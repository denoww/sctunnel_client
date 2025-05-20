import os
import json
import subprocess
import threading
import time
import socket
import logging
import psutil
import requests
from sshtunnel import SSHTunnelForwarder
from scapy.all import ARP, Ether, srp

# Configurar o logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Carregar configurações do arquivo JSON
def carregar_configuracoes(caminho_config):
    with open(caminho_config, 'r') as arquivo:
        return json.load(arquivo)

# Obter informações da interface de rede
def obter_interface_e_ip():
    try:
        # Obter o nome da interface de rede padrão
        interfaces = psutil.net_if_addrs()
        for interface_nome, enderecos in interfaces.items():
            for endereco in enderecos:
                if endereco.family == socket.AF_INET and not endereco.address.startswith("127."):
                    return interface_nome, endereco.address
    except Exception as e:
        logging.error(f"Erro ao obter interface de rede: {e}")
    return None, None

# Realizar varredura ARP na rede local
def varredura_arp(interface, ip_rede):
    try:
        logging.info(f"Iniciando varredura ARP na rede {ip_rede} pela interface {interface}")
        pacote = Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=ip_rede)
        resultado = srp(pacote, timeout=3, iface=interface, inter=0.1, verbose=False)[0]
        dispositivos = []
        for _, recebido in resultado:
            dispositivos.append({'ip': recebido.psrc, 'mac': recebido.hwsrc})
        return dispositivos
    except Exception as e:
        logging.error(f"Erro na varredura ARP: {e}")
        return []

# Estabelecer túnel SSH para um dispositivo
def estabelecer_tunel_ssh(config, dispositivo):
    try:
        ssh_host = config['sc_tunnel_server']['host']
        ssh_usuario = config['sc_tunnel_server']['user']
        ssh_chave = os.path.join(os.path.dirname(__file__), 'scTunnel.pem')
        dispositivo_host = dispositivo['host']
        dispositivo_porta = dispositivo.get('port', 80)
        porta_remota = dispositivo.get('tunnel_porta', 0)

        if not porta_remota:
            # Obter porta remota disponível via API
            resposta = requests.get(f"http://{ssh_host}:3020/unused_ports?qtd=1")
            if resposta.status_code == 200:
                porta_remota = resposta.json()['portas'][0]
            else:
                logging.error("Não foi possível obter porta remota disponível.")
                return

        servidor = SSHTunnelForwarder(
            (ssh_host, 22),
            ssh_username=ssh_usuario,
            ssh_pkey=ssh_chave,
            remote_bind_address=(dispositivo_host, dispositivo_porta),
            local_bind_address=('0.0.0.0', porta_remota)
        )

        servidor.start()
        logging.info(f"Túnel SSH estabelecido: {servidor.local_bind_host}:{servidor.local_bind_port} -> {dispositivo_host}:{dispositivo_porta}")

        # Manter o túnel ativo em uma thread separada
        threading.Thread(target=manter_tunel_ativo, args=(servidor,), daemon=True).start()

        # Atualizar informações do túnel no ERP
        atualizar_erp(config, dispositivo, f"{ssh_host}:{porta_remota}")

    except Exception as e:
        logging.error(f"Erro ao estabelecer túnel SSH: {e}")

# Manter o túnel SSH ativo
def manter_tunel_ativo(servidor):
    try:
        while True:
            time.sleep(60)
    except KeyboardInterrupt:
        servidor.stop()
        logging.info("Túnel SSH encerrado.")

# Atualizar informações do túnel no ERP
def atualizar_erp(config, dispositivo, endereco_tunel):
    try:
        host_erp = config['sc_server']['host']
        token = config['sc_server']['token']
        cliente_id = config['sc_server']['cliente_id']
        dispositivo_id = dispositivo['id']

        url = f"{host_erp}/portarias/update_tunnel_devices.json?token={token}&cliente_id={cliente_id}"
        payload = {
            "id": dispositivo_id,
            "tunnel_address": endereco_tunel,
            "cliente_id": cliente_id
        }

        resposta = requests.post(url, json=payload)
        if resposta.status_code == 200:
            logging.info(f"Informações do túnel atualizadas no ERP para o dispositivo {dispositivo_id}.")
        else:
            logging.error(f"Falha ao atualizar ERP: {resposta.status_code} - {resposta.text}")

    except Exception as e:
        logging.error(f"Erro ao atualizar ERP: {e}")

# Função principal
def main():
    caminho_config = os.path.join(os.path.dirname(__file__), 'config.json')
    config = carregar_configuracoes(caminho_config)

    interface, ip_local = obter_interface_e_ip()
    if not interface or not ip_local:
        logging.error("Não foi possível determinar a interface de rede ou o IP local.")
        return

    # Determinar a sub-rede (assumindo máscara /24)
    ip_rede = '.'.join(ip_local.split('.')[:3]) + '.0/24'

    dispositivos_rede = varredura_arp(interface, ip_rede)
    logging.info(f"Dispositivos encontrados na rede: {dispositivos_rede}")

    # Obter lista de dispositivos para estabelecer túneis via API
    host_erp = config['sc_server']['host']
    token = config['sc_server']['token']
    cliente_id = config['sc_server']['cliente_id']
    url = f"{host_erp}/portarias/get_tunnel_devices.json?token={token}&cliente_id={cliente_id}"

    try:
        resposta = requests.get(url)
        if resposta.status_code == 200:
            dispositivos = resposta.json().get('devices', [])
            for dispositivo in dispositivos:
                # Verificar se o dispositivo está na rede local
                mac_dispositivo = dispositivo.get('mac_address')
                for dispositivo_rede in dispositivos_rede:
                    if dispositivo_rede['mac'].lower() == mac_dispositivo.lower():
                        dispositivo['host'] = dispositivo_rede['ip']
                        break
                else:
                    logging.warning(f"Dispositivo {dispositivo.get('codigo')} não encontrado na rede local.")
                    continue

                if dispositivo.get('tunnel_me') is True:
                    estabelecer_tunel_ssh(config, dispositivo)
        else:
            logging.error(f"Falha ao obter dispositivos do ERP: {resposta.status_code} - {resposta.text}")
    except Exception as e:
        logging.error(f"Erro ao obter dispositivos do ERP: {e}")

if __name__ == "__main__":
    main()
