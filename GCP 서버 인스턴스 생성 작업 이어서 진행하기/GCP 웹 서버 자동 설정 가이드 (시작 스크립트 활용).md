# GCP 웹 서버 자동 설정 가이드 (시작 스크립트 활용)

이 가이드는 Google Cloud Platform(GCP) 인스턴스 생성 시 시작 스크립트(Startup Script)를 활용하여 Nginx, UFW(방화벽), Certbot(SSL 인증서)을 자동으로 설치하고 설정하는 방법을 상세히 안내합니다. 이 방법을 사용하면 웹 서버 환경 구축에 필요한 수동 작업을 최소화하고 효율성을 극대화할 수 있습니다.

## 1. GCP 인스턴스 생성 및 시작 스크립트 추가

새로운 GCP 인스턴스를 생성하면서 웹 서버 환경 설정을 자동화하기 위해 시작 스크립트를 추가합니다. 시작 스크립트는 인스턴스가 처음 부팅될 때 한 번 실행되는 스크립트로, 서버 초기 설정에 매우 유용합니다.

### 1.1 GCP 콘솔 접속 및 인스턴스 생성 시작

1.  **GCP 콘솔 접속**: Google Cloud Platform 콘솔(console.cloud.google.com)에 접속하여 로그인합니다.
2.  **VM 인스턴스 생성**: 좌측 메뉴에서 `Compute Engine` > `VM 인스턴스`로 이동한 후, 상단의 `인스턴스 만들기` 버튼을 클릭합니다.

### 1.2 인스턴스 기본 설정

인스턴스 생성 페이지에서 다음 기본 설정을 권장합니다:

*   **이름**: `aiin-autoservice-automated` (원하는 이름으로 지정)
*   **리전**: 사용자에게 가장 가까운 리전 (예: `asia-northeast3`)
*   **영역**: 선택한 리전 내의 영역 (예: `asia-northeast3-a`)
*   **머신 구성**: `E2` 또는 `N1` 시리즈의 적절한 머신 유형 (예: `e2-medium`)
*   **부팅 디스크**: `Ubuntu 22.04 LTS` (가장 안정적인 버전)
*   **방화벽**: `HTTP 트래픽 허용` 및 `HTTPS 트래픽 허용`을 반드시 체크합니다. 이 설정은 GCP 네트워크 방화벽에서 해당 포트를 열어주는 역할을 합니다.

### 1.3 시작 스크립트 추가

인스턴스 생성 페이지에서 아래로 스크롤하여 `관리, 보안, 디스크, 네트워킹, 단일 테넌시` 섹션을 확장합니다. 여기서 `관리` 탭을 선택하고 `자동화` 섹션에서 `시작 스크립트` 필드를 찾습니다. 다음 스크립트 내용을 복사하여 이 필드에 붙여넣습니다.

```bash
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

# Certbot (Let's Encrypt) 설정 - 도메인 이름을 your_domain.com으로 변경하세요.
# 이메일 주소와 실제 도메인으로 변경해야 합니다.
# 예: certbot --nginx -d example.com -d www.example.com --non-interactive --agree-tos --email your_email@example.com
# Certbot은 대화형으로 진행될 수 있으므로, 실제 도메인과 이메일로 변경 후 주석을 해제하고 실행하세요.
sudo certbot --nginx -d chavion.com -d www.chavion.com --non-interactive --agree-tos --email kkpetceo1@gmail.com

# Certbot 자동 갱신 설정 확인
systemctl enable certbot.timer
systemctl start certbot.timer

# 웹 서버 루트 디렉토리 생성 및 기본 페이지 설정 (선택 사항)
mkdir -p /var/www/html
echo "<html><body><h1>Welcome to your Nginx server!</h1></body></html>" > /var/www/html/index.nginx-debian.html

# Nginx 재시작 (설정 적용)
systemctl restart nginx

```

**중요**: 위 스크립트에서 `Certbot (Let's Encrypt) 설정` 부분은 주석 처리되어 있습니다. **실제 도메인 이름과 이메일 주소로 변경한 후 주석을 해제해야 합니다.** 예를 들어, `your_domain.com`을 `example.com`으로, `your_email@example.com`을 실제 이메일 주소로 변경해야 합니다. 도메인이 준비되지 않았다면 이 부분은 나중에 수동으로 진행할 수 있습니다.

### 1.4 인스턴스 생성 완료

