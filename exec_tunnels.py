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
    if not mac:
        return None  # ← evita erro se mac for None

    for item in lista:
        if item.get('mac') and item['mac'].lower() == mac.lower():
            return item['ip']
    return None


def obter_porta_remota(host):
    res = requests.get(f'http://{host}:3020/unused_ports?qtd=1')
    return res.json()['portas'][0]

def salvar_conexao(pid, device_id, host, port):
    with open(CONEXOES_FILE, 'a') as f:
        f.write(f'pid:{pid}§§§§device_id:{device_id}§§§§device_host:{host}§§§§tunnel_porta:{port}\n')

def atualizar_erp(config, dispositivo, endereco_tunel):
    """
    Atualiza o endereço do túnel no ERP, exceto se device_id for 0.
    """
    device_id = dispositivo.get("id")
    if device_id in (0, "0"):
        logging.warning("⚠️  Ignorando update: device_id é 0")
        return

    url = f"{config['sc_server']['host']}/portarias/update_tunnel_devices.json"
    payload = {
        "id": device_id,
        "tunnel_address": endereco_tunel,
        "cliente_id": config["sc_server"]["cliente_id"]
    }

    logging.info(f"📡 Atualizando ERP: {url}")
    logging.debug(f"Payload: {json.dumps(payload)}")

    try:
        requests.post(url, json=payload)
    except Exception as e:
        logging.error(f"❌ Falha ao atualizar ERP: {e}")


def desconectar_tunel_antigo(device_id):
    """
    Desconecta túneis antigos associados ao device_id.
    """
    logging.info(f"🔌 Desconectando túneis antigos para o dispositivo ID {device_id}")
    if not CONEXOES_FILE.exists():
        logging.warning("Arquivo de conexões não encontrado.")
        return
    linhas_restantes = []
    with open(CONEXOES_FILE, 'r') as f:
        for linha in f:
            if f'device_id:{device_id}' in linha:
                pid = int(linha.split('pid:')[1].split('§§§§')[0])
                try:
                    os.kill(pid, 9)
                    logging.info(f"✅ Processo PID {pid} finalizado.")
                except ProcessLookupError:
                    logging.warning(f"⚠️ Processo PID {pid} não encontrado.")
            else:
                linhas_restantes.append(linha)
    with open(CONEXOES_FILE, 'w') as f:
        f.writelines(linhas_restantes)

def garantir_conexao_do_device(config, dispositivo):
    """
    Garante que o dispositivo esteja conectado. Se não estiver, tenta reconectar.
    """
    device_id = dispositivo['id']
    host = dispositivo.get('host')
    tunnel_host = config['sc_tunnel_server']['host']
    dispositivo['porta_remota'] = obter_porta_remota
    if not host:
        logging.warning(f"❌ Dispositivo #{dispositivo.get('codigo')} sem IP/host definido.")
        return
    if not CONEXOES_FILE.exists():
        logging.info(f"🔄 Nenhuma conexão existente para o dispositivo ID {device_id}. Estabelecendo nova conexão.")
        abrir_tunel(config, dispositivo)
        return
    with open(CONEXOES_FILE, 'r') as f:
        conexoes = f.readlines()
    for linha in conexoes:
        if f'device_id:{device_id}' in linha:
            pid = int(linha.split('pid:')[1].split('§§§§')[0])
            if psutil.pid_exists(pid):
                logging.info(f"🔄 Conexão existente para o dispositivo ID {device_id} com PID {pid}.")
                return
            else:
                logging.warning(f"⚠️ PID {pid} não está ativo. Reconectando.")
                desconectar_tunel_antigo(device_id)
                abrir_tunel(config, dispositivo)
                return
    logging.info(f"🔄 Nenhuma conexão registrada para o dispositivo ID {device_id}. Estabelecendo nova conexão.")
    abrir_tunel(config, dispositivo)


