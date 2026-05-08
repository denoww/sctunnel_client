"""ARP scan helpers using Scapy. Linux-only."""
import logging
import os
import shutil

from scapy.all import ARP, Ether, srp


def has_cap_net_raw():
    """True if the running Python binary holds cap_net_raw (required for raw sockets without root)."""
    bin_path = os.readlink("/proc/self/exe")
    getcap = shutil.which("getcap") or "/usr/sbin/getcap"
    if not os.path.isfile(getcap):
        logging.warning("getcap not found")
        return False
    caps = os.popen(f"{getcap} {bin_path}").read()
    return "cap_net_raw" in caps


def arp_scan(interface, subnet):
    """Send a broadcast ARP for `subnet` on `interface`. Returns [{ip, mac}, ...]."""
    logging.info(f"ARP scan {subnet} on {interface}")
    pkt = Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=subnet)
    answered, _ = srp(pkt, timeout=2, iface=interface, verbose=False)
    results = [{"ip": rcv.psrc, "mac": rcv.hwsrc} for _, rcv in answered]
    logging.info(f"ARP scan {interface}: {len(results)} replies")
    return results
