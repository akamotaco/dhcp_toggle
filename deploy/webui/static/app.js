// --- API Helper ---
async function api(method, path, body) {
  const opts = { method, headers: {} };
  if (body) {
    opts.headers["Content-Type"] = "application/json";
    opts.body = JSON.stringify(body);
  }
  const res = await fetch("/api" + path, opts);
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.detail || "요청 실패");
  }
  return data;
}

// --- Toast ---
function toast(msg, type = "success") {
  const el = document.getElementById("toast");
  el.textContent = msg;
  el.className = "toast show " + type;
  setTimeout(() => { el.className = "toast"; }, 3000);
}

// --- Tab Navigation ---
document.querySelectorAll(".tab").forEach(btn => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach(b => b.classList.remove("active"));
    document.querySelectorAll(".panel").forEach(p => p.classList.remove("active"));
    btn.classList.add("active");
    const panel = document.getElementById(btn.dataset.tab);
    panel.classList.add("active");
    loadTab(btn.dataset.tab);
  });
});

function loadTab(tab) {
  switch (tab) {
    case "dashboard": loadDashboard(); break;
    case "clients": loadClients(); break;
    case "forwards": loadForwards(); break;
    case "logs": loadLogs(); break;
    case "settings": loadSettings(); break;
  }
}

// --- Dashboard ---
async function loadDashboard() {
  try {
    const status = await api("GET", "/status");
    const modeEl = document.getElementById("current-mode");
    modeEl.textContent = status.mode === "off" ? "OFF" : "모드 " + status.mode.toUpperCase();
    modeEl.className = "mode-display" + (status.mode === "off" ? " off" : "");

    // highlight active button
    ["a", "b", "c", "off"].forEach(m => {
      const btn = document.getElementById("btn-mode-" + m);
      btn.classList.toggle("active", status.mode === m);
    });

    // interfaces
    const tbody = document.querySelector("#iface-table tbody");
    tbody.innerHTML = "";
    for (const iface of status.interfaces) {
      const tr = document.createElement("tr");
      tr.innerHTML = `<td>${iface.name}</td><td>${iface.state}</td><td>${iface.addrs.join(", ") || "-"}</td>`;
      tbody.appendChild(tr);
    }

    // ip forward
    document.getElementById("ip-fwd").textContent = status.ip_forward ? "ON" : "OFF";
  } catch (e) {
    toast(e.message, "error");
  }
}

async function setMode(mode) {
  // disable buttons during switch
  document.querySelectorAll(".btn-mode, .btn-off").forEach(b => b.disabled = true);
  try {
    await api("POST", "/mode", { mode });
    toast("모드 " + mode.toUpperCase() + " 전환 완료");
    await loadDashboard();
  } catch (e) {
    toast(e.message, "error");
  } finally {
    document.querySelectorAll(".btn-mode, .btn-off").forEach(b => b.disabled = false);
  }
}