모든 설정을 확인한 후 `만들기` 버튼을 클릭하여 인스턴스를 생성합니다. 인스턴스가 부팅되고 시작 스크립트가 실행되는 데 몇 분 정도 소요될 수 있습니다.

인스턴스 생성이 완료되면, 해당 인스턴스의 외부 IP 주소를 확인하여 웹 브라우저에서 접속해 보세요. Nginx 기본 페이지가 보인다면 성공적으로 설정된 것입니다. SSL 인증서 발급은 도메인 연결이 완료된 후에 진행해야 합니다.




## 2. 시작 스크립트 내용 상세 설명

이 섹션에서는 GCP 인스턴스 생성 시 사용되는 시작 스크립트의 각 부분에 대해 상세히 설명합니다. 이 스크립트는 Ubuntu 22.04 LTS 환경을 기준으로 작성되었으며, 웹 서버 구축에 필요한 모든 단계를 자동화합니다.

### 2.1 스크립트 헤더 (`#!/bin/bash`)

```bash
#!/bin/bash
```

이 줄은 셸 스크립트의 시작을 알리는 셔뱅(shebang)입니다. 이 스크립트가 `bash` 셸을 사용하여 실행되어야 함을 시스템에 알려줍니다. GCP 시작 스크립트는 기본적으로 `root` 권한으로 실행되므로, 스크립트 내에서 `sudo`를 사용할 필요는 없지만, 명령어의 명확성을 위해 포함하는 것이 일반적입니다.

### 2.2 시스템 업데이트 및 필수 패키지 설치

```bash
apt update -y
apt install -y nginx ufw certbot python3-certbot-nginx
```

*   `apt update -y`: 이 명령어는 시스템의 패키지 목록을 최신 상태로 업데이트합니다. `-y` 옵션은 모든 프롬프트에 자동으로 '예'라고 응답하여 업데이트 과정을 자동화합니다. 이는 최신 버전의 소프트웨어를 설치하고 잠재적인 보안 취약점을 해결하는 데 중요합니다.
*   `apt install -y nginx ufw certbot python3-certbot-nginx`: 이 명령어는 Nginx, UFW, Certbot, 그리고 Certbot의 Nginx 플러그인을 설치합니다. 이 네 가지 패키지는 웹 서버 구축 및 SSL 인증서 관리에 필수적입니다.
    *   `nginx`: 고성능 웹 서버 및 리버스 프록시 서버입니다.
    *   `ufw`: Uncomplicated Firewall의 약자로, iptables를 쉽게 관리할 수 있도록 돕는 사용자 친화적인 방화벽 도구입니다.
    *   `certbot`: Let's Encrypt를 통해 무료 SSL/TLS 인증서를 발급받고 관리하는 데 사용되는 도구입니다.
    *   `python3-certbot-nginx`: Certbot이 Nginx 웹 서버와 연동하여 SSL 설정을 자동으로 처리할 수 있도록 하는 플러그인입니다.

### 2.3 Nginx 설정

```bash
systemctl start nginx
systemctl enable nginx
```

*   `systemctl start nginx`: Nginx 서비스를 시작합니다. 패키지 설치 후 Nginx는 자동으로 시작될 수 있지만, 명시적으로 시작 명령을 포함하여 확실하게 서비스를 활성화합니다.
*   `systemctl enable nginx`: 시스템 부팅 시 Nginx 서비스가 자동으로 시작되도록 설정합니다. 이는 서버 재부팅 후에도 웹 서비스가 중단 없이 제공되도록 보장합니다.

### 2.4 UFW 방화벽 설정

```bash
ufw allow ssh
ufw allow http
ufw allow https
echo "y" | ufw enable
```

*   `ufw allow ssh`: SSH(Secure Shell) 접속에 사용되는 기본 포트인 22번 포트를 허용합니다. 이는 인스턴스에 원격으로 접속하여 관리할 수 있도록 하는 필수적인 설정입니다.
*   `ufw allow http`: 웹 트래픽에 사용되는 80번 포트(HTTP)를 허용합니다. Nginx가 HTTP 요청을 처리할 수 있도록 합니다.
*   `ufw allow https`: 보안 웹 트래픽에 사용되는 443번 포트(HTTPS)를 허용합니다. SSL/TLS 암호화된 통신을 가능하게 합니다.
*   `echo "y" | ufw enable`: UFW 방화벽을 활성화합니다. `ufw enable` 명령은 방화벽 활성화 시 SSH 연결이 끊어질 수 있다는 경고 메시지를 출력하고 사용자에게 `y/n` 확인을 요청합니다. `echo "y" |`는 이 질문에 자동으로 `y`라고 응답하여 스크립트가 중단 없이 진행되도록 합니다.

