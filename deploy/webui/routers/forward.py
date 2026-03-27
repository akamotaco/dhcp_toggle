import json
import os
import subprocess
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional

router = APIRouter(tags=["forward"])

TOGGLE_CMD = "/usr/local/bin/dhcp-toggle"
FORWARDS_FILE = "/var/lib/dhcp-toggle/forwards.json"


class ForwardAddRequest(BaseModel):
    name: str
    ext_ports: str
    int_ip: str
    int_ports: str
    proto: str = "tcp"


class ForwardToggleRequest(BaseModel):
    name: str


def run_cmd(args):
    result = subprocess.run(
        args, capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "Command failed"
        raise HTTPException(status_code=500, detail=detail)
    return result


def read_forwards():
    if not os.path.exists(FORWARDS_FILE):
        return []
    with open(FORWARDS_FILE) as f:
        return json.load(f)


@router.get("/forwards")
def list_forwards():
    return read_forwards()


@router.post("/forwards")
def add_forward(req: ForwardAddRequest):
    run_cmd(["sudo", TOGGLE_CMD, "forward", "add",
             req.name, req.ext_ports, req.int_ip, req.int_ports, req.proto])
    return {"message": f"규칙 추가 완료: {req.name}"}


@router.delete("/forwards/{name}")
def remove_forward(name: str):
    run_cmd(["sudo", TOGGLE_CMD, "forward", "remove", name])
    return {"message": f"규칙 제거 완료: {name}"}


@router.post("/forwards/{name}/enable")
def enable_forward(name: str):
    run_cmd(["sudo", TOGGLE_CMD, "forward", "enable", name])
    return {"message": f"규칙 활성화: {name}"}


@router.post("/forwards/{name}/disable")
def disable_forward(name: str):
    run_cmd(["sudo", TOGGLE_CMD, "forward", "disable", name])
    return {"message": f"규칙 비활성화: {name}"}