// --- Clients ---
async function loadClients() {
  try {
    const data = await api("GET", "/clients");

    document.getElementById("arp-iface").textContent = data.lan_iface || "-";

    // DHCP
    const dhcpTbody = document.querySelector("#dhcp-table tbody");
    dhcpTbody.innerHTML = "";
    if (data.dhcp.length === 0) {
      dhcpTbody.innerHTML = '<tr><td colspan="4" style="color:var(--text-dim)">(없음)</td></tr>';
    }
    for (const c of data.dhcp) {
      const expire = new Date(c.expire * 1000).toLocaleString("ko-KR", { month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit" });
      const tr = document.createElement("tr");
      tr.innerHTML = `<td>${c.mac}</td><td>${c.ip}</td><td>${c.hostname || "-"}</td><td>${expire}</td>`;
      dhcpTbody.appendChild(tr);
    }

    // ARP
    const arpTbody = document.querySelector("#arp-table tbody");
    arpTbody.innerHTML = "";
    if (data.arp.length === 0) {
      arpTbody.innerHTML = '<tr><td colspan="3" style="color:var(--text-dim)">(없음)</td></tr>';
    }
    for (const a of data.arp) {
      const tr = document.createElement("tr");
      tr.innerHTML = `<td>${a.ip}</td><td>${a.mac}</td><td>${a.state}</td>`;
      arpTbody.appendChild(tr);
    }
  } catch (e) {
    toast(e.message, "error");
  }
}

// --- Forwards ---
async function loadForwards() {
  try {
    const rules = await api("GET", "/forwards");
    const tbody = document.querySelector("#fwd-table tbody");
    tbody.innerHTML = "";
    if (rules.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" style="color:var(--text-dim)">(등록된 규칙 없음)</td></tr>';
      return;
    }
    for (const r of rules) {
      const tr = document.createElement("tr");
      const badge = r.enabled
        ? '<span class="badge badge-on">ON</span>'
        : '<span class="badge badge-off">OFF</span>';
      const toggleBtn = r.enabled
        ? `<button class="btn btn-sm btn-disable" onclick="toggleForward('${r.name}', false)">비활성화</button>`
        : `<button class="btn btn-sm btn-enable" onclick="toggleForward('${r.name}', true)">활성화</button>`;
      tr.innerHTML = `
        <td>${r.name}</td>
        <td>${r.ext_ports}</td>
        <td>${r.int_ip}</td>
        <td>${r.int_ports}</td>
        <td>${r.proto.toUpperCase()}</td>
        <td>${badge}</td>
        <td>
          ${toggleBtn}
          <button class="btn btn-sm btn-remove" onclick="removeForward('${r.name}')">삭제</button>
        </td>`;
      tbody.appendChild(tr);
    }
  } catch (e) {
    toast(e.message, "error");
  }
}

async function addForward(e) {
  e.preventDefault();
  const body = {
    name: document.getElementById("fwd-name").value,
    ext_ports: document.getElementById("fwd-ext").value,
    int_ip: document.getElementById("fwd-ip").value,
    int_ports: document.getElementById("fwd-int").value,
    proto: document.getElementById("fwd-proto").value,
  };
  try {
    await api("POST", "/forwards", body);
    toast("규칙 추가: " + body.name);
    document.getElementById("fwd-form").reset();
    await loadForwards();
  } catch (e) {
    toast(e.message, "error");
  }
}

async function toggleForward(name, enable) {
  try {
    const action = enable ? "enable" : "disable";
    await api("POST", `/forwards/${name}/${action}`);
    toast(`${name} ${enable ? "활성화" : "비활성화"}`);
    await loadForwards();
  } catch (e) {
    toast(e.message, "error");
  }
}

async function removeForward(name) {
  if (!confirm(`"${name}" 규칙을 삭제하시겠습니까?`)) return;
  try {
    await api("DELETE", `/forwards/${name}`);
    toast("규칙 삭제: " + name);
    await loadForwards();
  } catch (e) {
    toast(e.message, "error");
  }
}

// --- Logs ---
async function loadLogs() {
  try {
    const lines = document.getElementById("log-lines").value;
    const data = await api("GET", `/logs?lines=${lines}`);
    document.getElementById("log-output").textContent = data.lines.join("\n") || "(로그 없음)";
  } catch (e) {
    toast(e.message, "error");
  }
}

// --- Settings ---
async function loadSettings() {
  try {
    const data = await api("GET", "/webui");
    document.getElementById("webui-svc-status").textContent = data.service || "-";
    document.getElementById("webui-enabled").textContent = data.enabled ? "ON" : "OFF";
    document.getElementById("webui-port").value = data.port || 8080;
  } catch (e) {
    toast(e.message, "error");
  }
}

async function webuiToggle(enable) {
  try {
    await api("POST", enable ? "/webui/on" : "/webui/off");
    toast(enable ? "Web UI 활성화됨" : "Web UI 비활성화됨");
    await loadSettings();
  } catch (e) {
    toast(e.message, "error");
  }
}

async function webuiSetPort() {
  const port = parseInt(document.getElementById("webui-port").value);
  if (!port || port < 1 || port > 65535) {
    toast("포트 범위: 1-65535", "error");
    return;
  }
  if (!confirm(`포트를 ${port}로 변경하면 서비스가 재시작됩니다. 계속하시겠습니까?`)) return;
  try {
    await api("POST", "/webui/port", { port });
    toast(`포트 변경: ${port} — 새 주소로 접속하세요`);
  } catch (e) {
    toast(e.message, "error");
  }
}

// --- Auto refresh ---
let refreshTimer = null;

function startAutoRefresh() {
  if (refreshTimer) clearInterval(refreshTimer);
  refreshTimer = setInterval(() => {
    const activeTab = document.querySelector(".tab.active")?.dataset.tab;
    if (activeTab) loadTab(activeTab);
  }, 30000);
}

// --- Init ---
document.addEventListener("DOMContentLoaded", () => {
  loadDashboard();
  startAutoRefresh();
});