### 2.5 Certbot (Let's Encrypt) 설정 (주석 처리됨)

```bash
# Certbot (Let\'s Encrypt) 설정 - 도메인 이름을 your_domain.com으로 변경하세요.
# 이메일 주소와 실제 도메인으로 변경해야 합니다.
# 예: certbot --nginx -d example.com -d www.example.com --non-interactive --agree-tos --email your_email@example.com
# Certbot은 대화형으로 진행될 수 있으므로, 실제 도메인과 이메일로 변경 후 주석을 해제하고 실행하세요。
sudo certbot --nginx -d chavion.com -d www.chavion.com --non-interactive --agree-tos --email kkpetceo1@gmail.com
```

이 부분은 기본적으로 주석 처리되어 있습니다. Certbot을 통해 SSL 인증서를 발급받으려면 실제 도메인 이름과 유효한 이메일 주소가 필요합니다. 인스턴스 생성 시점에 도메인이 아직 연결되지 않았거나, 대화형 프롬프트에 응답하기 어려운 경우를 대비하여 주석 처리되어 있습니다. 인스턴스 생성 후 도메인 연결이 완료되면 이 부분을 수동으로 실행하거나, 스크립트를 수정하여 재실행할 수 있습니다.

*   `--nginx`: Certbot이 Nginx 설정을 자동으로 감지하고 수정하여 SSL을 적용하도록 지시합니다.
*   `-d your_domain.com -d www.your_domain.com`: 인증서를 발급받을 도메인 이름을 지정합니다. 여러 도메인을 지정할 수 있습니다.
*   `--non-interactive`: Certbot이 대화형 프롬프트 없이 자동으로 진행되도록 합니다. 시작 스크립트에서는 필수적입니다.
*   `--agree-tos`: Let's Encrypt 서비스 약관에 자동으로 동의합니다.
*   `--email your_email@example.com`: 인증서 만료 알림 등을 받을 이메일 주소를 지정합니다.

### 2.6 Certbot 자동 갱신 설정 확인

```bash
systemctl enable certbot.timer
systemctl start certbot.timer
```

Let's Encrypt 인증서는 90일마다 갱신해야 합니다. Certbot은 이 과정을 자동화하기 위한 `certbot.timer`라는 `systemd` 타이머 유닛을 제공합니다. 이 명령어들은 `certbot.timer`를 활성화하고 시작하여 인증서가 자동으로 갱신되도록 설정합니다.

### 2.7 웹 서버 루트 디렉토리 생성 및 기본 페이지 설정 (선택 사항)

```bash
mkdir -p /var/www/html
echo "<html><body><h1>Welcome to your Nginx server!</h1></body></html>" > /var/www/html/index.nginx-debian.html
```

*   `mkdir -p /var/www/html`: Nginx의 기본 웹 루트 디렉토리인 `/var/www/html`을 생성합니다. `-p` 옵션은 상위 디렉토리가 없으면 함께 생성합니다.
*   `echo "..." > /var/www/html/index.nginx-debian.html`: 간단한 HTML 파일을 생성하여 Nginx의 기본 웹 페이지로 설정합니다. 이 페이지는 웹 서버가 정상적으로 작동하는지 확인하는 데 사용될 수 있습니다.

### 2.8 Nginx 재시작 (설정 적용)

```bash
systemctl restart nginx
```

스크립트의 마지막 단계에서 Nginx 서비스를 재시작하여 모든 변경 사항(특히 Nginx 설정 파일 변경 또는 SSL 적용)이 올바르게 반영되도록 합니다.

이 시작 스크립트를 사용하면 GCP 인스턴스 생성과 동시에 웹 서버 환경이 자동으로 구성되어, 사용자는 최소한의 노력으로 웹 서비스를 시작할 수 있습니다. Certbot을 통한 SSL 인증서 발급은 도메인 연결 후 수동으로 진행하거나, 스크립트의 해당 부분을 수정하여 자동화할 수 있습니다.




## 3. 최종 환경 검증 및 사용자에게 결과 전달

