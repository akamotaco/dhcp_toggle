# DHCP Toggle 계획서

## 장비 정보
- **장비**: FriendlyElec NanoPi R6S (aarch64)
- **OS**: Ubuntu (arm64) + X11 + XFCE4
- **인터페이스**: eth0, eth1, wlan0, wlan1

## 목표
필요에 따라 DHCP 서버(라우터 모드)를 on/off 할 수 있는 CUI 토글 스크립트 구현

## 동작 모드

### 모드 OFF (데스크톱 모드)
- DHCP 서버 비활성
- 모든 인터페이스 일반 사용

### 모드 A: 유선 WAN
```
[인터넷] → eth0 (WAN, DHCP client) → NAT → eth1 (LAN, DHCP server)
```
- eth0: WAN — 외부 네트워크에서 IP 자동 할당 받음
- eth1: LAN — 고정 IP 192.168.10.1/24, DHCP 서버 운영
- DHCP 범위: 192.168.10.100 ~ 192.168.10.200
- NAT: eth1 → eth0 masquerade

### 모드 B: Wi-Fi WAN
```
[인터넷] → wlan0 (WAN) → NAT → eth0 + eth1 (LAN, DHCP server)
```
- wlan0: WAN — Wi-Fi로 인터넷 연결 (현재 192.168.1.65)
- eth0: LAN — 고정 IP 192.168.10.1/24
- eth1: LAN — 같은 브릿지 또는 같은 서브넷 192.168.10.1/24 (br0로 묶기)
- DHCP 범위: 192.168.10.100 ~ 192.168.10.200
- NAT: br0 → wlan0 masquerade

## 구현 작업

### 1단계: dnsmasq 설정 파일
- `/etc/dnsmasq.d/dhcp-mode-a.conf` — 모드 A 전용
- `/etc/dnsmasq.d/dhcp-mode-b.conf` — 모드 B 전용
- 기본 dnsmasq 설정에서 DHCP 비활성 상태 유지

### 2단계: dhcp-toggle 스크립트
- 위치: `/usr/local/bin/dhcp-toggle`
- 사용법:
  ```
  dhcp-toggle a        # 모드 A 활성화 (eth0=WAN, eth1=LAN)
  dhcp-toggle b        # 모드 B 활성화 (wlan0=WAN, eth0+eth1=LAN)
  dhcp-toggle off      # 전부 해제
  dhcp-toggle status   # 현재 상태 확인
  ```
- 스크립트 동작:
  1. 이전 모드 정리 (cleanup)
  2. 인터페이스 IP 설정
  3. 모드 B의 경우 br0 브릿지 생성 (eth0 + eth1)
  4. dnsmasq 설정 심볼릭링크 활성화
  5. dnsmasq 재시작
  6. IP 포워딩 활성화 (`sysctl net.ipv4.ip_forward=1`)
  7. iptables NAT masquerade 규칙 추가

### 3단계: sudoers 설정
- `/etc/sudoers.d/dhcp-toggle`
- 비밀번호 없이 dhcp-toggle 실행 허용:
  ```
  pi ALL=(ALL) NOPASSWD: /usr/local/bin/dhcp-toggle
  ```

### 4단계: 서비스 등록 (선택)
- systemd 서비스 파일로 등록하면 부팅 시 자동으로 원하는 모드 실행 가능
- `/etc/systemd/system/dhcp-toggle.service`
- `systemctl enable dhcp-toggle` → 부팅 시 자동 실행

### 5단계: 테스트
- [ ] 모드 A: eth0에 인터넷 케이블, eth1에 클라이언트 연결 → IP 할당 확인
- [ ] 모드 B: wlan0 인터넷, eth0/eth1에 클라이언트 연결 → IP 할당 확인
- [ ] 모드 OFF: DHCP 서버 중지, 일반 동작 확인
- [ ] 모드 전환: A → B, B → OFF 등 전환 시 정상 동작 확인

## 필요 패키지
- `dnsmasq-base` (설치됨)
- `iptables` (확인 필요)
- `bridge-utils` (모드 B의 br0 브릿지용, 확인 필요)

## 파일 목록
```
/usr/local/bin/dhcp-toggle          # 메인 토글 스크립트
/etc/dnsmasq.d/dhcp-mode-a.conf     # 모드 A DHCP 설정
/etc/dnsmasq.d/dhcp-mode-b.conf     # 모드 B DHCP 설정
/etc/sudoers.d/dhcp-toggle          # sudo 권한
/etc/systemd/system/dhcp-toggle.service  # (선택) 부팅 자동 실행
```
