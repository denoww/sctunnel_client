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
import signal
import getpass
import time
import tempfile
import shutil
import stat

from ipaddress import IPv4Address, IPv4Interface


import logging
from logging.handlers import RotatingFileHandler

# from scapy.all import ARP, Ether, srp

from network_scanner import varredura_arp, verificar_cap_net_raw
from scapy.all import get_if_addr


# if getattr(sys, 'frozen', False):
#     PROJECT_DIR = Path(sys.executable).parent  # ← pega a pasta do .exe
# else:
#     PROJECT_DIR = Path(__file__).resolve().parent

# CONEXOES_FILE = PROJECT_DIR / 'conexoes.txt'
# CONFIG_PATH = Path(sys._MEIPASS) / 'config.json'
# PEM_FILE = Path(sys._MEIPASS) / 'scTunnel.pem' if getattr(sys, 'frozen', False) else PROJECT_DIR / 'scTunnel.pem'
# LOG_FILE = PROJECT_DIR / 'logs.log'

# Detecta se está rodando como .exe (PyInstaller)
FROZEN = getattr(sys, 'frozen', False)
IS_WINDOWS = platform.system() == "Windows"

# Diretório onde o script ou executável está
PROJECT_DIR = Path(sys.executable).parent if FROZEN else Path(__file__).resolve().parent

# Se for Windows e estiver empacotado (.exe), usa _MEIPASS para arquivos embutidos
if FROZEN and IS_WINDOWS:
    # quando o arquivo foi mergiado junto com o exec.exe  pelo pyinstaller
    DIR_MERGER_WITH_EXE = Path(sys._MEIPASS)
else:
    DIR_MERGER_WITH_EXE = PROJECT_DIR

# Caminhos dos arquivos
CONEXOES_FILE = PROJECT_DIR / 'conexoes.txt'         # Sempre no diretório de execução
LOG_FILE = PROJECT_DIR / 'logs.log'                  # Sempre no diretório de execução
CONFIG_PATH = DIR_MERGER_WITH_EXE / 'config.json'        # Embutido no exe ou lado a lado no Linux
PEM_FILE_ORIGINAL = DIR_MERGER_WITH_EXE / 'scTunnel.pem'          # Idem
CLIENTE_TXT = PROJECT_DIR / 'cliente.txt'         # Idem
RESET_BAT = PROJECT_DIR / 'reset.bat'         # Idem
# PEM_FILE = PROJECT_DIR / 'scTunnel.pem'          # Idem


# def garantir_permissoes_para_todos(path):
#     if not path.exists():
#         path.touch()

#     sistema = platform.system().lower()

#     if sistema == 'windows':
#         # No Windows, o ideal é não usar ACL diretamente em Python, mas garantir que o arquivo esteja em pasta pública
#         # ou evitar que seja só de admins. Para garantir permissões básicas:
#         # os.chmod(path, stat.S_IWRITE | stat.S_IREAD)
#         # Dá controle total a todos os usuários (Everyone)
#         subprocess.run([
#             "icacls", str(path),
#             "/grant", "Everyone:F"
#         ], check=True)
#     else:
#         # Linux: permissão 666 = leitura/escrita para todos
#         os.chmod(path, 0o666)

