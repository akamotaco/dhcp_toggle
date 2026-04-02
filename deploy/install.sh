#!/bin/bash
# dhcp-toggle 설치 스크립트
# 사용법: sudo bash install.sh
# 인터페이스를 자동 감지하여 어떤 리눅스 배포판에서도 동작합니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="/etc/dhcp-toggle"
CONFIG_FILE="${CONFIG_DIR}/config"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: root 권한이 필요합니다. sudo bash install.sh 으로 실행하세요."
    exit 1
fi

echo "=== dhcp-toggle 설치 시작 ==="

# --- 인터페이스 자동 감지 ---

detect_interfaces() {
    echo ""
    echo "[0/8] 네트워크 인터페이스 감지 중..."

    # 유선 인터페이스 목록 (lo, br*, veth*, docker* 제외)
    local eths=()
    while IFS= read -r iface; do
        # 무선 인터페이스 제외
        [[ -d "/sys/class/net/${iface}/wireless" ]] && continue
        eths+=("$iface")
    done < <(ls /sys/class/net/ | grep -vE '^(lo|br|veth|docker|virbr|tun|tap)' | sort)

    # 무선 인터페이스 목록
    local wlans=()
    for iface in /sys/class/net/*/wireless; do
        [[ -e "$iface" ]] || continue
        local name
        name=$(basename "$(dirname "$iface")")
        wlans+=("$name")
    done

    echo ""
    echo "감지된 유선 인터페이스: ${eths[*]:-없음}"
    echo "감지된 무선 인터페이스: ${wlans[*]:-없음}"

    # 유선 최소 2개 필요
    if (( ${#eths[@]} < 2 )); then
        echo "ERROR: 유선 인터페이스가 2개 이상 필요합니다. (감지: ${#eths[@]}개)"
        echo "현재 인터페이스 목록:"
        ip -br link show
        exit 1
    fi

    # 기본값 설정
    IF_WAN0="${eths[0]}"
    IF_LAN0="${eths[1]}"
    IF_WLAN0="${wlans[0]:-}"
    RUN_USER="${SUDO_USER:-$(logname 2>/dev/null || echo pi)}"

    # 기존 설정 파일이 있으면 로드하여 기본값으로 사용
    if [[ -f "$CONFIG_FILE" ]]; then
        echo ""
        echo "기존 설정 파일 발견: $CONFIG_FILE"
        source "$CONFIG_FILE"
        echo "  WAN=${IF_WAN0}, LAN=${IF_LAN0}, WLAN=${IF_WLAN0:-없음}, USER=${RUN_USER}"
    fi

    echo ""
    echo "인터페이스 매핑 확인:"
    echo "  WAN (외부 네트워크):  ${IF_WAN0}"
    echo "  LAN (내부 네트워크):  ${IF_LAN0}"
    echo "  WLAN (무선):          ${IF_WLAN0:-없음}"
    echo "  실행 사용자:          ${RUN_USER}"
    echo ""

    read -rp "이 설정으로 진행하시겠습니까? [Y/n/c(수동설정)] " confirm
    case "${confirm,,}" in
        n)
            echo "설치를 취소합니다."
            exit 0
            ;;
        c)
            echo ""
            read -rp "WAN 인터페이스 [${IF_WAN0}]: " input
            [[ -n "$input" ]] && IF_WAN0="$input"
            read -rp "LAN 인터페이스 [${IF_LAN0}]: " input
            [[ -n "$input" ]] && IF_LAN0="$input"
            read -rp "WLAN 인터페이스 [${IF_WLAN0:-없음}]: " input
            [[ -n "$input" ]] && IF_WLAN0="$input"
            read -rp "실행 사용자 [${RUN_USER}]: " input
            [[ -n "$input" ]] && RUN_USER="$input"
            echo ""
            ;;
    esac

    # 인터페이스 존재 확인
    for iface in "$IF_WAN0" "$IF_LAN0"; do
        if [[ ! -e "/sys/class/net/${iface}" ]]; then
            echo "WARNING: 인터페이스 '${iface}'가 존재하지 않습니다. 계속 진행합니다."
        fi
    done

    # 설정 파일 저장
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<CONF
# dhcp-toggle 인터페이스 설정
# install.sh에 의해 자동 생성됨 — 필요 시 수동 수정 가능
# 변경 후 별도 재시작 불필요 (dhcp-toggle 실행 시마다 읽음)

IF_WAN0="${IF_WAN0}"
IF_LAN0="${IF_LAN0}"
IF_WLAN0="${IF_WLAN0}"
RUN_USER="${RUN_USER}"
CONF

    echo "설정 저장 완료: $CONFIG_FILE"
}

detect_interfaces

# 1. 필요 패키지 설치
echo ""
echo "[1/8] 패키지 확인..."
apt-get install -y dnsmasq iptables jq hostapd python3-fastapi python3-uvicorn 2>/dev/null || echo "패키지 설치 실패 — 수동 설치 필요"

# dnsmasq: 자동시작 비활성화 (dhcp-toggle이 직접 관리)
systemctl disable dnsmasq 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true

# hostapd: unmask (Ubuntu 기본 masked) + 자동시작 비활성화 (dhcp-toggle이 직접 관리)
systemctl unmask hostapd 2>/dev/null || true
systemctl disable hostapd 2>/dev/null || true
systemctl stop hostapd 2>/dev/null || true

# 2. dnsmasq 설정 디렉토리 + conf 파일 생성 (인터페이스명 치환)
echo "[2/8] dnsmasq 설정 파일 배포..."
mkdir -p /etc/dnsmasq.d
mkdir -p /usr/local/share/dhcp-toggle

# 모드 A conf: LAN 인터페이스 바인딩
cat > /usr/local/share/dhcp-toggle/dhcp-mode-a.conf <<CONF
# DHCP 모드 A: ${IF_WAN0}=WAN, ${IF_LAN0}=LAN
# 이 파일은 dhcp-toggle 스크립트가 관리합니다. 직접 수정하지 마세요.

interface=${IF_LAN0}
bind-interfaces

dhcp-range=192.168.10.100,192.168.10.200,255.255.255.0,12h
dhcp-option=option:router,192.168.10.1
dhcp-option=option:dns-server,8.8.8.8,8.8.4.4

# 로그
log-dhcp
CONF

# 모드 B/C conf: br0 바인딩 (인터페이스 무관)
for mode in b c; do
    cp "$SCRIPT_DIR/dhcp-mode-${mode}.conf" /usr/local/share/dhcp-toggle/
done

# hostapd conf: wlan 인터페이스명 치환
sed "s/^interface=.*/interface=${IF_WLAN0}/" "$SCRIPT_DIR/hostapd.conf" \
    > /usr/local/share/dhcp-toggle/hostapd.conf

mkdir -p /etc/hostapd
cp "$SCRIPT_DIR/uninstall.sh" /usr/local/share/dhcp-toggle/
chmod +x /usr/local/share/dhcp-toggle/uninstall.sh

# dnsmasq가 /etc/dnsmasq.d/ 를 읽도록 설정
if [[ ! -f /etc/dnsmasq.conf ]]; then
    echo "conf-dir=/etc/dnsmasq.d/,*.conf" > /etc/dnsmasq.conf
elif ! grep -q "conf-dir=/etc/dnsmasq.d" /etc/dnsmasq.conf; then
    echo "conf-dir=/etc/dnsmasq.d/,*.conf" >> /etc/dnsmasq.conf
fi

# 3. 메인 스크립트 설치
echo "[3/8] dhcp-toggle 스크립트 설치..."
cp "$SCRIPT_DIR/dhcp-toggle" /usr/local/bin/dhcp-toggle
chmod +x /usr/local/bin/dhcp-toggle

# 4. sudoers 설정 (감지된 사용자명 사용)
echo "[4/8] sudoers 설정..."
cat > /etc/sudoers.d/dhcp-toggle <<SUDOERS
# dhcp-toggle: 비밀번호 없이 실행 허용
${RUN_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/dhcp-toggle
SUDOERS
chmod 0440 /etc/sudoers.d/dhcp-toggle
visudo -c -f /etc/sudoers.d/dhcp-toggle && echo "  sudoers 문법 확인 OK" || {
    echo "ERROR: sudoers 문법 오류!"
    rm -f /etc/sudoers.d/dhcp-toggle
    exit 1
}

# 5. systemd 서비스 (dhcp-toggle)
echo "[5/8] systemd 서비스 등록..."
cp "$SCRIPT_DIR/dhcp-toggle.service" /etc/systemd/system/
echo "  부팅 시 자동 실행을 원하면: systemctl enable dhcp-toggle"

# 6. 상태 디렉토리
echo "[6/8] 상태 디렉토리 생성..."
mkdir -p /var/lib/dhcp-toggle

# 7. Web UI 파일 배포
echo "[7/8] Web UI 파일 배포..."
cp -r "$SCRIPT_DIR/webui" /usr/local/share/dhcp-toggle/

# 8. Web UI systemd 서비스
echo "[8/8] Web UI 서비스 등록..."
cp "$SCRIPT_DIR/dhcp-toggle-webui.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now dhcp-toggle-webui
echo "  Web UI 시작됨 (포트 8080)"

echo ""
echo "=== 설치 완료 ==="
echo ""
echo "인터페이스 설정: $CONFIG_FILE"
echo "  WAN=${IF_WAN0}  LAN=${IF_LAN0}  WLAN=${IF_WLAN0:-없음}"
echo ""
echo "사용법:"
echo "  sudo dhcp-toggle a        # 모드 A (${IF_WAN0}=WAN, ${IF_LAN0}=LAN)"
echo "  sudo dhcp-toggle b        # 모드 B (${IF_WLAN0}=WAN, ${IF_WAN0}+${IF_LAN0}=LAN)"
echo "  sudo dhcp-toggle c        # 모드 C (${IF_WAN0}=WAN, ${IF_LAN0}+${IF_WLAN0} AP=LAN)"
echo "  sudo dhcp-toggle off      # 해제"
echo "  dhcp-toggle status        # 상태 확인"
echo "  dhcp-toggle forward list  # 포트포워딩 목록"
echo ""
echo "Web UI: http://192.168.10.1:8080"
