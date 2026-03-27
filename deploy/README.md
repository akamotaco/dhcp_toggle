# dhcp-toggle

NanoPi R6S (aarch64) 용 DHCP 서버 모드 토글 도구.
필요에 따라 장비를 라우터 모드로 전환하거나 일반 데스크톱으로 복귀할 수 있다.

## 기능 요약

- **모드 전환**: 유선/Wi-Fi WAN 라우터 모드, 데스크톱 모드 간 원클릭 전환
- **포트포워딩**: 정책(named rule) 기반 DNAT 규칙 관리 (enable/disable 가능)
- **Web UI**: 브라우저에서 모드 전환, 포워딩, 클라이언트 조회, 로그 확인
- **클라이언트 조회**: DHCP 리스 + ARP 테이블 결합 출력
- **로그**: 모든 동작을 타임스탬프와 함께 기록

---

## 동작 모드

| 모드 | WAN | LAN | 설명 |
|------|-----|-----|------|
| `off` | — | — | DHCP 서버 비활성 (데스크톱 모드) |
| `a` | eth0 (DHCP client) | eth1 (192.168.10.1/24) | 유선 WAN |
| `b` | wlan0 | br0: eth0+eth1 (192.168.10.1/24) | Wi-Fi WAN |

### 모드 A: 유선 WAN
```
[인터넷] → eth0 (WAN, DHCP client) → NAT → eth1 (LAN, DHCP server)
```

### 모드 B: Wi-Fi WAN
```
[인터넷] → wlan0 (WAN) → NAT → br0 [eth0 + eth1] (LAN, DHCP server)
```

### 네트워크 설정

| 항목 | 값 |
|------|-----|
| LAN IP | 192.168.10.1/24 |
| DHCP 범위 | 192.168.10.100 ~ 192.168.10.200 |
| DNS | 8.8.8.8, 8.8.4.4 |
| 리스 시간 | 12시간 |

---

## 요구 사항

- Linux + systemd (Ubuntu arm64 기준)
- dnsmasq-base
- iptables
- iproute2 (`ip` 명령)
- jq (포트포워딩 JSON 처리)
- python3-fastapi, python3-uvicorn (Web UI, apt 설치)

---

## 설치

```bash
tar xzf dhcp-toggle.tar.gz
cd dhcp-toggle
sudo bash install.sh
```

`install.sh`는 다음을 수행한다:
1. 패키지 설치 (`iptables`, `jq`)
2. dnsmasq 설정 파일 배포
3. 메인 스크립트 `/usr/local/bin/dhcp-toggle` 설치
4. sudoers 설정 (pi 사용자 NOPASSWD)
5. systemd 서비스 등록
6. Web UI: apt로 python3-fastapi/uvicorn 설치, 서비스 자동 시작

## 제거

```bash
sudo bash /usr/local/share/dhcp-toggle/uninstall.sh
```

---

## 사용법

### 모드 전환

```bash
sudo dhcp-toggle a          # 모드 A 활성화 (eth0=WAN, eth1=LAN)
sudo dhcp-toggle b          # 모드 B 활성화 (wlan0=WAN, eth0+eth1=LAN)
sudo dhcp-toggle off        # 전부 해제 (데스크톱 모드)
dhcp-toggle status          # 현재 상태 확인 (sudo 불필요)
```

### 포트포워딩

정책(named rule) 기반으로 관리한다. 규칙마다 이름이 있고, enable/disable로 iptables 적용 여부를 제어한다.

```bash
# 규칙 추가
sudo dhcp-toggle forward add http_s 80,443 192.168.10.101 80,443 tcp
sudo dhcp-toggle forward add game 25565 192.168.10.102 25565 both
sudo dhcp-toggle forward add cams 8080-8090 192.168.10.103 8080-8090 tcp

# 규칙 활성화/비활성화 (iptables 적용만 토글, 설정은 유지)
sudo dhcp-toggle forward disable http_s
sudo dhcp-toggle forward enable http_s

# 규칙 삭제
sudo dhcp-toggle forward remove http_s

# 목록 확인 (sudo 불필요)
dhcp-toggle forward list
```

**포트 형식:**
| 형식 | 예시 | 설명 |
|------|------|------|
| 단일 포트 | `80` | 하나의 포트 |
| 포트 범위 | `8080-8090` | 연속 범위 (iptables `--dport 8080:8090`) |
| 복수 포트 | `80,443` | 쉼표 구분 (iptables `-m multiport`) |

**프로토콜:** `tcp`, `udp`, `both` (기본: tcp)