def gerar_ssh_cmd(config):
    device_id = 0
    ssh_port = extrair_campo_conexao(device_id, "tunnel_porta")
    if not ssh_port:
        logging.error("❌ Porta SSH do túnel não encontrada para device_id: 0.")
        return "Erro: porta não encontrada."

    ssh_host = config['sc_tunnel_server']['host']
    user = os.getenv('USER') or os.getlogin()

    ssh_cmd = (
        f"ssh -p {ssh_port} {user}@{ssh_host} "
        "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    )
    return ssh_cmd



def extrair_campo_conexao(device_id, campo):
    """
    Extrai o valor de um campo específico da conexão salva em conexoes.txt.
    """
    if not CONEXOES_FILE.exists():
        logging.warning("Arquivo conexoes.txt não encontrado.")
        return None

    with open(CONEXOES_FILE, 'r') as f:
        for linha in f:
            if f'device_id:{device_id}' in linha:
                partes = linha.strip().split('§§§§')
                for parte in partes:
                    if parte.startswith(f'{campo}:'):
                        return parte.split(f'{campo}:', 1)[1]
    return None


def abrir_ssh_do_tunnel(ip_tunnel, config):
    """
    Abre um túnel SSH reverso para o IP fornecido e exibe o comando SSH para acesso.
    """
    host = ip_tunnel
    porta_local = 22
    tunnel_host = config['sc_tunnel_server']['host']
    p_green(f"Abrindo túnel SSH na porta 22 para o device em {host}")

    dispositivo = {
        "id": 0,
        "codigo": "0",
        "host": host,
        "port": porta_local,
        "tunnel_me": True
    }

    # Obtém a porta remota do túnel
    dispositivo['porta_remota'] = obter_porta_remota(tunnel_host)

    # Usa a função normal de abertura com override de porta
    abrir_tunel(config, dispositivo)

    # Gera o comando SSH que o usuário usará para acessar
    ssh_cmd = gerar_ssh_cmd(config)

    print("##################################################################")
    p_green("Acesse essa máquina com")
    p_green(ssh_cmd)
    print("##################################################################")


def p_green(txt):
    print(f"\033[0;32m{txt}\033[0m")


def abrir_tunel(config, dispositivo):
    print(f"{dispositivo}")
    host_local = dispositivo['host']
    porta_local = dispositivo.get('port') or 80
    tunnel_host = config['sc_tunnel_server']['host']
    tunnel_user = config['sc_tunnel_server']['user']
    porta_remota = dispositivo.get('porta_remota') or obter_porta_remota(tunnel_host)

    cmd = [
        'ssh', '-N',
        '-o', 'ServerAliveInterval=20',
        '-i', str(PEM_FILE),
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'UserKnownHostsFile=/tmp/ssh_known_hosts_temp',
        '-R', f'{porta_remota}:{host_local}:{porta_local}',
        f'{tunnel_user}@{tunnel_host}'
    ]

    p_green(f'{host_local}:{porta_local} => {tunnel_host}:{porta_remota}')
    #proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    # for line in proc.stdout:
    #     logging.info(f'[ssh] {line.strip()}')
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )

    logging.info(f"✅ Túnel iniciado com PID {proc.pid}")

    
    
    salvar_conexao(proc.pid, dispositivo['id'], host_local, porta_remota)
    atualizar_erp(config, dispositivo, f'{tunnel_host}:{porta_remota}')

