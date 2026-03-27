# dhcp-toggle

NanoPi R6S (aarch64) 용 DHCP 서버 모드 토글 스크립트

## 개요

필요에 따라 DHCP 서버(라우터 모드)를 on/off 할 수 있는 CUI 토글 도구.

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

- DHCP 범위: `192.168.10.100 ~ 192.168.10.200`
- DNS: 8.8.8.8, 8.8.4.4

## 요구 사항

- Ubuntu (arm64) + systemd
- dnsmasq-base
- iptables
- iproute2 (ip 명령)

## 설치

```bash
tar xzf dhcp-toggle.tar.gz
cd dhcp-toggle
sudo bash install.sh
```

## 제거

```bash
sudo bash /usr/local/share/dhcp-toggle/uninstall.sh
```
또는 압축 해제한 디렉토리에서:
```bash
sudo bash uninstall.sh
```

## 사용법

```bash
sudo dhcp-toggle a          # 모드 A 활성화 (eth0=WAN, eth1=LAN)
sudo dhcp-toggle b          # 모드 B 활성화 (wlan0=WAN, eth0+eth1=LAN)
sudo dhcp-toggle off        # 전부 해제 (데스크톱 모드)
dhcp-toggle status          # 현재 상태 확인 (sudo 불필요)
dhcp-toggle clients         # 접속 클라이언트 목록
dhcp-toggle log             # 최근 로그 50줄
dhcp-toggle log 100         # 최근 로그 100줄
dhcp-toggle help            # 상세 도움말
```

### clients — 접속 클라이언트 조회

DHCP 리스와 ARP 테이블을 결합하여 현재 접속된 장치를 표시합니다.

```
======================================
 접속 클라이언트 목록 (모드: a)
======================================

--- DHCP 할당 클라이언트 ---
MAC 주소           IP 주소          호스트명
――――――――――――――――   ―――――――――――――    ――――――――
aa:bb:cc:dd:ee:ff  192.168.10.101   my-laptop            (만료: 03/26 23:15)

--- ARP 테이블 (eth1) ---
IP 주소          MAC 주소           상태
―――――――――――――    ――――――――――――――――   ――――
192.168.10.101   aa:bb:cc:dd:ee:ff  REACHABLE

DHCP 할당: 1대 | ARP 활성: 1대
======================================
```

### log — 동작 로그

모든 모드 전환, 에러, 경고가 타임스탬프와 함께 기록됩니다.

```
[2026-03-26 10:30:01] [INFO] 이전 모드(off) 정리 중...
[2026-03-26 10:30:02] [INFO] 모드 A 활성화: eth0=WAN, eth1=LAN
[2026-03-26 10:30:03] [INFO] 모드 A 활성화 완료
```

로그 파일 위치: `/var/log/dhcp-toggle.log`

## 설치되는 파일

| 경로 | 설명 |
|------|------|
| `/usr/local/bin/dhcp-toggle` | 메인 토글 스크립트 |
| `/usr/local/share/dhcp-toggle/dhcp-mode-a.conf` | 모드 A dnsmasq 설정 |
| `/usr/local/share/dhcp-toggle/dhcp-mode-b.conf` | 모드 B dnsmasq 설정 |
| `/usr/local/share/dhcp-toggle/uninstall.sh` | 제거 스크립트 |
| `/etc/dnsmasq.d/dhcp-active.conf` | 활성 모드 설정 (런타임 생성) |
| `/etc/sudoers.d/dhcp-toggle` | sudo 권한 설정 |
| `/etc/systemd/system/dhcp-toggle.service` | systemd 서비스 |
| `/var/lib/dhcp-toggle/mode` | 현재 모드 상태 파일 |
| `/var/log/dhcp-toggle.log` | 동작 로그 |

## 부팅 시 자동 실행

기본 설치 시 자동 실행되지 않음. 원하는 경우:

```bash
# 서비스 파일에서 ExecStart 의 모드를 원하는 값으로 수정 후:
sudo systemctl enable dhcp-toggle
```

## 라이선스

자유롭게 사용/수정 가능
