#!/usr/bin/env python3
"""dhcp-toggle Web UI — FastAPI backend"""

import json
import os

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from routers import mode, forward, clients, logs, webui

CONFIG_FILE = "/var/lib/dhcp-toggle/webui.json"
DEFAULT_PORT = 8080


def load_config():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE) as f:
            return json.load(f)
    return {"port": DEFAULT_PORT}


app = FastAPI(title="dhcp-toggle", docs_url="/api/docs")

app.include_router(mode.router, prefix="/api")
app.include_router(forward.router, prefix="/api")
app.include_router(clients.router, prefix="/api")
app.include_router(logs.router, prefix="/api")
app.include_router(webui.router, prefix="/api")

app.mount("/", StaticFiles(directory=os.path.join(os.path.dirname(__file__), "static"), html=True), name="static")


def main():
    import uvicorn
    config = load_config()
    port = int(config.get("port", DEFAULT_PORT))
    uvicorn.run("app:app", host="0.0.0.0", port=port, log_level="info")


if __name__ == "__main__":
    main()
