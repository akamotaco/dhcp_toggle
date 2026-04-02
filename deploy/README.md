# dhcp-toggle

aarch64 Linux 보드용 DHCP 서버 모드 토글 도구.
필요에 따라 장비를 라우터 모드로 전환하거나 일반 데스크톱으로 복귀할 수 있다.

인터페이스 이름은 `install.sh`에서 자동 감지되므로 Ubuntu(eth0/eth1), Armbian(end0/end1), Debian(enp*) 등 어떤 배포판에서도 동작한다.

## 기능 요약

- **모드 전환**: 유선/Wi-Fi WAN/AP 라우터 모드, 데스크톱 모드 간 원클릭 전환
- **부팅 시 자동 복원**: 마지막 모드를 기억하여 재부팅 후 자동 복원
- **포트포워딩**: 정책(named rule) 기반 DNAT 규칙 관리 (enable/disable 가능)
- **Web UI**: 브라우저에서 모드 전환, 포워딩, 클라이언트 조회, 로그 확인
- **클라이언트 조회**: DHCP 리스 + ARP 테이블 결합 출력
- **로그**: 모든 동작을 타임스탬프와 함께 기록

---

## 동작 모드

인터페이스 이름은 `/etc/dhcp-toggle/config`에 설정된 값을 사용한다.
아래 표에서 `WAN0`, `LAN0`, `WLAN0`은 설정된 실제 인터페이스명으로 대체된다.

| 모드 | WAN | LAN | 설명 |
|------|-----|-----|------|
| `off` | -- | -- | DHCP 서버 비활성 (데스크톱 모드) |
| `a` | WAN0 (DHCP client) | LAN0 (192.168.10.1/24) | 유선 WAN |
| `b` | WLAN0 | br0: WAN0+LAN0 (192.168.10.1/24) | Wi-Fi WAN |
| `c` | WAN0 (DHCP client) | br0: LAN0+WLAN0 AP (192.168.10.1/24) | AP 모드 |

### 모드 A: 유선 WAN
```
[인터넷] → WAN0 (DHCP client) → NAT → LAN0 (DHCP server)
```

### 모드 B: Wi-Fi WAN
```
[인터넷] → WLAN0 (WAN) → NAT → br0 [WAN0 + LAN0] (DHCP server)
```

### 모드 C: AP 모드 (유선 WAN + Wi-Fi AP)
```
[인터넷] → WAN0 (DHCP client) → NAT → br0 [LAN0 + WLAN0(AP)] (DHCP server)
```
hostapd로 WLAN0을 AP로 동작시켜 유/무선 클라이언트 모두에게 LAN을 제공한다.

AP 설정(SSID, 비밀번호, 채널, 주파수 등)은 `/usr/local/share/dhcp-toggle/hostapd.conf`에서 수정 가능:

```bash
sudo vi /usr/local/share/dhcp-toggle/hostapd.conf
```

**2.4GHz 설정 (기본):**
```conf
hw_mode=g
channel=7
```

**5GHz 802.11ac 설정:**
```conf
hw_mode=a
channel=36
ieee80211ac=1
vht_oper_chwidth=0
vht_capab=[SHORT-GI-80][RX-LDPC][TX-STBC-2BY1][MAX-MPDU-11454]
```

변경 후 `sudo dhcp-toggle off && sudo dhcp-toggle c`로 재적용.

### 네트워크 설정

| 항목 | 값 |
|------|-----|
| LAN IP | 192.168.10.1/24 |
| DHCP 범위 | 192.168.10.100 ~ 192.168.10.200 |
| DNS | 8.8.8.8, 8.8.4.4 |
| 리스 시간 | 12시간 |

---

## 요구 사항

- Linux + systemd (aarch64)
- dnsmasq
- iptables
- iproute2 (`ip` 명령)
- jq (포트포워딩 JSON 처리)
- hostapd (모드 C Wi-Fi AP)
- python3-fastapi, python3-uvicorn (Web UI, apt 설치)

---

## 설치

```bash
cd deploy
sudo bash install.sh
```