이 섹션에서는 시작 스크립트를 통해 GCP 인스턴스에 구축된 웹 서버 환경이 정상적으로 작동하는지 최종적으로 검증하고, 사용자에게 이 가이드 문서를 전달하는 방법에 대해 설명합니다. 모든 구성 요소가 올바르게 설정되었는지 확인하는 것은 안정적인 서비스 운영을 위해 매우 중요합니다.

### 3.1 Nginx 작동 확인

Nginx 웹 서버가 정상적으로 실행 중이며, 웹 페이지를 올바르게 서비스하고 있는지 확인합니다. 인스턴스 생성 후 몇 분이 지나면, 웹 브라우저를 열고 새로 생성된 GCP 인스턴스의 **외부 IP 주소**로 접속해 보세요. 시작 스크립트에 포함된 `Welcome to your Nginx server!` 메시지가 포함된 기본 HTML 페이지가 표시된다면 Nginx가 성공적으로 설치 및 실행된 것입니다.

만약 페이지가 표시되지 않는다면, GCP 콘솔에서 해당 인스턴스의 SSH 터미널에 접속하여 다음 명령어를 실행하여 Nginx 서비스의 상태를 확인합니다.

```bash
sudo systemctl status nginx
```

`active (running)` 상태를 확인하고, 오류 메시지가 없는지 점검합니다. 만약 Nginx가 예상대로 작동하지 않는다면, Nginx 에러 로그(`sudo tail -f /var/log/nginx/error.log`)를 확인하여 문제의 원인을 파악해야 합니다.

### 3.2 UFW 방화벽 작동 확인

UFW 방화벽이 올바르게 활성화되어 있고, 필요한 포트(SSH, HTTP, HTTPS)가 허용되었는지 확인합니다. 이는 서버의 보안을 유지하면서 웹 서비스가 외부에서 접근 가능하도록 보장합니다.

인스턴스의 SSH 터미널에서 다음 명령어를 실행합니다.

```bash
sudo ufw status verbose
```

이 명령어를 통해 UFW의 상태가 `active`이고, `22/tcp (SSH)`, `80/tcp (HTTP)`, `443/tcp (HTTPS)` 포트가 `ALLOW`로 설정되어 있는지 확인합니다. 만약 규칙이 올바르지 않다면, 시작 스크립트의 UFW 관련 부분을 다시 확인하거나 수동으로 규칙을 추가해야 합니다.

### 3.3 Certbot 및 SSL 인증서 (선택 사항)

시작 스크립트에서 Certbot 설치는 포함되었지만, SSL 인증서 발급은 도메인 연결이 필요하므로 주석 처리되어 있습니다. 만약 도메인을 연결하고 Certbot을 통해 SSL 인증서를 발급받았다면, 웹 브라우저에서 `https://your_domain.com`으로 접속했을 때 주소창에 자물쇠 아이콘이 표시되고 인증서 정보가 유효한지 확인합니다.

Certbot의 자동 갱신 기능이 정상적으로 설정되었는지 테스트하려면 다음 명령어를 사용합니다.

```bash
sudo certbot renew --dry-run
```

이 명령어가 `Congratulations, all renewals succeeded:` 메시지를 반환하면, 인증서 자동 갱신이 문제없이 작동할 준비가 된 것입니다.

### 3.4 최종 결과 전달

모든 검증 단계를 성공적으로 완료했다면, GCP 인스턴스에 Nginx, UFW, Certbot을 포함한 웹 서버 환경이 시작 스크립트를 통해 안정적으로 구축된 것입니다. 이제 이 가이드 문서를 사용자에게 전달하여, 사용자가 직접 GCP 서버를 설정하고 웹 서비스를 운영할 수 있도록 돕습니다.

이 가이드 문서는 GCP 인스턴스 생성 시 시작 스크립트를 활용하여 웹 서버 환경을 자동화하는 과정을 상세히 설명합니다. 이 문서를 통해 사용자는 웹 서비스 배포 및 운영에 대한 자신감을 얻을 수 있을 것입니다.

--- 

**저자**: Manus AI

**참고 자료**:

[1] Nginx 공식 문서: [https://nginx.org/en/docs/](https://nginx.org/en/docs/)
[2] UFW (Uncomplicated Firewall) 공식 문서: [https://ubuntu.com/server/docs/firewall](https://ubuntu.com/server/docs/firewall)
[3] Certbot 공식 문서: [https://certbot.eff.org/docs/](https://certbot.eff.org/docs/)
[4] Google Cloud Platform (GCP) 공식 문서: [https://cloud.google.com/docs](https://cloud.google.com/docs)


