# dhcp-toggle

NanoPi R6S 용 DHCP 서버 모드 토글 도구 (CLI + Web UI).

자세한 문서는 [deploy/README.md](deploy/README.md)를 참고하세요.

## 빠른 시작

```bash
# 설치
sudo bash deploy/install.sh

# 모드 전환
sudo dhcp-toggle a          # 유선 WAN 라우터 모드
sudo dhcp-toggle b          # Wi-Fi WAN 라우터 모드
sudo dhcp-toggle off        # 데스크톱 모드

# 포트포워딩
sudo dhcp-toggle forward add http_s 80,443 192.168.10.101 80,443 tcp
dhcp-toggle forward list

# Web UI
# http://192.168.10.1:8080
```