`install.sh`는 다음을 수행한다:
1. 네트워크 인터페이스 자동 감지 및 확인 (수동 설정도 가능)
2. `/etc/dhcp-toggle/config` 생성 (인터페이스 매핑, 사용자명)
3. 패키지 설치 (`dnsmasq`, `iptables`, `jq`, `hostapd`, `python3-fastapi`, `python3-uvicorn`)
4. dnsmasq/hostapd 설정 파일 배포 (인터페이스명 자동 치환)
5. 메인 스크립트 `/usr/local/bin/dhcp-toggle` 설치
6. sudoers 설정 (감지된 사용자 NOPASSWD)
7. systemd 서비스 등록 (부팅 시 마지막 모드 자동 복원)
8. Web UI 서비스 자동 시작

## 제거

```bash
sudo bash /usr/local/share/dhcp-toggle/uninstall.sh
```

---

## 사용법

### 모드 전환

```bash
sudo dhcp-toggle a          # 모드 A 활성화 (유선 WAN)
sudo dhcp-toggle b          # 모드 B 활성화 (Wi-Fi WAN)
sudo dhcp-toggle c          # 모드 C 활성화 (AP 모드)
sudo dhcp-toggle off        # 전부 해제 (데스크톱 모드)
dhcp-toggle status          # 현재 상태 확인 (sudo 불필요)
dhcp-toggle help            # 상세 도움말 (실제 인터페이스명 포함)
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
- 모드 전환(a, b, c) 시 enabled 규칙이 자동 복원
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
| `/etc/dhcp-toggle/config` | 인터페이스 설정 (자동 생성) |
| `/usr/local/bin/dhcp-toggle` | 메인 토글 스크립트 |
| `/usr/local/share/dhcp-toggle/dhcp-mode-a.conf` | 모드 A dnsmasq 설정 |
| `/usr/local/share/dhcp-toggle/dhcp-mode-b.conf` | 모드 B dnsmasq 설정 |
| `/usr/local/share/dhcp-toggle/dhcp-mode-c.conf` | 모드 C dnsmasq 설정 |
| `/usr/local/share/dhcp-toggle/hostapd.conf` | 모드 C hostapd 설정 (SSID/비밀번호/채널) |
| `/etc/hostapd/hostapd.conf` | hostapd 활성 설정 (런타임 복사) |
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

### 인터페이스 설정

`install.sh`가 `/sys/class/net/`을 기반으로 유선/무선 인터페이스를 자동 감지한다.
결과는 `/etc/dhcp-toggle/config`에 저장되며, 수동 수정도 가능하다:

```bash
# /etc/dhcp-toggle/config
IF_WAN0="end0"      # 첫 번째 유선 (WAN)
IF_LAN0="end1"      # 두 번째 유선 (LAN)
IF_WLAN0="wlan0"    # 무선 (wlan이 여러 개여도 이것만 사용)
RUN_USER="pi"       # sudoers 사용자
```

### 코드 구조

```
deploy/
├── dhcp-toggle                 # 메인 bash 스크립트 (모든 CLI 기능)
├── dhcp-mode-a.conf            # 모드 A dnsmasq 설정 (템플릿)
├── dhcp-mode-b.conf            # 모드 B dnsmasq 설정
├── dhcp-mode-c.conf            # 모드 C dnsmasq 설정
├── hostapd.conf                # 모드 C hostapd 설정 (Wi-Fi AP)
├── dhcp-toggle.service         # DHCP 모드 systemd 서비스
├── dhcp-toggle-webui.service   # Web UI systemd 서비스
├── dhcp-toggle.sudoers         # sudoers 설정 (템플릿)
├── install.sh                  # 설치 스크립트 (인터페이스 자동 감지)
├── uninstall.sh                # 제거 스크립트
└── webui/
    ├── app.py                  # FastAPI 메인 앱
    ├── routers/
    │   ├── mode.py             # GET/POST /api/mode, /api/status
    │   ├── forward.py          # CRUD  /api/forwards
    │   ├── clients.py          # GET   /api/clients
    │   └── logs.py             # GET   /api/logs
    └── static/
        ├── index.html          # SPA 메인 페이지
        ├── style.css           # 다크 테마 CSS
        └── app.js              # 프론트엔드 로직
