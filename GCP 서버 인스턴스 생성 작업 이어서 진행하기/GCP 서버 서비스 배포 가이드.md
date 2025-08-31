# GCP 서버 서비스 배포 가이드

이 문서는 Google Cloud Platform(GCP) 인스턴스에 확정된 기술 스택(Flask, FastAPI, Celery, Redis, PostgreSQL, Nginx, Flask-SocketIO) 기반의 서비스를 Docker Compose를 활용하여 배포하는 과정을 상세히 안내합니다. 본 가이드를 통해 사용자는 서버 환경 설정부터 서비스 배포 및 Nginx를 통한 리버스 프록시 설정, SSL 인증서 적용까지의 전반적인 과정을 이해하고 직접 수행할 수 있습니다.

## 1. 아키텍처 개요

본 프로젝트는 다음과 같은 서비스 구성과 포트 할당을 기반으로 합니다.

| 서비스명             | 기술 스택           | 내부 포트 | 외부 포트 | 비고                                   |
| :------------------- | :------------------ | :-------- | :-------- | :------------------------------------- |
| **리버스 프록시**    | Nginx               | 80, 443   | 80, 443   | 모든 외부 트래픽 수신 및 라우팅, SSL 처리 |
| **웹 서비스**        | Flask + React       | 5002      | N/A       | chavion.com 메인 웹 서비스             |
| **대시보드**         | FastAPI             | 5004      | N/A       | 오케스트레이터 API/UI                  |
| **Executor**         | Celery              | 5051      | N/A       | 비상 직접 실행 포트 (평시 미사용)      |
| **작업 큐/캐시**     | Redis               | 6379      | N/A       | Celery 브로커 및 캐싱                  |
| **데이터베이스**     | PostgreSQL          | 5432      | N/A       | 영구 데이터 저장                       |
| **실시간 소통**      | Flask-SocketIO      | N/A       | N/A       | 웹 서비스 내 통합                     |

모든 서비스는 Docker 컨테이너로 격리되어 실행되며, Docker Compose를 통해 통합 관리됩니다. Nginx는 외부에서 들어오는 HTTP(80) 및 HTTPS(443) 요청을 받아 적절한 내부 서비스(웹 서비스 또는 대시보드)로 라우팅하는 리버스 프록시 역할을 수행합니다. SSL 인증서는 Certbot을 통해 자동으로 발급 및 갱신됩니다.

## 2. GCP 인스턴스 준비

서비스 배포를 시작하기 전에 GCP 인스턴스가 다음 요구 사항을 충족하는지 확인해야 합니다.

### 2.1 권장 인스턴스 사양

*   **운영체제**: Ubuntu 22.04 LTS (Debian 기반 Linux)
*   **머신 유형**: 최소 `e2-medium` (2 vCPU, 4GB 메모리) 이상 권장. 서비스 규모에 따라 더 높은 사양 필요.
*   **부팅 디스크**: 최소 50GB SSD 이상 권장.
*   **방화벽 설정**: GCP 콘솔에서 HTTP (80), HTTPS (443), SSH (22) 트래픽을 허용하도록 방화벽 규칙을 설정해야 합니다. 이는 인스턴스 생성 시 `HTTP 트래픽 허용` 및 `HTTPS 트래픽 허용`을 체크하는 것으로 충분합니다.

### 2.2 필수 소프트웨어 설치

GCP 인스턴스에 접속하여 다음 소프트웨어가 설치되어 있는지 확인하고, 설치되어 있지 않다면 설치를 진행합니다.

#### 2.2.1 Docker 및 Docker Compose 설치

Docker와 Docker Compose는 컨테이너 기반 서비스 배포의 핵심 도구입니다. 다음 명령어를 순서대로 실행하여 설치합니다.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker 서비스를 시작하고 부팅 시 자동 실행 설정
sudo systemctl start docker
sudo systemctl enable docker

# 현재 사용자에게 Docker 권한 부여 (재로그인 필요)
sudo usermod -aG docker $USER
```

**참고**: `sudo usermod -aG docker $USER` 명령어를 실행한 후에는 변경 사항을 적용하기 위해 SSH 세션을 종료하고 다시 접속해야 합니다. 이 과정은 Docker 명령어를 `sudo` 없이 실행할 수 있도록 해줍니다.

#### 2.2.2 Git 설치 (선택 사항)

만약 소스 코드를 Git 저장소에서 클론할 계획이라면 Git을 설치합니다.

```bash
sudo apt-get install -y git
```

## 3. 프로젝트 파일 준비 및 전송

로컬 개발 환경에서 작성된 Docker Compose 파일과 서비스별 코드(Flask, FastAPI, Celery 등)를 GCP 인스턴스로 전송해야 합니다. 여기서는 `scp` 명령어를 사용하는 방법을 안내합니다.

### 3.1 프로젝트 디렉토리 구조

모든 서비스 관련 파일은 다음과 같은 디렉토리 구조를 가집니다.

```
/path/to/your/project/
├── docker-compose.yml
├── web/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── dashboard/
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
├── executor/
│   ├── Dockerfile
│   ├── celery_worker.py
│   └── requirements.txt
├── nginx/
│   ├── nginx.conf
│   └── conf.d/
│       └── default.conf
└── certbot/
    ├── conf/ (비어 있음)
    └── www/ (비어 있음)
