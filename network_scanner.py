# network_scanner.py

from scapy.all import ARP, Ether, srp

import os
import platform
import logging
import shutil

def verificar_cap_net_raw():
    """Verifica se o binário atual tem permissão cap_net_raw."""
    if platform.system().lower() == "linux":
        bin_path = os.readlink("/proc/self/exe")

        # Usa o caminho absoluto do getcap
        getcap_path = shutil.which("getcap") or "/usr/sbin/getcap"
        if not os.path.isfile(getcap_path):
            logging.warning(f"getcap não encontrado em PATH nem em /usr/sbin")
            return False

        caps = os.popen(f"{getcap_path} {bin_path}").read()
        logging.info(f"Python bin path: {bin_path}")
        logging.info(f"getcap path: {getcap_path}")
        logging.info(f"caps: {caps}")

        return "cap_net_raw" in caps

    return True  # Assume que no Windows funciona com Npcap



# def verificar_cap_net_raw():
#     """Verifica se o binário atual tem permissão cap_net_raw."""
#     if platform.system().lower() == "linux":
#         import os
#         bin_path = os.readlink("/proc/self/exe")
#         caps = os.popen(f"getcap {bin_path}").read()
#         logging.info('caps')
#         logging.info(caps)
#         return "cap_net_raw" in caps
#     return True  # Assume que no Windows funciona com Npcap

def varredura_arp(interface, subnet):
    logging.info(f"Escaneando rede {subnet} via {interface} usando Scapy...")
    pkt = Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=f"{subnet}")
    # pkt = Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=f"{subnet}/24")
    try:
        ans, _ = srp(pkt, timeout=2, iface=interface, verbose=False)
        logging.info(f"resposta ARP: {ans} ")
        logging.info(f"{len(ans)} respostas recebidas de ARP")
        resultados = []
        for snd, rcv in ans:
            logging.info(f"\033[0;32mIP={rcv.psrc} MAC={rcv.hwsrc}\033[0m")
            # logging.info(f"Recebido: IP={rcv.psrc} MAC={rcv.hwsrc}")
            resultados.append({"ip": rcv.psrc, "mac": rcv.hwsrc})
        return resultados
    except PermissionError:
        logging.error("❌ Scapy falhou: sem permissão para usar raw socket.")
        raise
    except Exception as e:
        logging.error(f"❌ Erro inesperado durante varredura com Scapy: {e}")
        raise