**동작 방식:**
- 규칙은 `/var/lib/dhcp-toggle/forwards.json`에 영구 저장
- 모드 전환(a, b) 시 enabled 규칙이 자동 복원
- off 모드에서도 규칙 추가 가능 (모드 전환 시 적용)

### 클라이언트 조회

```bash
dhcp-toggle clients         # 접속 클라이언트 목록
```

DHCP 리스(`/var/lib/misc/dnsmasq.leases`)와 ARP 테이블을 결합하여 출력한다.

### Web UI

```bash
sudo dhcp-toggle webui on           # 활성화 + 시작
sudo dhcp-toggle webui off          # 비활성화 + 중지
sudo dhcp-toggle webui port 9090    # 포트 변경 (자동 재시작)
dhcp-toggle webui status            # 상태 확인
```

기본 접속: `http://192.168.10.1:8080`

설정은 `/var/lib/dhcp-toggle/webui.json`에 저장되어 재부팅 후에도 유지된다.

Web UI 탭 구성:
- **대시보드**: 현재 모드 표시 + 모드 전환 버튼 + 인터페이스 상태
- **클라이언트**: DHCP 리스 + ARP 테이블 (30초 자동 갱신)
- **포트포워딩**: 규칙 추가/삭제/활성화/비활성화
- **로그**: 동작 로그 조회
- **설정**: Web UI 포트 변경, on/off

### 로그

```bash
dhcp-toggle log             # 최근 50줄
dhcp-toggle log 100         # 최근 100줄
```

로그 파일: `/var/log/dhcp-toggle.log`

---

## 설치되는 파일

| 경로 | 설명 |
|------|------|
| `/usr/local/bin/dhcp-toggle` | 메인 토글 스크립트 |
| `/usr/local/share/dhcp-toggle/dhcp-mode-a.conf` | 모드 A dnsmasq 설정 |
| `/usr/local/share/dhcp-toggle/dhcp-mode-b.conf` | 모드 B dnsmasq 설정 |
| `/usr/local/share/dhcp-toggle/uninstall.sh` | 제거 스크립트 |
| `/usr/local/share/dhcp-toggle/webui/` | Web UI (FastAPI + 정적 파일) |
| `/etc/dnsmasq.d/dhcp-active.conf` | 활성 모드 설정 (런타임 생성) |
| `/etc/sudoers.d/dhcp-toggle` | sudo 권한 설정 |
| `/etc/systemd/system/dhcp-toggle.service` | DHCP 모드 systemd 서비스 |
| `/etc/systemd/system/dhcp-toggle-webui.service` | Web UI systemd 서비스 |
| `/var/lib/dhcp-toggle/mode` | 현재 모드 상태 파일 |
| `/var/lib/dhcp-toggle/forwards.json` | 포트포워딩 규칙 (영구) |
| `/var/lib/dhcp-toggle/webui.json` | Web UI 설정 (포트, on/off) |
| `/var/log/dhcp-toggle.log` | 동작 로그 |

---

## 아키텍처

### 코드 구조

```
deploy/
├── dhcp-toggle                 # 메인 bash 스크립트 (모든 CLI 기능)
├── dhcp-mode-a.conf            # 모드 A dnsmasq 설정
├── dhcp-mode-b.conf            # 모드 B dnsmasq 설정
├── dhcp-toggle.service         # DHCP 모드 systemd 서비스
├── dhcp-toggle-webui.service   # Web UI systemd 서비스
├── dhcp-toggle.sudoers         # sudoers 설정
├── install.sh                  # 설치 스크립트
├── uninstall.sh                # 제거 스크립트
└── webui/
    ├── app.py                  # FastAPI 메인 앱
    ├── routers/
    │   ├── mode.py             # GET/POST /api/mode, /api/status
    │   ├── forward.py          # CRUD  /api/forwards
    │   ├── clients.py          # GET   /api/clients
    │   ├── logs.py             # GET   /api/logs
    │   └── webui.py            # GET/POST /api/webui
    └── static/
        ├── index.html          # SPA 메인 페이지
        ├── style.css           # 다크 테마 CSS
        └── app.js              # 프론트엔드 로직
```

### 설계 원칙

- **Web UI는 CLI를 감싼다**: 모든 시스템 조작은 `subprocess.run(["sudo", "dhcp-toggle", ...])` 으로 CLI를 호출. FastAPI가 직접 iptables나 시스템 파일을 건드리지 않는다.
- **권한 분리**: Web UI는 `pi` 사용자로 실행. root 권한이 필요한 작업만 sudo로 호출.
- **설정 영구화**: 포트포워딩(`forwards.json`), Web UI 설정(`webui.json`)은 JSON 파일에 저장하여 재부팅/모드 전환 후에도 유지.
- **iptables comment 기반 관리**: 포워딩 규칙에 `--comment "fwd:<이름>"` 을 붙여서 규칙별 추가/제거를 안전하게 처리.

