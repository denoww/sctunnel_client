#!/usr/bin/env python3
"""sctunnel client runtime (v2, Linux-only).

Reverse-SSH tunnel orchestrator. Reads /opt/sctunnel/config.json, scans the
local network, asks the ERP which devices need a tunnel, and opens/maintains
`ssh -N -R` processes against the SC tunnel server.
"""
import ipaddress
import json
import logging
import os
import shutil
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import time
import uuid
from logging.handlers import RotatingFileHandler
from pathlib import Path

import psutil
import requests

from network_scanner import arp_scan, has_cap_net_raw


BASE_DIR = Path("/opt/sctunnel")
CONFIG_PATH = BASE_DIR / "config.json"
CLIENTE_TXT = BASE_DIR / "cliente.txt"
PEM_SRC = BASE_DIR / "scTunnel.pem"
SSH_USER_FILE = BASE_DIR / "ssh_user"
LOG_DIR = BASE_DIR / "logs"
LOG_FILE = LOG_DIR / "tunnels.log"
CONEXOES_FILE = BASE_DIR / "conexoes.txt"

ROTATE_AFTER_SECONDS = 60 * 60  # rotate self-tunnel every 1h
SELF_DEVICE_ID = 0
HTTP_TIMEOUT = 15


def setup_logging():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    fmt = logging.Formatter("[%(asctime)s] %(levelname)s: %(message)s")
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    for h in list(root.handlers):
        root.removeHandler(h)
    fh = RotatingFileHandler(LOG_FILE, maxBytes=512_000, backupCount=2, encoding="utf-8")
    fh.setFormatter(fmt)
    root.addHandler(fh)
    sh = logging.StreamHandler(sys.stdout)
    sh.setFormatter(fmt)
    root.addHandler(sh)


def load_config():
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def get_cliente_id(config):
    if CLIENTE_TXT.exists():
        v = CLIENTE_TXT.read_text(encoding="utf-8").strip()
        if v:
            return v
    return str(config["sc_server"]["cliente_id"])


def prepare_pem():
    """Copy PEM to a 0600 tempfile (ssh refuses world-readable keys)."""
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".pem", prefix="sctunnel_")
    tmp.close()
    shutil.copy(PEM_SRC, tmp.name)
    os.chmod(tmp.name, 0o600)
    return Path(tmp.name)


def list_active_interfaces():
    """Yield (iface, ip, subnet) for UP interfaces with a real IPv4."""
    stats = psutil.net_if_stats()
    addrs = psutil.net_if_addrs()
    for iface, st in stats.items():
        if not st.isup:
            continue
        for a in addrs.get(iface, []):
            if a.family != socket.AF_INET:
                continue
            ip = a.address
            if ip.startswith(("127.", "169.254.")) or ip == "0.0.0.0":
                continue
            subnet = str(ipaddress.IPv4Interface(f"{ip}/24").network)
            yield iface, ip, subnet


def scan_network():
    if not has_cap_net_raw():
        logging.error("Python lacks cap_net_raw; run cap_net_raw setcap step")
        return []
    devices = []
    for iface, ip, subnet in list_active_interfaces():
        try:
            devices += arp_scan(iface, subnet)
        except Exception as e:
            logging.error(f"arp_scan failed on {iface}: {e}")
        time.sleep(1)
    logging.info(f"network scan: {len(devices)} devices")
    return devices


def get_local_ip():
    for _, ip, _ in list_active_interfaces():
        return ip
    return None


def get_executor_mac():
    n = uuid.getnode()
    return ":".join(f"{(n >> shift) & 0xFF:02x}" for shift in range(40, -1, -8))


# ── conexoes.txt: persisted state of running tunnels ─────────────────────────
# format: pid:N---device_id:N---device_host:H---tunnel_porta:N---data_hora_conexao:EPOCH

def _read_conexoes():
    if not CONEXOES_FILE.exists():
        return []
    return [l for l in CONEXOES_FILE.read_text(encoding="utf-8", errors="replace").splitlines() if l.strip()]


def _write_conexoes(lines):
    CONEXOES_FILE.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def _parse(line):
    parts = line.split("---------")
    out = {}
    for p in parts:
        if ":" in p:
            k, v = p.split(":", 1)
            out[k] = v
    return out


