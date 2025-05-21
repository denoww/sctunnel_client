import os
import json
import subprocess
import psutil
import requests
import socket
from pathlib import Path
import platform
import ipaddress
import sys

import logging
from logging.handlers import RotatingFileHandler

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

# Caminho para o arquivo de log na raiz do projeto
log_file = os.path.join(os.path.dirname(__file__), "logs.log")

print(f"📄 Arquivo de log: {log_file}")
# logging.info("✅ Teste de log - deve aparecer no terminal e no arquivo.")



# Configuração de logging com RotatingFileHandler (limita tamanho do arquivo)
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(message)s',
    handlers=[
        logging.StreamHandler(),  # Saída no console
        RotatingFileHandler(log_file, maxBytes=100_000, backupCount=0, encoding='utf-8')  # ~1000 linhas
    ]
)




# BASE_DIR = Path(__file__).resolve().parent
# CONFIG_PATH = BASE_DIR / 'config.json'
# PEM_FILE = BASE_DIR / 'scTunnel.pem'



# if getattr(sys, 'frozen', False):
#     BASE_DIR = Path(sys._MEIPASS)
# else:
#     BASE_DIR = Path(__file__).resolve().parent

# CONFIG_PATH = BASE_DIR / 'config.json'
# PEM_FILE = BASE_DIR / 'scTunnel.pem'
# CONEXOES_FILE = BASE_DIR / 'conexoes.txt'


if getattr(sys, 'frozen', False):
    BASE_DIR = Path(sys.executable).parent  # ← pega a pasta do .exe
else:
    BASE_DIR = Path(__file__).resolve().parent

CONEXOES_FILE = BASE_DIR / 'conexoes.txt'

CONFIG_PATH = Path(sys._MEIPASS) / 'config.json'
PEM_FILE = Path(sys._MEIPASS) / 'scTunnel.pem' if getattr(sys, 'frozen', False) else BASE_DIR / 'scTunnel.pem'


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


def puts(txt):
    logging.info(txt)
def p_color(txt, color_code):
    puts(txt)
    print(f"\033[{color_code}m{txt}\033[0m")

def p_green(txt):
    p_color(txt, "0;32")

def p_red(txt):
    p_color(txt, "0;31")

def p_yellow(txt):
    p_color(txt, "0;33")
puts(f"TESTE_GIT_ACTION={os.getenv('TESTE_GIT_ACTION')}")


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
#     puts(f"Escaneando rede {subnet} via {interface} usando Scapy...")
#     pkt = Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=f"{subnet}/24")
#     ans, _ = srp(pkt, timeout=2, iface=interface, verbose=False)

#     puts(f"{len(ans)} respostas recebidas de ARP")

#     resultados = []
#     for snd, rcv in ans:
#         puts(f"Recebido: IP={rcv.psrc} MAC={rcv.hwsrc}")
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
    linhas_novas = []
    if CONEXOES_FILE.exists():
        with open(CONEXOES_FILE, 'r') as f:
            linhas_novas = [l for l in f if f'device_id:{device_id}' not in l]
    linhas_novas.append(f'pid:{pid}§§§§device_id:{device_id}§§§§device_host:{host}§§§§tunnel_porta:{port}\n')
    with open(CONEXOES_FILE, 'w') as f:
        f.writelines(linhas_novas)


def atualizar_erp(config, dispositivo, endereco_tunel):
    """
    Atualiza o endereço do túnel no ERP, usando cliente_id de cliente.txt.
    Gera erro se cliente.txt não existir ou estiver vazio.
    """
    device_id = dispositivo.get("id")
    if device_id in (0, "0"):
        logging.warning("⚠️  Ignorando update: device_id é 0")
        return

    cliente_id = get_cliente_id()


    url = f"{config['sc_server']['host']}/portarias/update_tunnel_devices.json"
    payload = {
        "id": device_id,
        "tunnel_address": endereco_tunel,
        "cliente_id": cliente_id
    }

    puts(f"📡 Atualizando ERP: {url}")
    logging.debug(f"Payload: {json.dumps(payload)}")

    try:
        requests.post(url, json=payload)
    except Exception as e:
        logging.error(f"❌ Falha ao atualizar ERP: {e}")



