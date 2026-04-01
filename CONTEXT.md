# dhcp-toggle 프로젝트 컨텍스트

## 프로젝트 개요

NanoPi R6S (aarch64, Ubuntu arm64)에서 DHCP 서버를 모드별로 토글하는 CUI 도구.
필요에 따라 장비를 라우터 모드로 전환하거나 일반 데스크톱으로 복귀할 수 있다.

## 장비 환경

- **장비**: FriendlyElec NanoPi R6S
- **아키텍처**: aarch64 (arm64)
- **OS**: Ubuntu + X11 + XFCE4
- **인터페이스**: eth0, eth1, wlan0, wlan1
- **사용자**: pi (sudo 가능, 비밀번호 필요)

## 작업 이력

### 1차: 계획 수립 (dhcp-toggle-plan.md)

- 모드 OFF / A / B 세 가지 동작 모드 정의
- 모드 A: eth0=WAN(DHCP client) → NAT → eth1=LAN(DHCP server)
- 모드 B: wlan0=WAN → NAT → br0(eth0+eth1)=LAN(DHCP server)
- LAN 서브넷: 192.168.10.0/24, DHCP 범위: .100~.200
- 구현 5단계: dnsmasq 설정 → 토글 스크립트 → sudoers → systemd → 테스트

### 2차: 구현 + 패키징

시스템 상태 확인 결과:
- dnsmasq 2.90 설치됨
- iptables CLI 미설치 (라이브러리만 있음) → install.sh에서 자동 설치
- bridge-utils 미설치 → `ip link add type bridge`로 대체
- /etc/dnsmasq.conf, /etc/dnsmasq.d/ 없음 → install.sh에서 생성
- sudo에 비밀번호 필요 → 직접 터미널에서 `sudo bash install.sh` 실행해야 함

생성 파일 (`deploy/` 디렉토리):
```
deploy/
├── README.md               # 설명서 (설치/제거/사용법/파일목록)
├── install.sh              # 설치 스크립트 (패키지 설치, 파일 배포, sudoers, systemd)
├── uninstall.sh            # 제거 스크립트 (서비스 해제, 파일 삭제)
├── dhcp-toggle             # 메인 토글 스크립트 (bash)
├── dhcp-mode-a.conf        # 모드 A dnsmasq 설정
├── dhcp-mode-b.conf        # 모드 B dnsmasq 설정
├── dhcp-toggle.sudoers     # pi 사용자 NOPASSWD 설정
└── dhcp-toggle.service     # systemd oneshot 서비스
```

패키징: `dhcp-toggle.tar.gz` (루트에 생성, 5.7K)
- `tar xzf dhcp-toggle.tar.gz && cd dhcp-toggle && sudo bash install.sh`

### 3차: 기능 추가 — clients

- `dhcp-toggle clients` 명령 추가
- DHCP 리스 (/var/lib/misc/dnsmasq.leases) + ARP 테이블 결합 출력
- MAC, IP, 호스트명, 만료시간, 연결 상태 표시
- `status` 실행 시에도 클라이언트 목록 함께 출력

### 4차: 기능 추가 — log, help

- 로그: 모든 log_info/warn/error 호출이 `/var/log/dhcp-toggle.log`에 타임스탬프와 함께 기록
- `dhcp-toggle log [N]` — 최근 N줄 로그 조회 (기본 50)
- `dhcp-toggle help` — 전체 명령어, 예제, 네트워크 구성, 파일 위치 등 상세 도움말
- `-h`, `--help` 플래그도 지원

## 설치 경로 매핑

| 소스 (deploy/) | 설치 위치 |
|----------------|-----------|
| dhcp-toggle | /usr/local/bin/dhcp-toggle |
| dhcp-mode-a.conf | /usr/local/share/dhcp-toggle/dhcp-mode-a.conf |
| dhcp-mode-b.conf | /usr/local/share/dhcp-toggle/dhcp-mode-b.conf |
| dhcp-mode-c.conf | /usr/local/share/dhcp-toggle/dhcp-mode-c.conf |
| hostapd.conf | /usr/local/share/dhcp-toggle/hostapd.conf |
| (런타임 복사) | /etc/hostapd/hostapd.conf |
| uninstall.sh | /usr/local/share/dhcp-toggle/uninstall.sh |
| dhcp-toggle.sudoers | /etc/sudoers.d/dhcp-toggle |
| dhcp-toggle.service | /etc/systemd/system/dhcp-toggle.service |
| (런타임 생성) | /etc/dnsmasq.d/dhcp-active.conf |
| (런타임 생성) | /var/lib/dhcp-toggle/mode |
| (런타임 생성) | /var/lib/dhcp-toggle/forwards.json |
| (런타임 생성) | /var/lib/dhcp-toggle/webui.json |
| (런타임 생성) | /var/log/dhcp-toggle.log |
| dhcp-toggle-webui.service | /etc/systemd/system/dhcp-toggle-webui.service |
| webui/ | /usr/local/share/dhcp-toggle/webui/ |