### 모드 전환 흐름

```
dhcp-toggle a/b 실행
  → cleanup()        # 이전 모드 정리: dnsmasq 정지, iptables 초기화, 브릿지 제거
  → mode_a()/mode_b() # 인터페이스 설정, dnsmasq 설정 복사, NAT 규칙 추가
  → restore_forwards() # forwards.json에서 enabled 규칙 iptables 적용
```

### iptables 규칙 구조

모드 활성화 시 적용되는 규칙:

```
# NAT (POSTROUTING) — 모드 전환 시 자동 설정
-t nat -A POSTROUTING -o <WAN인터페이스> -j MASQUERADE

# FORWARD — LAN↔WAN 양방향 허용
-A FORWARD -i <LAN인터페이스> -o <WAN인터페이스> -j ACCEPT
-A FORWARD -i <WAN인터페이스> -o <LAN인터페이스> -m state --state RELATED,ESTABLISHED -j ACCEPT

# 포트포워딩 (PREROUTING) — forwards.json에서 자동 복원
-t nat -A PREROUTING -i <WAN인터페이스> -p <proto> --dport <외부포트> \
    -j DNAT --to-destination <내부IP>:<내부포트> -m comment --comment "fwd:<이름>"
-A FORWARD -p <proto> -d <내부IP> --dport <내부포트> -j ACCEPT \
    -m comment --comment "fwd:<이름>"
```

---

## 커스터마이징: 새 모드 추가하기

다른 장비나 다른 인터페이스 구성으로 "모드 C"를 추가하려면 아래 파일들을 수정한다.

### 1단계: dnsmasq 설정 파일 생성

`deploy/dhcp-mode-c.conf` 생성:

```conf
# DHCP 모드 C: <WAN설명>, <LAN설명>
# 이 파일은 dhcp-toggle 스크립트가 관리합니다. 직접 수정하지 마세요.

interface=<LAN인터페이스>     # 예: eth2, br0 등 DHCP 서버가 바인딩할 인터페이스
bind-interfaces

dhcp-range=<시작IP>,<끝IP>,<서브넷마스크>,<리스시간>
# 예: dhcp-range=192.168.20.100,192.168.20.200,255.255.255.0,12h

dhcp-option=option:router,<게이트웨이IP>
# 예: dhcp-option=option:router,192.168.20.1

dhcp-option=option:dns-server,8.8.8.8,8.8.4.4

log-dhcp
```

**핵심 설정값:**
- `interface`: DHCP를 제공할 LAN 인터페이스. 브릿지 사용 시 `br0` 등.
- `dhcp-range`: 할당할 IP 범위, 서브넷 마스크, 리스 시간
- `dhcp-option=option:router`: 클라이언트에게 알려줄 게이트웨이 (보통 이 장비의 LAN IP)

### 2단계: dhcp-toggle 스크립트 수정

`deploy/dhcp-toggle` 파일에서 다음 부분을 수정한다:

**(a) 서브넷이 다르다면 상수 추가 (파일 상단)**

기존:
```bash
LAN_IP="192.168.10.1"
LAN_MASK="24"
```
모드 C가 다른 서브넷을 사용한다면 `mode_c()` 함수 안에서 직접 지정하면 된다.

**(b) `mode_c()` 함수 추가 (`mode_b()` 아래)**

```bash
mode_c() {
    log_info "모드 C 활성화: <설명>"

    # --- 인터페이스 설정 ---
    # WAN 인터페이스 UP + IP 획득
    ip link set <WAN인터페이스> up
    # DHCP 클라이언트로 IP 받기 (유선 WAN의 경우):
    dhclient -nw <WAN인터페이스> 2>/dev/null || log_warn "DHCP 클라이언트 실패"
    # 또는 고정 IP:
    # ip addr add <WAN_IP>/<MASK> dev <WAN인터페이스>

    # LAN 인터페이스 UP + 고정 IP
    ip link set <LAN인터페이스> up
    ip addr add <LAN_IP>/<LAN_MASK> dev <LAN인터페이스> 2>/dev/null || true

    # (선택) 브릿지가 필요한 경우:
    # ip link add name br0 type bridge
    # ip link set <인터페이스1> master br0
    # ip link set <인터페이스2> master br0
    # ip link set br0 up
    # ip addr add <LAN_IP>/<LAN_MASK> dev br0

    # --- dnsmasq 설정 활성화 ---
    cp /usr/local/share/dhcp-toggle/dhcp-mode-c.conf "$ACTIVE_CONF"
    systemctl restart dnsmasq

    # --- IP 포워딩 ---
    sysctl -q net.ipv4.ip_forward=1

    # --- NAT ---
    iptables -t nat -A POSTROUTING -o <WAN인터페이스> -j MASQUERADE
    iptables -A FORWARD -i <LAN인터페이스> -o <WAN인터페이스> -j ACCEPT
    iptables -A FORWARD -i <WAN인터페이스> -o <LAN인터페이스> -m state --state RELATED,ESTABLISHED -j ACCEPT

    save_mode "c"
    restore_forwards
    log_info "모드 C 활성화 완료"
}
```