def desconectar_tunel_antigo(device_id):
    """
    Desconecta túneis antigos associados ao device_id.
    """
    puts(f"🔌 Desconectando túneis antigos para o dispositivo ID {device_id}")
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
                    puts(f"✅ Processo PID {pid} finalizado.")
                except ProcessLookupError:
                    logging.warning(f"⚠️ Processo PID {pid} não encontrado.")
            else:
                linhas_restantes.append(linha)
    with open(CONEXOES_FILE, 'w') as f:
        f.writelines(linhas_restantes)

def garantir_conexao_do_device(config, dispositivo):
    puts("entrou em garantir_conexao_do_device")
    """
    Garante que o dispositivo esteja conectado. Se não estiver, tenta reconectar.
    """
    device_id = dispositivo['id']
    host = dispositivo.get('host')
    tunnel_host = config['sc_tunnel_server']['host']
    dispositivo['porta_remota'] = obter_porta_remota(tunnel_host)
    if not host:
        logging.warning(f"❌ Dispositivo #{dispositivo.get('codigo')} sem IP/host definido.")
        return
    if not CONEXOES_FILE.exists():
        puts(f"🔄 Nenhuma conexão existente para o dispositivo ID {device_id}. Estabelecendo nova conexão.")
        abrir_tunel(config, dispositivo)
        return
    with open(CONEXOES_FILE, 'r') as f:
        conexoes = f.readlines()
    for linha in conexoes:
        if f'device_id:{device_id}' in linha:
            pid = int(linha.split('pid:')[1].split('§§§§')[0])
            if psutil.pid_exists(pid):
                puts(f"🔄 Conexão existente para o dispositivo ID {device_id} com PID {pid}.")
                return
            else:
                logging.warning(f"⚠️ PID {pid} não está ativo. Reconectando.")
                desconectar_tunel_antigo(device_id)
                abrir_tunel(config, dispositivo)
                return
    puts(f"🔄 Nenhuma conexão registrada para o dispositivo ID {device_id}. Estabelecendo nova conexão.")
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

    puts("##################################################################")
    p_green("Acesse essa máquina com")
    p_green(ssh_cmd)
    puts("##################################################################")




def abrir_tunel(config, dispositivo):
    device_id = dispositivo.get('id')
    host_local = dispositivo['host']
    porta_local = dispositivo.get('port') or 80
    tunnel_host = config['sc_tunnel_server']['host']
    tunnel_user = config['sc_tunnel_server']['user']

    # Reutiliza porta antiga se houver
    porta_remota = extrair_campo_conexao(device_id, "tunnel_porta") or dispositivo.get('porta_remota') or obter_porta_remota(tunnel_host)

    # Evita criar novo túnel se já tiver um PID válido rodando
    if CONEXOES_FILE.exists():
        with open(CONEXOES_FILE, 'r') as f:
            for linha in f:
                if f'device_id:{device_id}' in linha:
                    pid_existente = int(linha.split('pid:')[1].split('§§§§')[0])
                    if psutil.pid_exists(pid_existente):
                        puts(f"🔁 PID {pid_existente} já ativo para device_id {device_id}. Reutilizando conexão.")
                        return
                    else:
                        puts(f"💀 PID {pid_existente} morto. Limpando entrada.")
                        desconectar_tunel_antigo(device_id)

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

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )

    puts(f"✅ Túnel iniciado com PID {proc.pid}")
    salvar_conexao(proc.pid, device_id, host_local, porta_remota)
    atualizar_erp(config, dispositivo, f'{tunnel_host}:{porta_remota}')


def get_cliente_id():
    cliente_path = BASE_DIR / "cliente.txt"
    if not cliente_path.exists():
        logging.error("❌ cliente.txt não encontrado. Instalação inválida.")
        raise FileNotFoundError("cliente.txt não encontrado.")

    try:
        with open(cliente_path, "r", encoding="utf-8") as f:
            cliente_id = f.read().strip()
            if not cliente_id:
                raise ValueError("cliente.txt está vazio.")
            return cliente_id
    except Exception as e:
        logging.error(f"❌ Falha ao ler cliente.txt: {e}")
        raise