```

### 설계 원칙

- **포터블**: 인터페이스명을 설정 파일에서 읽으므로 어떤 리눅스 배포판에서도 동작
- **Web UI는 CLI를 감싼다**: 모든 시스템 조작은 `subprocess.run(["sudo", "dhcp-toggle", ...])` 으로 CLI를 호출. FastAPI가 직접 iptables나 시스템 파일을 건드리지 않는다.
- **권한 분리**: Web UI는 일반 사용자로 실행. root 권한이 필요한 작업만 sudo로 호출.
- **설정 영구화**: 포트포워딩(`forwards.json`), Web UI 설정(`webui.json`)은 JSON 파일에 저장하여 재부팅/모드 전환 후에도 유지.
- **부팅 시 복원**: systemd 서비스가 마지막 모드를 자동 복원 (`restore` 명령)
- **iptables comment 기반 관리**: 포워딩 규칙에 `--comment "fwd:<이름>"` 을 붙여서 규칙별 추가/제거를 안전하게 처리.

### 모드 전환 흐름

```
dhcp-toggle a/b/c 실행
  → cleanup(next_mode)       # 이전 모드 정리: dnsmasq/hostapd 정지, iptables 초기화, 브릿지 제거
                              # next_mode가 c가 아닐 때만 NM 복원 (wlan AP 전환 충돌 방지)
  → mode_a()/mode_b()/mode_c()  # 인터페이스 설정, dnsmasq 설정 복사, NAT 규칙 추가
  → restore_forwards()       # forwards.json에서 enabled 규칙 iptables 적용
```

### NetworkManager와 wlan 관리

wlan은 **모드 C 전환과 관련된 경우에만** 건드린다. 그 외 전환에서는 기존 WiFi 연결을 보존한다:

| 전환 | wlan 처리 | 기존 WiFi 연결 |
|------|-----------|----------------|
| off/a/b 간 전환 | 안 건드림 | 유지 |
| off/a/b → c | NM에서 분리 + hostapd 시작 | 끊김 (AP 전환) |
| c → off/a/b | hostapd 정지 + NM 복원 | 자동 재접속 |

wlan이 여러 개(wlan0, wlan1 등) 존재하더라도 설정된 하나(IF_WLAN0)만 사용한다.

### iptables 규칙 구조

모드 활성화 시 적용되는 규칙:

```
# NAT (POSTROUTING) -- 모드 전환 시 자동 설정
-t nat -A POSTROUTING -o <WAN인터페이스> -j MASQUERADE

# FORWARD -- LAN<->WAN 양방향 허용
-A FORWARD -i <LAN인터페이스> -o <WAN인터페이스> -j ACCEPT
-A FORWARD -i <WAN인터페이스> -o <LAN인터페이스> -m state --state RELATED,ESTABLISHED -j ACCEPT

# 포트포워딩 (PREROUTING) -- forwards.json에서 자동 복원
-t nat -A PREROUTING -i <WAN인터페이스> -p <proto> --dport <외부포트> \
    -j DNAT --to-destination <내부IP>:<내부포트> -m comment --comment "fwd:<이름>"
-A FORWARD -p <proto> -d <내부IP> --dport <내부포트> -j ACCEPT \
    -m comment --comment "fwd:<이름>"
```

---

## 부팅 시 자동 복원

systemd 서비스가 `restore` 명령으로 마지막 모드를 자동 복원한다:

```bash
sudo systemctl enable dhcp-toggle    # 부팅 시 자동 복원 활성화
sudo systemctl disable dhcp-toggle   # 비활성화
```

Web UI는 설치 시 자동 시작된다. `dhcp-toggle webui off`로 비활성화 가능.

---

## WiFi AP 드라이버 참고

RTL8822CS 칩셋의 경우, 커널 내장 rtw88 드라이버는 AP 모드에서 데이터 전달이 안 될 수 있다.
이 경우 Realtek 벤더 드라이버(88x2cs)를 DKMS로 설치하고 rtw88을 블랙리스트해야 한다:

```bash
# 벤더 드라이버 빌드 및 설치
git clone https://github.com/libc0607/rtl8822cs-20240221.git
sudo dkms add rtl8822cs-20240221
sudo dkms build realtek-rtl8822cs/5.15.8.3~20240221
sudo dkms install realtek-rtl8822cs/5.15.8.3~20240221

# rtw88 블랙리스트
echo -e "blacklist rtw88_8822cs\nblacklist rtw88_8822c\nblacklist rtw88_sdio\nblacklist rtw88_core" | sudo tee /etc/modprobe.d/blacklist-rtw88.conf
sudo reboot
```

참고: dkms.conf에서 `ARCH=arm64`, `BUILT_MODULE_NAME[0]=88x2cs` 수정이 필요할 수 있다.

---

## 라이선스

자유롭게 사용/수정 가능
