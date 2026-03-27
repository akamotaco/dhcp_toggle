import json
import os
import subprocess
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional

router = APIRouter(tags=["webui"])

TOGGLE_CMD = "/usr/local/bin/dhcp-toggle"
WEBUI_CONF = "/var/lib/dhcp-toggle/webui.json"


def read_conf():
    if not os.path.exists(WEBUI_CONF):
        return {"port": 8080, "enabled": True}
    with open(WEBUI_CONF) as f:
        return json.load(f)


class WebuiPortRequest(BaseModel):
    port: int


@router.get("/webui")
def get_webui_status():
    conf = read_conf()
    svc = subprocess.run(
        ["systemctl", "is-active", "dhcp-toggle-webui"],
        capture_output=True, text=True
    )
    conf["service"] = svc.stdout.strip()
    return conf


@router.post("/webui/port")
def set_webui_port(req: WebuiPortRequest):
    if req.port < 1 or req.port > 65535:
        raise HTTPException(status_code=400, detail="포트 범위: 1-65535")
    result = subprocess.run(
        ["sudo", TOGGLE_CMD, "webui", "port", str(req.port)],
        capture_output=True, text=True, timeout=10
    )
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=result.stderr.strip())
    return {"message": f"포트 변경: {req.port} (서비스 재시작됨)"}


@router.post("/webui/on")
def webui_on():
    result = subprocess.run(
        ["sudo", TOGGLE_CMD, "webui", "on"],
        capture_output=True, text=True, timeout=10
    )
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=result.stderr.strip())
    return {"message": "Web UI 활성화됨"}


@router.post("/webui/off")
def webui_off():
    result = subprocess.run(
        ["sudo", TOGGLE_CMD, "webui", "off"],
        capture_output=True, text=True, timeout=10
    )
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=result.stderr.strip())
    return {"message": "Web UI 비활성화됨"}