```

### 3.2 파일 전송 (SCP 사용)

로컬 터미널에서 다음 `scp` 명령어를 사용하여 전체 프로젝트 디렉토리를 GCP 인스턴스로 전송합니다. `[YOUR_SSH_KEY_PATH]`는 GCP 인스턴스 접속에 사용하는 SSH 키 파일의 경로이고, `[YOUR_GCP_USERNAME]`은 GCP 인스턴스 사용자 이름(일반적으로 `ubuntu`), `[YOUR_GCP_EXTERNAL_IP]`는 인스턴스의 외부 IP 주소입니다.

```bash
scp -r -i [YOUR_SSH_KEY_PATH] /path/to/your/project/ [YOUR_GCP_USERNAME]@[YOUR_GCP_EXTERNAL_IP]:/home/[YOUR_GCP_USERNAME]/
```

예시:

```bash
scp -r -i ~/.ssh/google_compute_engine ~/my_chavion_project/ ubuntu@34.123.45.67:/home/ubuntu/
```

파일 전송이 완료되면 GCP 인스턴스에 SSH로 접속하여 `/home/[YOUR_GCP_USERNAME]/my_chavion_project/` 경로에 파일들이 올바르게 전송되었는지 확인합니다.

## 4. Docker Compose를 이용한 서비스 배포

프로젝트 파일이 GCP 인스턴스에 준비되었다면, 이제 Docker Compose를 사용하여 모든 서비스를 한 번에 배포할 수 있습니다.

### 4.1 초기 SSL 인증서 발급 및 Nginx 설정

Certbot을 통해 SSL 인증서를 발급받기 위해서는 Nginx가 80번 포트로 `/.well-known/acme-challenge/` 경로에 대한 요청을 처리할 수 있어야 합니다. 초기 배포 시에는 Nginx 컨테이너만 먼저 실행하여 Certbot이 인증서 검증을 수행할 수 있도록 합니다.

1.  **Nginx 및 Certbot 볼륨 디렉토리 생성 (필요시)**

    ```bash
    sudo mkdir -p /home/ubuntu/my_chavion_project/certbot/www
    sudo mkdir -p /home/ubuntu/my_chavion_project/certbot/conf
    ```

2.  **Nginx 컨테이너만 실행**

    ```bash
    cd /home/ubuntu/my_chavion_project/
    sudo docker compose up -d nginx
    ```

3.  **SSL 인증서 발급 (Certbot)**

    `chavion.com` 및 `dashboard.chavion.com` 도메인에 대한 SSL 인증서를 발급받습니다. `[YOUR_EMAIL]`과 `chavion.com`을 실제 도메인과 이메일 주소로 변경해야 합니다.

    ```bash
    sudo docker compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot -d chavion.com -d www.chavion.com --email [YOUR_EMAIL] --agree-tos --no-eff-email
    sudo docker compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot -d dashboard.chavion.com --email [YOUR_EMAIL] --agree-tos --no-eff-email
    ```

    **참고**: 이 명령어를 실행하기 전에 `chavion.com` 및 `dashboard.chavion.com` 도메인의 DNS A 레코드가 GCP 인스턴스의 외부 IP 주소를 가리키도록 설정되어 있어야 합니다. DNS 전파에는 시간이 걸릴 수 있으므로, 미리 설정해두는 것이 좋습니다.

4.  **Nginx SSL 설정 파일 생성**

    Certbot이 생성한 SSL 인증서를 Nginx가 사용할 수 있도록 `options-ssl-nginx.conf`와 `ssl-dhparams.pem` 파일을 생성합니다.

    ```bash
    sudo docker compose run --rm certbot sh -c "mkdir -p /etc/letsencrypt/options-ssl-nginx.conf && cp /etc/letsencrypt/options-ssl-nginx.conf /etc/letsencrypt/ssl-dhparams.pem /etc/letsencrypt/live/chavion.com/"
    ```

    **주의**: 위 명령어는 Certbot이 생성한 파일을 Nginx 컨테이너가 접근할 수 있는 볼륨 경로로 복사하는 예시입니다. 실제 Certbot의 출력 경로와 Nginx 설정에 맞게 조정해야 합니다. `docker-compose.yml`의 `nginx` 서비스 `volumes` 설정에 따라 `certbot/conf`와 `certbot/www` 경로가 `/etc/letsencrypt`와 `/var/www/certbot`에 매핑되므로, Certbot이 이 경로에 파일을 생성하도록 유도하거나, 생성된 파일을 해당 경로로 복사해야 합니다.

    **더 간단한 방법**: `docker-compose.yml`의 `certbot` 서비스 `volumes` 설정을 통해 Certbot이 직접 `certbot/conf`와 `certbot/www`에 파일을 생성하도록 설정했으므로, 별도의 복사 명령어 없이 Nginx 설정 파일에서 해당 경로를 직접 참조하도록 구성하면 됩니다. `nginx/conf.d/default.conf` 파일에 이미 `/etc/letsencrypt/live/chavion.com/fullchain.pem` 등을 참조하도록 설정되어 있습니다.

### 4.2 전체 서비스 배포

SSL 인증서 발급이 완료되었다면, 이제 모든 서비스를 Docker Compose로 빌드하고 실행합니다.

```bash
cd /home/ubuntu/my_chavion_project/
sudo docker compose down # 기존에 실행 중인 Nginx 컨테이너 중지
sudo docker compose up --build -d
```

이 명령어는 `docker-compose.yml` 파일에 정의된 모든 서비스를 빌드하고 백그라운드에서 실행합니다. `--build` 옵션은 Dockerfile이 변경되었거나 이미지가 없는 경우 다시 빌드하도록 합니다. `-d` 옵션은 서비스를 데몬(백그라운드)으로 실행합니다.

### 4.3 서비스 상태 확인

모든 서비스가 정상적으로 실행 중인지 확인합니다.

```bash
sudo docker compose ps
```

모든 서비스의 `State`가 `Up`으로 표시되어야 합니다. 만약 `Exit` 상태인 서비스가 있다면, 해당 서비스의 로그를 확인하여 문제 원인을 파악해야 합니다.

```bash
sudo docker compose logs [서비스명]
```

예시: `sudo docker compose logs web`

## 5. 서비스 검증

모든 서비스가 성공적으로 배포되었다면, 웹 브라우저를 통해 접속하여 정상 작동하는지 확인합니다.

*   **chavion.com 웹 서비스**: 웹 브라우저에서 `https://chavion.com`으로 접속하여 Flask 웹 서비스의 기본 페이지(`Hello from Flask Web Service!`)가 표시되는지 확인합니다.
*   **대시보드**: 웹 브라우저에서 `https://dashboard.chavion.com`으로 접속하여 FastAPI 대시보드의 기본 응답(`{"message": "Hello from FastAPI Dashboard!"}`)이 표시되는지 확인합니다.