### 5차: 포트포워딩 + Web UI

- 포트포워딩: 정책(named rule) 기반 — add/remove/enable/disable/list
  - 포트 형식: 단일(80), 범위(8080-8090), 복수(80,443)
  - 프로토콜: tcp, udp, both
  - `/var/lib/dhcp-toggle/forwards.json`에 저장, 모드 전환 시 자동 복원
  - iptables PREROUTING DNAT + FORWARD 규칙, comment 기반 관리

- Web UI: FastAPI + 순수 HTML/CSS/JS (CDN 없음, 빌드 도구 없음)
  - 직접 바인딩 (기본 포트 8080, `/var/lib/dhcp-toggle/webui.json`으로 변경 가능)
  - 탭 구성: 대시보드(모드 전환) / 클라이언트 / 포트포워딩 / 로그
  - subprocess로 `dhcp-toggle` CLI 호출하는 구조
  - systemd 서비스: `dhcp-toggle-webui.service` (User=pi)
  - 다크 테마, 모바일 반응형

추가 파일:
```
deploy/
├── dhcp-toggle-webui.service
└── webui/
    ├── app.py
    ├── requirements.txt
    ├── routers/
    │   ├── mode.py
    │   ├── forward.py
    │   ├── clients.py
    │   └── logs.py
    └── static/
        ├── index.html
        ├── style.css
        └── app.js
```

### 6차: 기능 추가 — 모드 C (AP 모드)

- 모드 C: eth0=WAN(DHCP client) → NAT → br0(eth1+wlan0 AP)=LAN
- hostapd로 wlan0을 Wi-Fi AP로 동작시켜 유/무선 클라이언트 모두 지원
- R6S WiFi 칩(RTL8822CS)은 싱글 라디오(phy0)에 wlan0/wlan1 가상 인터페이스 2개 구조
  - 듀얼밴드(2.4/5GHz)이나 한 번에 한 밴드만 사용 가능
  - wlan0 하나만 AP로 사용하는 것이 적합
- NetworkManager 충돌 방지:
  - mode b/c 진입 시 `nmcli device set wlan0/1 managed no`로 NM에서 분리
  - mode a/off 복귀 시 `managed yes`로 복원 → 기존 WiFi(Orion 등) 자동 재접속
- cleanup()에서 hostapd 정지 추가

추가/수정 파일:
```
deploy/
├── dhcp-mode-c.conf            # 모드 C dnsmasq 설정 (br0 바인딩)
├── hostapd.conf                # hostapd 설정 (SSID, 비밀번호, 채널, WPA2)
├── dhcp-toggle                 # mode_c() 추가, NM 관리 로직 추가
├── install.sh                  # hostapd 패키지 + 설정 파일 배포
└── webui/
    ├── routers/mode.py         # "c" 모드 허용
    ├── routers/clients.py      # mode c → br0 매핑
    └── static/
        ├── index.html          # 모드 C 버튼 추가
        └── app.js              # 모드 C 버튼 하이라이트
```

## 현재 상태

- 코드 작성 완료
- **아직 재설치하지 않음** — sudo 비밀번호가 필요하여 사용자가 직접 실행해야 함
- 테스트 미진행

## 알아둘 점

- dnsmasq 설정 파일은 `/usr/local/share/dhcp-toggle/`에 원본 보관, 모드 전환 시 `/etc/dnsmasq.d/dhcp-active.conf`로 복사하는 방식
- 모드 A의 dhcp-toggle 스크립트에 `dhcp-mode-a.conf.tpl` fallback 경로가 있는데, 실제로는 `/usr/local/share/dhcp-toggle/dhcp-mode-a.conf`만 사용됨 (정리 필요할 수 있음)
- bridge-utils 없이 `ip link add type bridge`로 브릿지 생성
- systemd 서비스는 기본 off 모드로 시작, `systemctl enable`은 사용자 선택
