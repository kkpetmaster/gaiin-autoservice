#!/bin/bash

# 1. 시스템 업데이트 및 필수 패키지 설치
echo "Updating system and installing necessary packages..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release git nginx

# 2. Docker 및 Docker Compose 설치
echo "Installing Docker and Docker Compose..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker 서비스 시작 및 부팅 시 자동 실행 설정
sudo systemctl start docker
sudo systemctl enable docker

# 현재 사용자에게 Docker 권한 부여 (재로그인 필요 없도록 스크립트 내에서 처리)
sudo usermod -aG docker ubuntu

# iptables-legacy 설정 (Docker 빌드 오류 방지)
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# 3. Git 저장소 클론
echo "Cloning Git repository..."
PROJECT_DIR="/home/ubuntu/gaiin-autoservice"
if [ -d "$PROJECT_DIR" ]; then
    echo "Project directory already exists. Pulling latest changes."
    cd "$PROJECT_DIR"
    git pull
else
    git clone https://github.com/kkpetmaster/gaiin-autoservice.git "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

# 4. Certbot 관련 디렉토리 생성
echo "Creating Certbot directories..."
mkdir -p certbot/conf certbot/www

# 5. Docker Compose를 이용한 서비스 배포
echo "Starting Docker Compose services..."

# Nginx 컨테이너만 먼저 실행하여 Certbot이 인증서 검증을 수행할 수 있도록 함
# Nginx가 80/443 포트를 사용하므로, Certbot 실행 전에 Nginx를 중지해야 함
# Docker Compose 파일에 Nginx가 정의되어 있으므로, Certbot 실행 시 Nginx를 제외하고 실행

# Certbot 실행을 위해 Nginx를 잠시 중지 (만약 실행 중이라면)
sudo systemctl stop nginx || true

# Certbot 컨테이너를 위한 Nginx 설정 파일 임시 생성 (webroot 경로만)
cat <<EOF > nginx/conf.d/temp_certbot.conf
server {
    listen 80;
    server_name chavion.com www.chavion.com dashboard.chavion.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
}
EOF

# Nginx 컨테이너만 빌드 및 실행 (Certbot을 위한 임시 설정 사용)
sudo docker compose up -d nginx

# Certbot을 사용하여 SSL 인증서 발급
# Certbot 컨테이너가 /var/www/certbot에 접근할 수 있도록 볼륨 매핑 확인
# Certbot 실행 시 Nginx가 80번 포트를 점유하고 있을 수 있으므로, Nginx를 잠시 중지하고 Certbot 실행

# Certbot 실행 전 Nginx 컨테이너 중지
sudo docker compose stop nginx

# chavion.com 도메인 인증서 발급
sudo docker compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot -d chavion.com -d www.chavion.com --email kkpetceo1@gmail.com --agree-tos --no-eff-email --force-renewal

# dashboard.chavion.com 도메인 인증서 발급
sudo docker compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot -d dashboard.chavion.com --email kkpetceo1@gmail.com --agree-tos --no-eff-email --force-renewal

# Certbot이 생성한 SSL 설정 파일 복사 (Nginx가 참조할 수 있도록)
# Certbot 컨테이너 내부에서 /etc/letsencrypt/options-ssl-nginx.conf와 ssl-dhparams.pem을 생성하므로, 이를 호스트로 복사
# Docker Compose 볼륨 매핑을 통해 이미 호스트의 certbot/conf 디렉토리에 저장됨
# Nginx 설정 파일에서 이 경로를 직접 참조하도록 되어 있음

# 임시 Nginx 설정 파일 삭제
rm nginx/conf.d/temp_certbot.conf

# 모든 서비스 빌드 및 실행
echo "Building and starting all services..."
sudo docker compose down # 기존 컨테이너 중지 및 제거
sudo docker compose up --build -d

echo "Deployment complete!"


