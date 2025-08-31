#!/bin/bash

# 시스템 업데이트 및 필수 패키지 설치
apt update -y
apt install -y nginx ufw certbot python3-certbot-nginx

# Nginx 설정
systemctl start nginx
systemctl enable nginx

# UFW 방화벽 설정
ufw allow ssh
ufw allow http
ufw allow https
echo "y" | ufw enable

# Certbot (Let\'s Encrypt) 설정 - 도메인 이름을 your_domain.com으로 변경하세요.
# 이메일 주소와 실제 도메인으로 변경해야 합니다.
# 예: certbot --nginx -d example.com -d www.example.com --non-interactive --agree-tos --email your_email@example.com
certbot --nginx -d chavion.com -d www.chavion.com --non-interactive --agree-tos --email kkpetceo1@gmail.com

# Certbot 자동 갱신 설정 확인
systemctl enable certbot.timer
systemctl start certbot.timer

# 웹 서버 루트 디렉토리 생성 및 기본 페이지 설정 (선택 사항)
mkdir -p /var/www/html
echo "<html><body><h1>Welcome to your Nginx server!</h1></body></html>" > /var/www/html/index.nginx-debian.html

# Nginx 재시작 (설정 적용)
systemctl restart nginx