def find_connection(device_id):
    for line in _read_conexoes():
        rec = _parse(line)
        if rec.get("device_id") == str(device_id):
            return rec
    return None


def save_connection(pid, device_id, host, remote_port):
    others = [l for l in _read_conexoes() if _parse(l).get("device_id") != str(device_id)]
    others.append(
        f"pid:{pid}---------device_id:{device_id}---------"
        f"device_host:{host}---------tunnel_porta:{remote_port}---------"
        f"data_hora_conexao:{int(time.time())}"
    )
    _write_conexoes(others)


def drop_connection(device_id):
    keep = [l for l in _read_conexoes() if _parse(l).get("device_id") != str(device_id)]
    _write_conexoes(keep)


def pid_is_ssh(pid):
    try:
        return psutil.Process(int(pid)).name().lower() == "ssh"
    except (psutil.NoSuchProcess, ValueError, TypeError):
        return False


def kill_pid(pid):
    try:
        try:
            os.killpg(os.getpgid(int(pid)), signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            os.kill(int(pid), signal.SIGKILL)
        return True
    except Exception as e:
        logging.warning(f"kill {pid} failed: {e}")
        return False


def disconnect(device_id):
    rec = find_connection(device_id)
    if rec and rec.get("pid"):
        kill_pid(rec["pid"])
    drop_connection(device_id)


def request_remote_port(tunnel_host):
    url = f"http://{tunnel_host}:3020/unused_ports?qtd=1"
    r = requests.get(url, timeout=HTTP_TIMEOUT)
    r.raise_for_status()
    return int(r.json()["portas"][0])


def open_tunnel(config, device, pem_path):
    device_id = device["id"]
    host_local = device["host"]
    port_local = device.get("port") or 80
    tunnel_host = config["sc_tunnel_server"]["host"]
    tunnel_user = config["sc_tunnel_server"]["user"]

    rec = find_connection(device_id)
    if rec and pid_is_ssh(rec.get("pid")):
        logging.info(f"device {device_id}: PID {rec['pid']} already running, reusing")
        return

    remote_port = (rec.get("tunnel_porta") if rec else None) or request_remote_port(tunnel_host)

    dest = host_local if ":" in str(host_local) else f"{host_local}:{port_local}"
    cmd = [
        "ssh", "-N",
        "-o", "ServerAliveInterval=20",
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=/tmp/sctunnel_known_hosts",
        "-i", str(pem_path),
        "-R", f"{remote_port}:{dest}",
        f"{tunnel_user}@{tunnel_host}",
    ]
    logging.info(" ".join(cmd))

    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True
    )
    time.sleep(2)
    if proc.poll() is not None:
        out, err = proc.communicate()
        logging.error(f"ssh exited early: stdout={out!r} stderr={err!r}")
        return

    logging.info(f"tunnel up: PID {proc.pid} {dest} -> {tunnel_host}:{remote_port}")
    save_connection(proc.pid, device_id, host_local, remote_port)
    erp_update(config, device, remote_port)


def erp_update(config, device, remote_port):
    if device["id"] in (0, "0"):
        return
    url = f"{config['sc_server']['host']}/portarias/update_tunnel_devices.json"
    payload = {
        "id": device["id"],
        "tunnel_address": f"{config['sc_tunnel_server']['host']}:{remote_port}",
        "cliente_id": get_cliente_id(config),
        "token": config["sc_server"]["token"],
    }
    try:
        r = requests.post(url, json=payload, timeout=HTTP_TIMEOUT)
        logging.info(f"erp_update {r.status_code}: {r.text[:200]}")
    except Exception as e:
        logging.error(f"erp_update failed: {e}")