def garantir_permissoes_para_todos(path):
    path = Path(path)

    if not path.exists():
        path.touch()

    if os.name == 'nt':  # Windows
        for nome in ["Todos", "Everyone"]:
            try:
                subprocess.run(
                    ["icacls", str(path), "/grant", f"{nome}:F"],
                    check=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                break
            except subprocess.CalledProcessError:
                pass  # Falha ao aplicar permissões, mas seguimos o script
    else:
        try:
            os.chmod(path, 0o666)
        except Exception:
            pass  # Ignora erro de permissão no Linux também

garantir_permissoes_para_todos(CONEXOES_FILE)
garantir_permissoes_para_todos(CLIENTE_TXT)
garantir_permissoes_para_todos(RESET_BAT)



def preparar_pem_temp(pem_origem: Path) -> Path:
    with tempfile.NamedTemporaryFile(delete=False, suffix='.pem') as tmp:
        pem_temp_path = Path(tmp.name)

    shutil.copy(pem_origem, pem_temp_path)

    if IS_WINDOWS:
        ajustar_permissoes_windows(pem_temp_path)
    else:
        os.chmod(pem_temp_path, 0o600)  # rw------- no Linux

    return pem_temp_path

def ajustar_permissoes_windows(caminho_arquivo: Path):
    username = getpass.getuser()
    cmd = [
        "icacls",
        str(caminho_arquivo),
        "/inheritance:r",
        f"/grant:r", f"{username}:R"
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    print(f"[icacls] STDOUT:\n{result.stdout}")
    if result.returncode != 0:
        print(f"[icacls] ERRO: {result.stderr}")

# Exemplo de uso:
PEM_FILE = preparar_pem_temp(Path(PEM_FILE_ORIGINAL))
print(f"🔐 PEM pronto: {PEM_FILE}")

def cortar_ultimas_linhas_logs(path, max_linhas):
    try:
        linhas = path.read_text(encoding='utf-8').splitlines()
        if len(linhas) > max_linhas:
            path.write_text('\n'.join(linhas[-max_linhas:]) + '\n', encoding='utf-8')
    except Exception as e:
        print(f"[AVISO] Falha ao cortar log: {e}")

# Configura o logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler()
    ]
)

# Exemplo de uso
cortar_ultimas_linhas_logs(LOG_FILE, 1000)

# Gera muitos logs até estourar o tamanho
for i in range(20):
    logging.info(f"Log número {i}")

def gerar_log(txt):
    logging.info(txt)

def puts(txt):
    gerar_log(txt)
    print(txt)
def p_color(txt, color_code):
    gerar_log(txt)
    print(f"\033[{color_code}m{txt}\033[0m")

def p_green(txt):
    p_color(txt, "0;32")

def p_red(txt):
    p_color(txt, "0;31")

def p_yellow(txt):
    p_color(txt, "0;33")
puts(f"TESTE_GIT_ACTION={os.getenv('TESTE_GIT_ACTION')}")





def mostrar_conteudo_pem(pem_path):
    puts("🔍 Conteúdo de scTunnel.pem:")
    puts("═════════════════════════════════════")
    try:
        with open(pem_path, "r", encoding="utf-8") as f:
            for linha in f:
                puts(linha.strip())
    except Exception as e:
        p_red(f"❌ Erro ao ler PEM: {e}")
    puts("═════════════════════════════════════")




def carregar_config():
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

# def obter_interface_ip_subnet():
#     for iface, addrs in psutil.net_if_addrs().items():
#         for addr in addrs:
#             if addr.family == socket.AF_INET:
#                 ip = addr.address
#                 if not ip.startswith("127.") and not ip.startswith("169.254."):
#                     try:
#                         rede = ipaddress.IPv4Interface(f"{ip}/{addr.netmask}").network
#                         base_ip = str(rede.network_address)  # ← apenas o IP base
#                         return iface, ip, base_ip  # ← sem /24
#                     except Exception:
#                         continue
#     return None, None, None







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


def update_tunnel_devices(config, dispositivo):
    """
    Atualiza o endereço do túnel no ERP, usando cliente_id de cliente.txt.
    Gera erro se cliente.txt não existir ou estiver vazio.
    """

    device_id = dispositivo.get("id")

    tunnel_host = config['sc_tunnel_server']['host']
    porta_remota = extrair_campo_conexao(device_id, "tunnel_porta")
    endereco_tunel = f'{tunnel_host}:{porta_remota}'

    if device_id in (0, "0"):
        p_yellow("⚠️  Ignorando update: device_id é 0")
        return

    cliente_id = get_cliente_id(config)

    token = config['sc_server']['token']

    url = f"{config['sc_server']['host']}/portarias/update_tunnel_devices.json"
    payload = {
        "id": device_id,
        "tunnel_address": endereco_tunel,
        "cliente_id": cliente_id,
        "token": token
    }

    puts(f"📡 Atualizando ERP: {url}")
    puts(f"Payload: {json.dumps(payload)}")

    try:
        # requests.post(url, json=payload)
        response = requests.post(url, json=payload, timeout=5)
        puts(f"📥 Status code: {response.status_code}")
        puts(f"📄 Resposta: {response.text}")
        response.raise_for_status()  # Lança exceção para 4xx ou 5xx

    except Exception as e:
        p_red(f"❌ Falha ao atualizar ERP: {e}")