SSL 인증서가 올바르게 적용되었는지 확인하려면 브라우저의 주소창에 있는 자물쇠 아이콘을 클릭하여 인증서 정보를 확인합니다.

## 6. Certbot 자동 갱신 설정

Certbot은 Let's Encrypt 인증서의 자동 갱신을 위해 `certbot.timer`를 사용합니다. `docker-compose.yml`에 `certbot` 서비스가 포함되어 있으므로, Docker Compose를 통해 배포하면 자동으로 갱신 스케줄이 설정됩니다. Certbot 컨테이너가 주기적으로 인증서 갱신을 시도합니다.

자동 갱신 테스트는 다음 명령어로 수행할 수 있습니다.

```bash
sudo docker compose run --rm certbot renew --dry-run
```

이 명령어가 `Congratulations, all renewals succeeded:` 메시지를 반환하면, 인증서 자동 갱신이 문제없이 작동할 준비가 된 것입니다.

## 7. 문제 해결 팁

*   **컨테이너 빌드 실패**: `Dockerfile` 또는 `requirements.txt` 파일에 오류가 없는지 확인합니다. `sudo docker compose build --no-cache` 명령어로 캐시를 사용하지 않고 다시 빌드해 봅니다.
*   **컨테이너 실행 실패**: `sudo docker compose logs [서비스명]` 명령어로 해당 서비스의 로그를 확인하여 오류 메시지를 분석합니다.
*   **포트 충돌**: `sudo netstat -tulpn` 명령어로 현재 사용 중인 포트를 확인하고, `docker-compose.yml` 파일의 포트 매핑이 다른 서비스와 충돌하지 않는지 확인합니다.
*   **Nginx 설정 오류**: `sudo docker compose exec nginx nginx -t` 명령어로 Nginx 설정 파일의 문법 오류를 확인합니다. 오류가 없다면 `sudo docker compose restart nginx`로 Nginx를 재시작합니다.
*   **SSL 인증서 문제**: 도메인 DNS 설정이 올바른지, Certbot 명령어가 정확한지, 그리고 Nginx 설정 파일에서 인증서 경로가 올바르게 지정되었는지 확인합니다.

이 가이드를 통해 성공적으로 서비스를 배포하시길 바랍니다. 추가적인 질문이나 문제가 발생하면 언제든지 문의해주세요.

---

**저자**: Manus AI

**참고 자료**:

[1] Docker 공식 문서: [https://docs.docker.com/](https://docs.docker.com/)
[2] Docker Compose 공식 문서: [https://docs.docker.com/compose/](https://docs.docker.com/compose/)
[3] Nginx 공식 문서: [https://nginx.org/en/docs/](https://nginx.org/en/docs/)
[4] Certbot 공식 문서: [https://certbot.eff.org/docs/](https://certbot.eff.org/docs/)
[5] Google Cloud Platform (GCP) 공식 문서: [https://cloud.google.com/docs](https://cloud.google.com/docs)


