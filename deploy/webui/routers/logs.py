import os
from fastapi import APIRouter, Query

router = APIRouter(tags=["logs"])

LOG_FILE = "/var/log/dhcp-toggle.log"


@router.get("/logs")
def get_logs(lines: int = Query(default=50, ge=1, le=1000)):
    if not os.path.exists(LOG_FILE):
        return {"lines": [], "total": 0}

    with open(LOG_FILE) as f:
        all_lines = f.readlines()

    tail = all_lines[-lines:] if len(all_lines) > lines else all_lines
    return {"lines": [l.rstrip() for l in tail], "total": len(all_lines)}
