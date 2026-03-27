#!/bin/bash
# dhcp-toggle 설치 스크립트
# 사용법: sudo bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: root 권한이 필요합니다. sudo bash install.sh 으로 실행하세요."
    exit 1
fi

echo "=== dhcp-toggle 설치 시작 ==="

# 1. 필요 패키지 설치
echo "[1/6] 패키지 확인..."
apt-get install -y iptables 2>/dev/null || echo "iptables 설치 실패 — 수동 설치 필요"

# 2. dnsmasq 설정 디렉토리
echo "[2/6] dnsmasq 설정 파일 배포..."
mkdir -p /etc/dnsmasq.d
mkdir -p /usr/local/share/dhcp-toggle
cp "$SCRIPT_DIR/dhcp-mode-a.conf" /usr/local/share/dhcp-toggle/
cp "$SCRIPT_DIR/dhcp-mode-b.conf" /usr/local/share/dhcp-toggle/
cp "$SCRIPT_DIR/uninstall.sh" /usr/local/share/dhcp-toggle/
chmod +x /usr/local/share/dhcp-toggle/uninstall.sh

# dnsmasq가 /etc/dnsmasq.d/ 를 읽도록 설정
if [[ ! -f /etc/dnsmasq.conf ]]; then
    echo "conf-dir=/etc/dnsmasq.d/,*.conf" > /etc/dnsmasq.conf
elif ! grep -q "conf-dir=/etc/dnsmasq.d" /etc/dnsmasq.conf; then
    echo "conf-dir=/etc/dnsmasq.d/,*.conf" >> /etc/dnsmasq.conf
fi

# 3. 메인 스크립트 설치
echo "[3/6] dhcp-toggle 스크립트 설치..."
cp "$SCRIPT_DIR/dhcp-toggle" /usr/local/bin/dhcp-toggle
chmod +x /usr/local/bin/dhcp-toggle

# 4. sudoers 설정
echo "[4/6] sudoers 설정..."
cp "$SCRIPT_DIR/dhcp-toggle.sudoers" /etc/sudoers.d/dhcp-toggle
chmod 0440 /etc/sudoers.d/dhcp-toggle
visudo -c -f /etc/sudoers.d/dhcp-toggle && echo "  sudoers 문법 확인 OK" || {
    echo "ERROR: sudoers 문법 오류!"
    rm -f /etc/sudoers.d/dhcp-toggle
    exit 1
}

# 5. systemd 서비스
echo "[5/6] systemd 서비스 등록..."
cp "$SCRIPT_DIR/dhcp-toggle.service" /etc/systemd/system/
systemctl daemon-reload
echo "  부팅 시 자동 실행을 원하면: systemctl enable dhcp-toggle"

# 6. 상태 디렉토리
echo "[6/6] 상태 디렉토리 생성..."
mkdir -p /var/lib/dhcp-toggle

echo ""
echo "=== 설치 완료 ==="
echo ""
echo "사용법:"
echo "  sudo dhcp-toggle a        # 모드 A (eth0=WAN, eth1=LAN)"
echo "  sudo dhcp-toggle b        # 모드 B (wlan0=WAN, eth0+eth1=LAN)"
echo "  sudo dhcp-toggle off      # 해제"
echo "  dhcp-toggle status        # 상태 확인"