**(c) `get_wan_iface()`에 모드 C 추가**

```bash
get_wan_iface() {
    local mode
    mode=$(get_current_mode)
    case "$mode" in
        a) echo "eth0" ;;
        b) echo "wlan0" ;;
        c) echo "<WAN인터페이스>" ;;   # ← 추가
        *) echo "" ;;
    esac
}
```

**(d) `show_clients()`의 LAN 인터페이스 매핑 추가**

```bash
case "$mode" in
    a) lan_iface="eth1" ;;
    b) lan_iface="br0" ;;
    c) lan_iface="<LAN인터페이스>" ;;   # ← 추가
esac
```

**(e) `cleanup()` 수정**

브릿지나 추가 인터페이스를 사용한다면 `cleanup()`에 정리 로직 추가:
```bash
# 모드 C 정리가 필요하면 여기에 추가
ip addr flush dev <추가인터페이스> 2>/dev/null || true
```

**(f) main case문에 모드 C 추가**

```bash
c)
    require_root
    cleanup
    mode_c
    ;;
```

### 3단계: install.sh 수정

`install.sh`에 새 설정 파일 복사 추가:
```bash
cp "$SCRIPT_DIR/dhcp-mode-c.conf" /usr/local/share/dhcp-toggle/
```

### 4단계: (선택) Web UI 모드 버튼 추가

`webui/static/index.html`에 버튼 추가:
```html
<button onclick="setMode('c')" class="btn btn-mode" id="btn-mode-c">
  모드 C<br><small>설명</small>
</button>
```

`webui/routers/mode.py`에서 허용 모드 추가:
```python
if req.mode not in ("a", "b", "c", "off"):
```

`webui/static/app.js`에서 버튼 하이라이트 추가:
```javascript
["a", "b", "c", "off"].forEach(m => { ... });
```

### 수정 요약 체크리스트

| 파일 | 수정 내용 |
|------|-----------|
| `deploy/dhcp-mode-c.conf` | **신규** — dnsmasq 설정 |
| `deploy/dhcp-toggle` | `mode_c()` 함수, `get_wan_iface()`, `show_clients()`, `cleanup()`, main case |
| `deploy/install.sh` | conf 파일 복사 추가 |
| `webui/static/index.html` | 모드 버튼 추가 (선택) |
| `webui/routers/mode.py` | 허용 모드 추가 (선택) |
| `webui/static/app.js` | 버튼 하이라이트 (선택) |

### 다른 장비에 적용할 때 확인할 것

| 항목 | 확인 방법 | 수정 위치 |
|------|-----------|-----------|
| 인터페이스 이름 | `ip link show` | dhcp-toggle 상수, conf 파일 |
| LAN 서브넷 | 네트워크 설계에 따라 | dhcp-toggle `LAN_IP`, conf `dhcp-range` |
| WAN IP 획득 방식 | DHCP client / 고정 IP / PPPoE | `mode_x()` 함수 |
| 사용자명 | `whoami` | sudoers 파일 (`pi` → 실제 사용자) |
| DNS 서버 | 정책에 따라 | conf `dhcp-option=option:dns-server` |
| dnsmasq 리스 파일 경로 | 배포판마다 다름 | dhcp-toggle `lease_file`, clients.py `LEASE_FILE` |

---

## 부팅 시 자동 실행

기본 설치 시 DHCP 모드 자동 실행 안 됨. 원하는 경우:

```bash
# 서비스 파일에서 ExecStart 의 모드를 원하는 값으로 수정 후:
sudo systemctl enable dhcp-toggle
```

Web UI는 설치 시 자동 시작된다. `dhcp-toggle webui off`로 비활성화 가능.

---

## 라이선스

자유롭게 사용/수정 가능
