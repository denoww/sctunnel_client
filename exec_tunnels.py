import os
import json
import subprocess
import psutil
import requests
import logging
import socket
from pathlib import Path
import platform
import ipaddress

# from scapy.all import ARP, Ether, srp

from network_scanner import varredura_arp, verificar_cap_net_raw




# # Tenta importar scapy, mas permite fallback
# try:
#     from scapy.all import ARP, Ether, srp
#     SCAPY_OK = True
# except ImportError:
#     logging.warning("Scapy não disponível. Usando fallback com ping.")
#     SCAPY_OK = False




# def verificar_permissoes():
#     if platform.system().lower() == "linux":
#         try:
#             with open("/proc/sys/net/ipv4/ip_forward") as f:
#                 return os.geteuid() == 0 or "cap_net_raw" in os.popen(f"getcap {os.readlink('/proc/self/exe')}").read()
#         except:
#             return False
#     elif platform.system().lower() == "windows":
#         return True  # Assumimos Npcap instalado
#     return False




# Caminho de log opcional, respeitando sistema operacional
log_dir = os.path.join(os.getcwd(), "logs")
os.makedirs(log_dir, exist_ok=True)

log_file = os.path.join(log_dir, "app.log")

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(message)s',
    handlers=[
        logging.StreamHandler(),  # Saída no console
        logging.FileHandler(log_file, encoding='utf-8')  # Arquivo de log
    ]
)


logging.info(f"TESTE_GIT_ACTION={os.getenv('TESTE_GIT_ACTION')}")



BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / 'config.json'
PEM_FILE = BASE_DIR / 'scTunnel.pem'
CONEXOES_FILE = BASE_DIR / 'conexoes.txt'

def carregar_config():
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

def obter_interface_ip_subnet():
    for iface, addrs in psutil.net_if_addrs().items():
        for addr in addrs:
            if addr.family == socket.AF_INET:
                ip = addr.address
                if not ip.startswith("127.") and not ip.startswith("169.254."):
                    try:
                        rede = ipaddress.IPv4Interface(f"{ip}/{addr.netmask}").network
                        base_ip = str(rede.network_address)  # ← apenas o IP base
                        return iface, ip, base_ip  # ← sem /24
                    except Exception:
                        continue
    return None, None, None


# def obter_interface_ip_subnet():
#     """
#     Retorna a interface de rede ativa com IP IPv4 válido e a subnet /24 correspondente.
#     Exemplo de retorno: ('eno1', '192.168.15.115', '192.168.15.0/24')
#     """
#     for iface, addrs in psutil.net_if_addrs().items():
#         for addr in addrs:
#             if addr.family == socket.AF_INET:
#                 ip = addr.address
#                 if not ip.startswith("127.") and not ip.startswith("169.254."):
#                     try:
#                         # Calcula a rede com base na máscara
#                         rede = ipaddress.IPv4Interface(f"{ip}/{addr.netmask}").network
#                         return iface, ip, str(rede)
#                     except Exception:
#                         continue
#     return None, None, None

# def obter_interface_ip_subnet():
#     return "eno1", "192.168.15.115", "192.168.15.0"

# def obter_interface_ip_subnet():
#     for iface, addrs in psutil.net_if_addrs().items():
#         for addr in addrs:
#             if addr.family == socket.AF_INET and not addr.address.startswith("127."):
#                 ip = addr.address
#                 subnet = '.'.join(ip.split('.')[:3]) + '.0/24'
#                 return iface, ip, subnet
#     return None, None, None

# def varredura_arp(interface, subnet):
#     logging.info(f"Escaneando rede {subnet} via {interface} usando Scapy...")
#     pkt = Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=f"{subnet}/24")
#     ans, _ = srp(pkt, timeout=2, iface=interface, verbose=False)

#     logging.info(f"{len(ans)} respostas recebidas de ARP")

#     resultados = []
#     for snd, rcv in ans:
#         logging.info(f"Recebido: IP={rcv.psrc} MAC={rcv.hwsrc}")
#         resultados.append({"ip": rcv.psrc, "mac": rcv.hwsrc})

#     return resultados



