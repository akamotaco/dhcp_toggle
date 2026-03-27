import subprocess
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(tags=["mode"])

TOGGLE_CMD = "/usr/local/bin/dhcp-toggle"
STATE_FILE = "/var/lib/dhcp-toggle/mode"


class ModeRequest(BaseModel):
    mode: str


def run_cmd(args, check=True):
    result = subprocess.run(
        args, capture_output=True, text=True, timeout=30
    )
    if check and result.returncode != 0:
        raise HTTPException(status_code=500, detail=result.stderr.strip() or "Command failed")
    return result


@router.get("/mode")
def get_mode():
    try:
        with open(STATE_FILE) as f:
            current = f.read().strip()
    except FileNotFoundError:
        current = "off"
    return {"mode": current}


@router.post("/mode")
def set_mode(req: ModeRequest):
    if req.mode not in ("a", "b", "off"):
        raise HTTPException(status_code=400, detail="모드는 a, b, off 중 하나")
    run_cmd(["sudo", TOGGLE_CMD, req.mode])
    return {"mode": req.mode, "message": f"모드 {req.mode} 전환 완료"}


@router.get("/status")
def get_status():
    try:
        with open(STATE_FILE) as f:
            current = f.read().strip()
    except FileNotFoundError:
        current = "off"

    info = {"mode": current, "interfaces": [], "ip_forward": False}

    # interfaces
    result = subprocess.run(["ip", "-br", "addr", "show"], capture_output=True, text=True)
    if result.returncode == 0:
        for line in result.stdout.strip().split("\n"):
            parts = line.split()
            if len(parts) >= 2:
                iface = {"name": parts[0], "state": parts[1], "addrs": parts[2:]}
                info["interfaces"].append(iface)

    # ip_forward
    result = subprocess.run(["sysctl", "-n", "net.ipv4.ip_forward"], capture_output=True, text=True)
    if result.returncode == 0:
        info["ip_forward"] = result.stdout.strip() == "1"

    return info