def kill_process(pid):
    try:
        if platform.system() == "Windows":
            result = subprocess.run(
                ["taskkill", "/PID", str(pid), "/F"],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        else:
            os.kill(pid, signal.SIGKILL)
        return True
    except subprocess.CalledProcessError as e:
        p_yellow(f"⚠️ taskkill falhou para PID {pid}: {e}")
        return False
    except Exception as e:
        p_red(f"❌ Erro ao finalizar PID {pid}: {e}")
        return False


def desconectar_tunel_antigo(device_id):
    """
    Desconecta túneis antigos associados ao device_id.
    """
    puts(f"🔌 Desconectando túneis antigos para o dispositivo ID {device_id}")
    if not CONEXOES_FILE.exists():
        p_yellow("Arquivo de conexões não encontrado.")
        return
    linhas_restantes = []
    with open(CONEXOES_FILE, 'r') as f:
        for linha in f:
            if f'device_id:{device_id}' in linha:
                pid = int(linha.split('pid:')[1].split('§§§§')[0])
                try:
                    if kill_process(pid):
                        puts(f"✅ Processo PID {pid} finalizado.")
                except ProcessLookupError:
                    p_yellow(f"⚠️ Processo PID {pid} não encontrado.")
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
    codigo = dispositivo.get('codigo')
    tunnel_host = config['sc_tunnel_server']['host']
    dispositivo['porta_remota'] = obter_porta_remota(tunnel_host)
    if not host:
        p_yellow(f"❌ Dispositivo #{codigo} sem IP/host definido.")
        return
    if not CONEXOES_FILE.exists():
        puts(f"🔄 Nenhuma conexão existente para o dispositivo #{codigo}. Estabelecendo nova conexão.")
        abrir_tunel(config, dispositivo)
        return
    with open(CONEXOES_FILE, 'r') as f:
        conexoes = f.readlines()
    for linha in conexoes:
        if f'device_id:{device_id}' in linha:
            pid = int(linha.split('pid:')[1].split('§§§§')[0])
            if pid_existe(pid):
                puts(f"🔄 Conexão existente para o dispositivo #{codigo} com PID {pid}.")
                update_tunnel_devices(config, dispositivo)

                return
            else:
                p_yellow(f"⚠️ PID {pid} não está ativo. Reconectando.")
                desconectar_tunel_antigo(device_id)
                abrir_tunel(config, dispositivo)
                return
    puts(f"🔄 Nenhuma conexão registrada para o dispositivo #{codigo}. Estabelecendo nova conexão.")
    abrir_tunel(config, dispositivo)


def gerar_ssh_cmd(config):
    if IS_WINDOWS:
      return "windows não tem..."
    device_id = 0
    ssh_port = extrair_campo_conexao(device_id, "tunnel_porta")
    if not ssh_port:
        p_red("❌ Porta SSH do túnel não encontrada para device_id: 0.")
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
        p_yellow("Arquivo conexoes.txt não encontrado.")
        return None

    with open(CONEXOES_FILE, 'r') as f:
        for linha in f:
            if f'device_id:{device_id}' in linha:
                partes = linha.strip().split('§§§§')
                for parte in partes:
                    if parte.startswith(f'{campo}:'):
                        return parte.split(f'{campo}:', 1)[1]
    return None


def descobrir_meu_ip():
    """
    Retorna o primeiro IP IPv4 válido da máquina (não 127.x, nem 169.x, nem 0.0.0.0).
    Exemplo de retorno: '192.168.15.115'
    """
    stats = psutil.net_if_stats()
    addrs = psutil.net_if_addrs()

    for iface in stats:
        if not stats[iface].isup:
            continue

        for addr in addrs.get(iface, []):
            if addr.family.name == 'AF_INET':
                ip = addr.address
                if ip and not ip.startswith("127.") and not ip.startswith("169.254") and ip != "0.0.0.0":
                    return ip

    return None  # Nenhum IP válido encontrado


def abrir_ssh_desse_device(config):
    ip_local = descobrir_meu_ip()
    if ip_local:
        puts(f"📡 IP local detectado: {ip_local}")
    else:
        p_red("❌ Não foi possível detectar um IP IPv4 válido.")

    porta = "22"

    host = f"{ip_local}"
    puts(f"🔐 Abrindo túnel SSH na porta {porta} para o device em {host}")

    # monta objeto como no shell
    device = {
        "id": 0,
        "codigo": "0",
        "host": ip_local,
        "port": porta
    }

    abrir_tunel(config, device)

    ssh_cmd = gerar_ssh_cmd(config)
    print("##################################################################")
    p_green("Acesse essa máquina com")
    p_green(ssh_cmd)
    print("##################################################################")


def pid_existe(pid):
    try:
        processo = psutil.Process(pid)
        nome_processo = processo.name().lower()
        # p_red(f"$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$")
        # p_red(f"nome do processo {nome_processo}")

        if platform.system() == "Windows":
            return nome_processo == "ssh.exe"
        else:
            return nome_processo == "ssh"
    except psutil.NoSuchProcess:
        return False

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
                    pid = int(linha.split('pid:')[1].split('§§§§')[0])
                    if pid_existe(pid):
                        puts(f"🔁 PID {pid} já ativo para device_id {device_id}. Reutilizando conexão.")
                        return
                    else:
                        puts(f"💀 PID {pid} morto. Limpando entrada.")
                        desconectar_tunel_antigo(device_id)

    # Caminho correto para UserKnownHostsFile no Windows
    user_known_hosts = "NUL" if platform.system() == "Windows" else "/tmp/ssh_known_hosts_temp"

    # Comando SSH
    # comando_ssh = [
    #     'ssh', '-N',
    #     '-o', 'ServerAliveInterval=20',
    #     '-i', PEM_FILE,
    #     '-o', 'StrictHostKeyChecking=no',
    #     '-o', f'UserKnownHostsFile={user_known_hosts}',
    #     '-R', f'{porta_remota}:{host_local}:{porta_local}',
    #     f'{tunnel_user}@{tunnel_host}'
    # ]

    # comando_para_exibir = " ".join(comando_ssh)

    pem_file_str = str(PEM_FILE)

    # Verifica se host_local já contém ':', ou seja, já tem uma porta embutida
    if ':' in host_local:
        destino = host_local  # já está no formato IP:porta
    else:
        destino = f"{host_local}:{porta_local}"

    comando_ssh = [
        'ssh', '-N',
        '-o', 'ServerAliveInterval=20',
        '-i', f"{pem_file_str}",
        '-o', 'StrictHostKeyChecking=no',
        '-o', f'UserKnownHostsFile={user_known_hosts}',
        '-R', f'{porta_remota}:{destino}',
        f'{tunnel_user}@{tunnel_host}'
    ]



    # Execução do processo
    proc = subprocess.Popen(
        comando_ssh,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True  # funciona em Linux; no Windows é ignorado com segurança
    )

    # puts("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@")
    # puts("PEM_FILE")
    # puts(str(PEM_FILE))
    # mostrar_conteudo_pem(PEM_FILE)
    # puts("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@")

    puts("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
    comando_para_exibir = " ".join(comando_ssh)
    puts("O comando SSH que foi executado é:")
    puts(comando_para_exibir)
    puts("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")


    proc = subprocess.Popen(
        comando_ssh,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True
    )

    # Aguarde 2 segundos para ver se ele falha logo
    time.sleep(2)

    if proc.poll() is not None:
        stdout, stderr = proc.communicate()
        p_red(f"❌ ssh falhou com saída:\nSTDOUT: {stdout}\nSTDERR: {stderr}")
        return


    puts(f"✅ Túnel iniciado com PID {proc.pid}")
    p_green(f'pid: {proc.pid} - {destino} => {tunnel_host}:{porta_remota} ')
    salvar_conexao(proc.pid, device_id, host_local, porta_remota)
    # update_tunnel_devices(config, dispositivo, f'{tunnel_host}:{porta_remota}')
    update_tunnel_devices(config, dispositivo)


def get_cliente_id(config):
    if IS_WINDOWS:

      cliente_path = CLIENTE_TXT
      with open(cliente_path, "r", encoding="utf-8") as f:
          cliente_id = f.read().strip()
          if not cliente_id:
              # raise ValueError("cliente.txt está vazio.")
               cliente_id = config['sc_server']['cliente_id']
          if not cliente_id:
            p_red("❌ cliente_id não encontrado em cliente.txt nem em config.json. Instalação inválida.")
            raise
          return cliente_id
    else:
      return config['sc_server']['cliente_id']

    # cliente_path = PROJECT_DIR / "cliente.txt"
    # if not cliente_path.exists():
    #     if config['sc_server']['cliente_id']:
    #       return config['sc_server']['cliente_id']
    #     else:
    #       p_red("❌ cliente.txt não encontrado. Instalação inválida.")
    #       raise FileNotFoundError("cliente.txt não encontrado.")

    # try:
    #     with open(cliente_path, "r", encoding="utf-8") as f:
    #         cliente_id = f.read().strip()
    #         if not cliente_id:
    #             raise ValueError("cliente.txt está vazio.")
    #         return cliente_id
    # except Exception as e:
    #     p_red(f"❌ Falha ao ler cliente.txt: {e}")
    #     raise





# def obter_todas_interfaces():
#     """Retorna interfaces com IPs válidos, ativas e externas."""
#     interfaces_validas = []
#     stats = psutil.net_if_stats()
#     addrs = psutil.net_if_addrs()

#     puts("🔎 Verificando interfaces disponíveis...")
#     for iface in stats:
#         status = stats[iface]
#         ip = None

#         try:
#             ip = get_if_addr(iface)
#         except Exception as e:
#             p_yellow(f"⚠️ {iface}: erro ao obter IP ({e})")
#             continue

#         if not status.isup:
#             p_yellow(f"⚠️ {iface}: interface DOWN, ignorando.")
#             continue

#         if not ip or ip == "0.0.0.0" or ip.startswith("127.") or ip.startswith("169.254"):
#             p_yellow(f"⚠️ {iface}: IP inválido ({ip}), ignorando.")
#             continue

#         puts(f"✅ {iface}: IP={ip}, status=UP, adicionando para varredura.")
#         # interfaces_validas.append((iface, ip, "24"))
#         from ipaddress import IPv4Interface

#         subnet = str(IPv4Interface(f"{ip}/24").network)  # → ex: 192.168.15.0
#         interfaces_validas.append((iface, ip, subnet))

#     return interfaces_validas



def obter_todas_interfaces():
    """Retorna interfaces com IPs válidos, ativas e externas."""
    interfaces_validas = []
    stats = psutil.net_if_stats()
    addrs = psutil.net_if_addrs()

    print("🔎 Verificando interfaces disponíveis...")
    for iface in stats:
        status = stats[iface]
        if not status.isup:
            print(f"⚠️ {iface}: interface DOWN, ignorando.")
            continue

        for addr in addrs.get(iface, []):
            if addr.family.name != 'AF_INET':  # IPv4 apenas
                continue

            ip = addr.address
            if ip.startswith("127.") or ip.startswith("169.254") or ip == "0.0.0.0":
                print(f"⚠️ {iface}: IP inválido ({ip}), ignorando.")
                continue

            subnet = str(IPv4Interface(f"{ip}/24").network)
            print(f"✅ {iface}: IP={ip}, status=UP, adicionando para varredura.")
            interfaces_validas.append((iface, ip, subnet))

    return interfaces_validas


def executar_varredura():
    if not verificar_cap_net_raw():
        p_red("❌ Python atual não possui cap_net_raw. Use '/usr/bin/python3.10' com setcap.")
        return []

    puts("🌐 Varrendo todas as interfaces de rede ativas...")
    dispositivos = []
    interfaces_info = obter_todas_interfaces()

    for interface, ip, subnet in interfaces_info:
        try:
            puts(f"🛰️ Varredura ARP em {interface} ({ip}/{subnet})...")
            dispositivos += varredura_arp(interface, subnet)
            time.sleep(1)  # evita conflito entre varreduras
        except Exception as e:
            p_red(f"❌ Erro ao varrer interface {interface}: {e}")

    puts(f"🔍 {len(dispositivos)} dispositivos encontrados na rede.")
    return dispositivos

def consultar_erp(dispositivos_rede, config):
    puts("consultar_erp...")
    macs = sorted({d['mac'] for d in dispositivos_rede})
    mac_str = ','.join(macs)
    varredura_txt = '\n'.join(f"{d['ip']} {d['mac']}" for d in dispositivos_rede)

    cliente_id = get_cliente_id(config)
    puts("----------------------------------------------------------------")
    puts(f"Cliente Ativado {cliente_id}")
    puts("----------------------------------------------------------------")

    token = config['sc_server']['token']
    url = f"{config['sc_server']['host']}/portarias/get_tunnel_devices.json?token={token}&cliente_id={cliente_id}"

    payload = {
        "tunnel_macaddres": mac_str,
        "ssh_cmd": gerar_ssh_cmd(config),
        "varredura_rede": varredura_txt,
        "codigos": config['sc_server'].get('equipamento_codigos', [])
    }

    puts("🔗 Consultando ERP para obter dispositivos com túnel ativo...")
    try:
        res = requests.post(url, json=payload)
        res.raise_for_status()
        dispositivos = res.json().get('devices', [])
        puts(f"📦 {len(dispositivos)} dispositivos recebidos do ERP.")
        return dispositivos
    except Exception as e:
        p_red(f"❌ Erro ao consultar ERP: {e}")
        return None

def processar_dispositivos(dispositivos, dispositivos_rede, config):
    puts("---------------------------------------")
    p_green("Fazendo tunnels...")
    puts("---------------------------------------")
    for dispositivo in dispositivos:
        device_id = dispositivo['id']
        codigo = dispositivo.get('codigo')
        tunnel_me = dispositivo.get('tunnel_me')
        mac1 = dispositivo.get('mac_address')
        mac2 = dispositivo.get('mac_address_2')



        # ip = dispositivo.get('host') or buscar_ip_por_mac(mac1, dispositivos_rede) or buscar_ip_por_mac(mac2, dispositivos_rede)
        # ip =  buscar_ip_por_mac(mac1, dispositivos_rede) or buscar_ip_por_mac(mac2, dispositivos_rede) or dispositivo.get('ip')
        # ip =  buscar_ip_por_mac(mac1, dispositivos_rede) or buscar_ip_por_mac(mac2, dispositivos_rede) or dispositivo.get('host')

        # prioriza o IP do próprio dispositivo
        ip_cadastrado = dispositivo.get('ip')

        if ip_cadastrado:
            ip = ip_cadastrado
        else:
            ip = (
                buscar_ip_por_mac(mac1, dispositivos_rede)
                or buscar_ip_por_mac(mac2, dispositivos_rede)
                or None
            )


        if not ip:
            p_yellow(f"❌ Dispositivo #{codigo} sem IP conhecido.")
            continue

        dispositivo['host'] = ip

        if tunnel_me is False:
            puts(f"🔌 Dispositivo #{codigo} marcado para desconexão.")
            desconectar_tunel_antigo(device_id)
        elif tunnel_me is not None:
            puts(f"🔗 Dispositivo #{codigo} marcado para conexão.")
            desconectar_tunel_antigo(device_id)
            abrir_tunel(config, dispositivo)
            # tunnel_host = config['sc_tunnel_server']['host']
            # update_tunnel_devices(config, dispositivo, f"{tunnel_host}:{obter_porta_remota(tunnel_host)}")
        else:
            puts(f"🔍 Verificando conexão para o dispositivo #{codigo}.")
            garantir_conexao_do_device(config, dispositivo)


def main():
    puts("🚀 Iniciando execução do túnel reverso")

    if not PEM_FILE.exists():
        p_red("❌ Arquivo scTunnel.pem não encontrado.")
        return


    puts("📥 Carregando configurações do arquivo config.json")
    config = carregar_config()
    puts(json.dumps(config, indent=2, ensure_ascii=False))


    puts("Abrir ssh pra esse próprio device")
    abrir_ssh_desse_device(config)

    dispositivos_rede = executar_varredura()

    if not dispositivos_rede:
        p_yellow("⚠️ Nenhum dispositivo encontrado. Finalizando.")
        return

    dispositivos = consultar_erp(dispositivos_rede, config)
    if dispositivos is None:
        return

    processar_dispositivos(dispositivos, dispositivos_rede, config)
    puts("✅ Execução finalizada com sucesso.")




if __name__ == '__main__':
    main()
