import os
import subprocess
from fastapi import APIRouter

router = APIRouter(tags=["clients"])

STATE_FILE = "/var/lib/dhcp-toggle/mode"
LEASE_FILE = "/var/lib/misc/dnsmasq.leases"


def get_mode():
    try:
        with open(STATE_FILE) as f:
            return f.read().strip()
    except FileNotFoundError:
        return "off"


@router.get("/clients")
def get_clients():
    mode = get_mode()
    if mode == "off":
        return {"mode": mode, "dhcp": [], "arp": []}

    lan_iface = "eth1" if mode == "a" else "br0"  # b, c 모두 br0

    # DHCP leases
    dhcp = []
    if os.path.exists(LEASE_FILE):
        with open(LEASE_FILE) as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 4:
                    dhcp.append({
                        "expire": int(parts[0]),
                        "mac": parts[1],
                        "ip": parts[2],
                        "hostname": parts[3] if parts[3] != "*" else "",
                    })

    # ARP table
    arp = []
    result = subprocess.run(
        ["ip", "neigh", "show", "dev", lan_iface],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        for line in result.stdout.strip().split("\n"):
            parts = line.split()
            if len(parts) >= 4:
                arp.append({
                    "ip": parts[0],
                    "mac": parts[2] if len(parts) > 2 else "",
                    "state": parts[-1],
                })

    return {"mode": mode, "lan_iface": lan_iface, "dhcp": dhcp, "arp": arp}