def main():
    puts("🚀 Iniciando execução do túnel reverso")

    if not PEM_FILE.exists():
        logging.error("❌ Arquivo scTunnel.pem não encontrado.")
        return

    puts("📥 Carregando configurações do arquivo config.json")
    config = carregar_config()
    puts(json.dumps(config, indent=2, ensure_ascii=False))  # para imprimir bonito



    puts("🌐 Descobrindo interface de rede ativa...")
    interface, ip_local, subnet = obter_interface_ip_subnet()
    if not interface:
        logging.error("❌ Interface de rede não encontrada.")
        return
    puts(f"✅ Interface ativa: {interface}, IP local: {ip_local}, Subnet: {subnet}/24")

    abrir_ssh_do_tunnel(ip_local, config)
    ssh_cmd_exemplo = gerar_ssh_cmd(config)

    dispositivos_rede = []
    if os.getenv("TESTE_GIT_ACTION") == "true":
        puts("🔧 Modo TESTE_GIT_ACTION ativado. Usando dados simulados.")
        dispositivos_rede = [
            {"ip": "192.168.15.179", "mac": "08:54:11:2A:FA:BC"},
            {"ip": "192.168.15.189", "mac": "08:54:11:2A:FA:00"},
        ]
    else:
        if not verificar_cap_net_raw():
            logging.error("❌ Python atual não possui cap_net_raw. Use '/usr/bin/python3.10' com setcap.")
            return
        puts("🛰️ Iniciando varredura ARP com Scapy...")
        dispositivos_rede = varredura_arp(interface, subnet)

    puts(f"🔍 {len(dispositivos_rede)} dispositivos encontrados na rede.")
    if not dispositivos_rede:
        logging.warning("⚠️ Nenhum dispositivo encontrado. Finalizando.")
        return

    macs = sorted({d['mac'] for d in dispositivos_rede})
    mac_str = ','.join(macs)

    varredura = '\n'.join(f"{d['ip']} {d['mac']}" for d in dispositivos_rede)

    cliente_id = get_cliente_id()
    url = f"{config['sc_server']['host']}/portarias/get_tunnel_devices.json?token={config['sc_server']['token']}&cliente_id={cliente_id}"

    payload = {
        "tunnel_macaddres": mac_str,
        "ssh_cmd": ssh_cmd_exemplo,
        "varredura_rede": varredura,
        "codigos": config['sc_server'].get('equipamento_codigos', [])
    }

    puts("🔗 Consultando ERP para obter dispositivos com túnel ativo...")
    try:
        res = requests.post(url, json=payload)
        res.raise_for_status()
        dispositivos = res.json().get('devices', [])
        puts(f"📦 {len(dispositivos)} dispositivos recebidos do ERP.")
    except Exception as e:
        logging.error(f"❌ Erro ao consultar ERP: {e}")
        return

    puts("---------------------------------------")
    p_green("Fazendo tunnels...")
    puts("---------------------------------------")
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
            puts(f"🔌 Dispositivo #{codigo} marcado para desconexão.")
            desconectar_tunel_antigo(device_id)
        elif tunnel_me is not None:
            puts(f"🔗 Dispositivo #{codigo} marcado para conexão.")
            abrir_tunel(config, dispositivo)
            tunnel_host = config['sc_tunnel_server']['host']

            atualizar_erp(config, dispositivo, f"{tunnel_host}:{obter_porta_remota(tunnel_host)}")
        else:
            puts(f"🔍 Verificando conexão para o dispositivo #{codigo}.")
            garantir_conexao_do_device(config, dispositivo)

    puts("---------------------------------------")
    puts("---------------------------------------")


    # for dispositivo in dispositivos:
    #     if dispositivo.get('tunnel_me') is not True:
    #         puts(f"⏭️ Dispositivo #{dispositivo.get('codigo')} não está marcado como 'tunnel_me'. Ignorando.")
    #         continue

    #     mac1 = dispositivo.get('mac_address')
    #     mac2 = dispositivo.get('mac_address_2')
    #     ip = dispositivo.get('host') or buscar_ip_por_mac(mac1, dispositivos_rede) or buscar_ip_por_mac(mac2, dispositivos_rede)

    #     if not ip:
    #         logging.warning(f"⚠️ Dispositivo #{dispositivo.get('codigo')} sem IP conhecido. Pulando.")
    #         continue

    #     dispositivo['host'] = ip
    #     puts(f"🔐 Abrindo túnel para dispositivo #{dispositivo.get('codigo')} no IP {ip}")
    #     abrir_tunel(config, dispositivo)

    logging.info("✅ Execução finalizada com sucesso.")


if __name__ == '__main__':
    main()
