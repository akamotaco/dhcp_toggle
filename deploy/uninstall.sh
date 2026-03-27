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
        echo "[1/5] 현재 모드($current) 해제 중..."
        /usr/local/bin/dhcp-toggle off 2>/dev/null || true
    else
        echo "[1/5] 이미 off 상태"
    fi
else
    echo "[1/5] 상태 파일 없음, 건너뜀"
fi

# 2. systemd 서비스 제거
echo "[2/5] systemd 서비스 제거..."
systemctl disable dhcp-toggle 2>/dev/null || true
systemctl stop dhcp-toggle 2>/dev/null || true
rm -f /etc/systemd/system/dhcp-toggle.service
systemctl daemon-reload

# 3. sudoers 제거
echo "[3/5] sudoers 설정 제거..."
rm -f /etc/sudoers.d/dhcp-toggle

# 4. 파일 제거
echo "[4/5] 파일 제거..."
rm -f /usr/local/bin/dhcp-toggle
rm -f /etc/dnsmasq.d/dhcp-active.conf
rm -rf /usr/local/share/dhcp-toggle
rm -rf /var/lib/dhcp-toggle

# 5. dnsmasq.conf 에서 추가한 줄은 남겨둠 (다른 설정에 영향 줄 수 있으므로)
echo "[5/5] 정리 완료"

echo ""
echo "=== dhcp-toggle 제거 완료 ==="
echo ""
echo "참고: /etc/dnsmasq.conf 의 conf-dir 설정은 수동으로 확인하세요."
