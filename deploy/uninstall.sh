#!/bin/bash
# dhcp-toggle 제거 스크립트
# 사용법: sudo bash uninstall.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: root 권한이 필요합니다. sudo bash uninstall.sh 으로 실행하세요."
    exit 1
fi

echo "=== dhcp-toggle 제거 시작 ==="

# 1. 실행 중이면 먼저 off
if [[ -f /var/lib/dhcp-toggle/mode ]]; then
    current=$(cat /var/lib/dhcp-toggle/mode)
    if [[ "$current" != "off" ]]; then
        echo "[1/6] 현재 모드($current) 해제 중..."
        /usr/local/bin/dhcp-toggle off 2>/dev/null || true
    else
        echo "[1/6] 이미 off 상태"
    fi
else
    echo "[1/6] 상태 파일 없음, 건너뜀"
fi

# 2. systemd 서비스 제거
echo "[2/6] systemd 서비스 제거..."
systemctl disable dhcp-toggle-webui 2>/dev/null || true
systemctl stop dhcp-toggle-webui 2>/dev/null || true
rm -f /etc/systemd/system/dhcp-toggle-webui.service
systemctl disable dhcp-toggle 2>/dev/null || true
systemctl stop dhcp-toggle 2>/dev/null || true
rm -f /etc/systemd/system/dhcp-toggle.service
systemctl daemon-reload

# 3. sudoers 제거
echo "[3/6] sudoers 설정 제거..."
rm -f /etc/sudoers.d/dhcp-toggle

# 4. 파일 제거
echo "[4/6] 파일 제거..."
rm -f /usr/local/bin/dhcp-toggle
rm -f /etc/dnsmasq.d/dhcp-active.conf
rm -rf /usr/local/share/dhcp-toggle
rm -rf /var/lib/dhcp-toggle

# 5. 로그 파일 제거
echo "[5/6] 로그 파일 제거..."
rm -f /var/log/dhcp-toggle.log

# 6. dnsmasq.conf 에서 추가한 줄은 남겨둠 (다른 설정에 영향 줄 수 있으므로)
echo "[6/6] 정리 완료"

echo ""
echo "=== dhcp-toggle 제거 완료 ==="
echo ""
echo "참고: /etc/dnsmasq.conf 의 conf-dir 설정은 수동으로 확인하세요."