def ensure_self_tunnel(config, pem_path):
    """Maintain a tunnel from this machine's port 22, rotating every ROTATE_AFTER_SECONDS."""
    ip = get_local_ip()
    if not ip:
        logging.error("no local IPv4 found")
        return

    rec = find_connection(SELF_DEVICE_ID)
    needs_open = True
    if rec and pid_is_ssh(rec.get("pid")):
        age = int(time.time()) - int(rec.get("data_hora_conexao") or 0)
        if age < ROTATE_AFTER_SECONDS:
            logging.info(f"self-tunnel up (PID {rec['pid']}, age {age}s)")
            needs_open = False
        else:
            logging.info(f"self-tunnel age {age}s >= {ROTATE_AFTER_SECONDS}s, rotating")
            disconnect(SELF_DEVICE_ID)
    else:
        disconnect(SELF_DEVICE_ID)

    if needs_open:
        open_tunnel(config, {"id": SELF_DEVICE_ID, "host": ip, "port": 22}, pem_path)

    rec = find_connection(SELF_DEVICE_ID)
    if rec:
        try:
            user = SSH_USER_FILE.read_text(encoding="utf-8").strip() or "ubuntu"
        except FileNotFoundError:
            user = "ubuntu"
        cmd = (
            f"ssh -p {rec['tunnel_porta']} {user}@{config['sc_tunnel_server']['host']} "
            "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        )
        logging.info("=" * 60)
        logging.info(f"Acesse essa máquina: {cmd}")
        logging.info("=" * 60)


def find_ip_by_mac(mac, network):
    if not mac:
        return None
    mac = mac.lower()
    for d in network:
        if d.get("mac", "").lower() == mac:
            return d["ip"]
    return None


def query_erp(network, config):
    cliente_id = get_cliente_id(config)
    token = config["sc_server"]["token"]
    url = (
        f"{config['sc_server']['host']}/portarias/get_tunnel_devices.json"
        f"?token={token}&cliente_id={cliente_id}"
    )
    payload = {
        "tunnel_macaddres": get_executor_mac(),
        "varredura_rede": "\n".join(f"{d['ip']} {d['mac']}" for d in network),
        "codigos": config["sc_server"].get("equipamento_codigos", []),
        "conexoes_txt": _read_text_tail(CONEXOES_FILE, 80_000),
        "logs_txt": _read_text_tail(LOG_FILE, 200_000),
        "conexoes_file_name": CONEXOES_FILE.name,
        "logs_file_name": LOG_FILE.name,
    }
    logging.info(f"querying ERP cliente_id={cliente_id}")
    try:
        r = requests.post(url, json=payload, timeout=HTTP_TIMEOUT)
        r.raise_for_status()
        devices = r.json().get("devices", [])
        logging.info(f"ERP returned {len(devices)} devices")
        return devices
    except Exception as e:
        logging.error(f"query_erp failed: {e}")
        return None


def _read_text_tail(path, max_bytes):
    try:
        if not path.exists():
            return ""
        data = path.read_bytes()
        return data[-max_bytes:].decode("utf-8", errors="replace")
    except Exception:
        return ""


def process_devices(devices, network, config, pem_path):
    for d in devices:
        device_id = d["id"]
        codigo = d.get("codigo")
        ip = d.get("ip") or find_ip_by_mac(d.get("mac_address"), network) or find_ip_by_mac(d.get("mac_address_2"), network)
        if not ip:
            logging.warning(f"device #{codigo}: no IP found")
            continue
        d["host"] = ip

        if d.get("tunnel_me") is False:
            disconnect(device_id)
        elif d.get("tunnel_me") is True:
            disconnect(device_id)
            open_tunnel(config, d, pem_path)
        else:
            rec = find_connection(device_id)
            if rec and pid_is_ssh(rec.get("pid")):
                erp_update(config, d, int(rec["tunnel_porta"]))
            else:
                disconnect(device_id)
                open_tunnel(config, d, pem_path)


def main():
    setup_logging()
    logging.info("=== sctunnel v2 starting ===")

    if not PEM_SRC.exists():
        logging.error(f"PEM not found at {PEM_SRC}")
        sys.exit(1)

    config = load_config()
    pem_path = prepare_pem()
    try:
        ensure_self_tunnel(config, pem_path)
        network = scan_network()
        if not network:
            logging.warning("no devices found on local network; skipping ERP query")
            return
        devices = query_erp(network, config)
        if devices is None:
            return
        process_devices(devices, network, config, pem_path)
        logging.info("=== sctunnel v2 done ===")
    finally:
        try:
            pem_path.unlink(missing_ok=True)
        except Exception:
            pass


if __name__ == "__main__":
    main()