def ping_host(ip):
    param = "-n" if platform.system().lower() == "windows" else "-c"
    try:
        subprocess.check_output(["ping", param, "1", ip], stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False




def buscar_ip_por_mac(mac, lista):
    for item in lista:
        if item['mac'].lower() == mac.lower():
            return item['ip']
    return None

def obter_porta_remota(host):
    res = requests.get(f'http://{host}:3020/unused_ports?qtd=1')
    return res.json()['portas'][0]

def salvar_conexao(pid, device_id, host, port):
    with open(CONEXOES_FILE, 'a') as f:
        f.write(f'pid:{pid}§§§§device_id:{device_id}§§§§device_host:{host}§§§§tunnel_porta:{port}\n')

def atualizar_erp(config, dispositivo, endereco_tunel):
    url = f"{config['sc_server']['host']}/portarias/update_tunnel_devices.json"
    payload = {
        'id': dispositivo['id'],
        'tunnel_address': endereco_tunel,
        'cliente_id': config['sc_server']['cliente_id']
    }
    requests.post(url, json=payload)

def abrir_tunel(config, dispositivo):
    host_local = dispositivo['host']
    porta_local = dispositivo.get('port', 80)
    tunnel_host = config['sc_tunnel_server']['host']
    tunnel_user = config['sc_tunnel_server']['user']
    porta_remota = obter_porta_remota(tunnel_host)

    cmd = [
        'ssh', '-N',
        '-o', 'ServerAliveInterval=20',
        '-i', str(PEM_FILE),
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'UserKnownHostsFile=/tmp/ssh_known_hosts_temp',
        '-R', f'{porta_remota}:{host_local}:{porta_local}',
        f'{tunnel_user}@{tunnel_host}'
    ]

    logging.info(f'Abrindo túnel SSH reverso: {host_local}:{porta_local} => {tunnel_host}:{porta_remota}')
    #proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in proc.stdout:
        logging.info(f'[ssh] {line.strip()}')
    
    
    salvar_conexao(proc.pid, dispositivo['id'], host_local, porta_remota)
    atualizar_erp(config, dispositivo, f'{tunnel_host}:{porta_remota}')

def main():
    if not PEM_FILE.exists():
        logging.error('Arquivo scTunnel.pem não encontrado.')
        return

    config = carregar_config()
    interface, ip_local, subnet = obter_interface_ip_subnet()
    if not interface:
        logging.error('Interface de rede não encontrada.')
        return

    dispositivos_rede = []
    if os.getenv("TESTE_GIT_ACTION") == "true":
        dispositivos_rede = [
            {"ip": "10.1.0.101", "mac": "aa:bb:cc:dd:ee:ff"},
            {"ip": "10.1.0.102", "mac": "11:22:33:44:55:66"}
        ]
    else:
        if not verificar_cap_net_raw():
            logging.info(f'1')
            logging.error("❌ Python atual não possui cap_net_raw. Use '/usr/bin/python3.10' com setcap.")
            return
        else:
            logging.info(f'2')
            dispositivos_rede = varredura_arp(interface, subnet)
    
    logging.info(f'{len(dispositivos_rede)} dispositivos encontrados.')

    macs = sorted({d['mac'] for d in dispositivos_rede})
    mac_str = ','.join(macs)

    ssh_cmd_exemplo = f'ssh -p 22 {os.getlogin()}@{config["sc_tunnel_server"]["host"]}'
    varredura = '\n'.join(f"{d['ip']} {d['mac']}" for d in dispositivos_rede)

    url = f"{config['sc_server']['host']}/portarias/get_tunnel_devices.json?token={config['sc_server']['token']}&cliente_id={config['sc_server']['cliente_id']}"
    payload = {
        "tunnel_macaddres": mac_str,
        "ssh_cmd": ssh_cmd_exemplo,
        "varredura_rede": varredura,
        "codigos": config['sc_server'].get('equipamento_codigos', [])
    }

    try:
        res = requests.post(url, json=payload)
        res.raise_for_status()
        dispositivos = res.json().get('devices', [])
    except Exception as e:
        logging.error(f'Erro ao consultar ERP: {e}')
        return

    for dispositivo in dispositivos:
        if dispositivo.get('tunnel_me') is not True:
            continue

        mac1 = dispositivo.get('mac_address')
        mac2 = dispositivo.get('mac_address_2')
        ip = dispositivo.get('host') or buscar_ip_por_mac(mac1, dispositivos_rede) or buscar_ip_por_mac(mac2, dispositivos_rede)

        if not ip:
            logging.warning(f"Dispositivo #{dispositivo.get('codigo')} sem IP conhecido.")
            continue

        dispositivo['host'] = ip
        abrir_tunel(config, dispositivo)

    logging.info('✅ Execução finalizada.')

if __name__ == '__main__':
    main()
