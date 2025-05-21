# network_scanner.py
import platform
import logging
from scapy.all import ARP, Ether, srp

def verificar_cap_net_raw():
    """Verifica se o binário atual tem permissão cap_net_raw."""
    if platform.system().lower() == "linux":
        import os
        bin_path = os.readlink("/proc/self/exe")
        caps = os.popen(f"getcap {bin_path}").read()
        return "cap_net_raw" in caps
    return True  # Assume que no Windows funciona com Npcap

def varredura_arp(interface, subnet):
    logging.info(f"Escaneando rede {subnet} via {interface} usando Scapy...")
    pkt = Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=f"{subnet}/24")
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