def main():
    logging.info("🚀 Iniciando execução do túnel reverso")

    if not PEM_FILE.exists():
        logging.error("❌ Arquivo scTunnel.pem não encontrado.")
        return

    logging.info("📥 Carregando configurações do arquivo config.json")
    config = carregar_config()


    logging.info("🌐 Descobrindo interface de rede ativa...")
    interface, ip_local, subnet = obter_interface_ip_subnet()
    if not interface:
        logging.error("❌ Interface de rede não encontrada.")
        return
    logging.info(f"✅ Interface ativa: {interface}, IP local: {ip_local}, Subnet: {subnet}/24")

    abrir_ssh_do_tunnel(ip_local, config)
    ssh_cmd_exemplo = gerar_ssh_cmd(config)

    dispositivos_rede = []
    if os.getenv("TESTE_GIT_ACTION") == "true":
        logging.info("🔧 Modo TESTE_GIT_ACTION ativado. Usando dados simulados.")
        dispositivos_rede = [
            {"ip": "192.168.15.179", "mac": "08:54:11:2A:FA:BC"},
            {"ip": "192.168.15.189", "mac": "08:54:11:2A:FA:00"},
        ]
    else:
        if not verificar_cap_net_raw():
            logging.error("❌ Python atual não possui cap_net_raw. Use '/usr/bin/python3.10' com setcap.")
            return
        logging.info("🛰️ Iniciando varredura ARP com Scapy...")
        dispositivos_rede = varredura_arp(interface, subnet)

    logging.info(f"🔍 {len(dispositivos_rede)} dispositivos encontrados na rede.")
    if not dispositivos_rede:
        logging.warning("⚠️ Nenhum dispositivo encontrado. Finalizando.")
        return

    macs = sorted({d['mac'] for d in dispositivos_rede})
    mac_str = ','.join(macs)

    varredura = '\n'.join(f"{d['ip']} {d['mac']}" for d in dispositivos_rede)

    url = f"{config['sc_server']['host']}/portarias/get_tunnel_devices.json?token={config['sc_server']['token']}&cliente_id={config['sc_server']['cliente_id']}"
    payload = {
        "tunnel_macaddres": mac_str,
        "ssh_cmd": ssh_cmd_exemplo,
        "varredura_rede": varredura,
        "codigos": config['sc_server'].get('equipamento_codigos', [])
    }

    logging.info("🔗 Consultando ERP para obter dispositivos com túnel ativo...")
    try:
        res = requests.post(url, json=payload)
        res.raise_for_status()
        dispositivos = res.json().get('devices', [])
        logging.info(f"📦 {len(dispositivos)} dispositivos recebidos do ERP.")
    except Exception as e:
        logging.error(f"❌ Erro ao consultar ERP: {e}")
        return

    print("---------------------------------------")
    p_green("Fazendo tunnels...")
    print("---------------------------------------")
    for dispositivo in dispositivos:
        device_id = dispositivo['id']
        codigo = dispositivo.get('codigo')
        tunnel_me = dispositivo.get('tunnel_me')
        mac1 = dispositivo.get('mac_address')
        mac2 = dispositivo.get('mac_address_2')
        ip = dispositivo.get('host') or buscar_ip_por_mac(mac1, dispositivos_rede) or buscar_ip_por_mac(mac2, dispositivos_rede)

        if not ip:
            logging.warning(f"❌ Dispositivo #{codigo} sem IP conhecido.")
            continue

        dispositivo['host'] = ip

        if tunnel_me is False:
            logging.info(f"🔌 Dispositivo #{codigo} marcado para desconexão.")
            desconectar_tunel_antigo(device_id)
        elif tunnel_me is not None:
            logging.info(f"🔗 Dispositivo #{codigo} marcado para conexão.")
            abrir_tunel(config, dispositivo)
            atualizar_erp(config, dispositivo, f"{config['sc_tunnel_server']['host']}:{obter_porta_remota(config['sc_tunnel_server']['host'])}")
        else:
            logging.info(f"🔍 Verificando conexão para o dispositivo #{codigo}.")
            garantir_conexao_do_device(config, dispositivo)

    print("---------------------------------------")
    print("---------------------------------------")


    # for dispositivo in dispositivos:
    #     if dispositivo.get('tunnel_me') is not True:
    #         logging.info(f"⏭️ Dispositivo #{dispositivo.get('codigo')} não está marcado como 'tunnel_me'. Ignorando.")
    #         continue

    #     mac1 = dispositivo.get('mac_address')
    #     mac2 = dispositivo.get('mac_address_2')
    #     ip = dispositivo.get('host') or buscar_ip_por_mac(mac1, dispositivos_rede) or buscar_ip_por_mac(mac2, dispositivos_rede)

    #     if not ip:
    #         logging.warning(f"⚠️ Dispositivo #{dispositivo.get('codigo')} sem IP conhecido. Pulando.")
    #         continue

    #     dispositivo['host'] = ip
    #     logging.info(f"🔐 Abrindo túnel para dispositivo #{dispositivo.get('codigo')} no IP {ip}")
    #     abrir_tunel(config, dispositivo)

    logging.info("✅ Execução finalizada com sucesso.")


if __name__ == '__main__':
    main()
