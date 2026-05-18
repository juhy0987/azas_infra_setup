# 클라우드 기반 재해 복구 시스템

평시가 아닌, 급격한 서버 마비 상황에서 서비스 가용성을 빠르게 복구시키고 트래픽을 안정적으로 처리하기 위한 시스템

### 팀명

- Azas Team

### 💠 팀원

- 김주현(팀장), 임종원, 강윤주, 박영헌, 유현상

### 💠 역할 분담

- 김주현(팀장)
    - 아키텍처 총괄
- 임종원
    - AWS 클라우드
- 강윤주
    - 서비스 레이어
- 박영헌
    - DB
- 유현상
    - 온프레미스

### 💠 사용 기술 및 도구

`사용 예정인 기술, 툴, 프레임워크 등`

- **기술 스택**
    - 언어 및 프레임워크: Python (FastAPI), JWT (JSON Web Token)
    - Web Server: Nginx
    - DB: PostgreSQL
    - 클라우드 플랫폼 : AWS
        - 라우팅 & 가용성: AWS Route 53, ALB, ASG
        - 컴퓨팅 & 가상화: AWS EC2, AWS Lambda
        - 보안 & 스토리지: AWS ACM, AWS S3
        - 메시징 큐: AWS SQS
    - 코드형 인프라 (IaC): Terraform, Ansible
    - 네트워크 & VPN: Tailscale
    - 모니터링 및 시각화: Prometheus, Grafana
    - 장애 알림: Telegram
    - 부하 테스트: stress
- **사용 도구**
    - CI/CD 배포 자동화: GitHub Actions Runner
    - 버전 관리 : Git, GitHub
    - IDE & 터미널: VS Code, MobaXterm
    - 가상화 플랫폼: VMware Workstation Pro
    - 아키텍처 디자인: Draw.io
    - 문서화 및 협업: Notion, Google Drive

### Convention

## Github

### Issue
**템플릿을 준수**
이슈 타이틀 형태: `[카테고리]: 이슈 제목`

카테고리
- Feature: 기능 추가, 기능 변경
- Refactor: 리팩토링, 구조 변경
- Bug: 발생한 버그 목록
- Chore: 의존성, 문서 작업 등 코드 외 작업 (별도의 의존성 작업만 추가할 경우)

EX
`[Feature] OAuth 2.0 추가`
`[Refactor] Ansible 모듈 리팩토링`

### Branch
브랜치 이름 형태: `카테고리/#이슈번호/브랜치명`

카테고리
- feature: 기능 추가, 기능 변경
- refactor: 리팩토링, 구조 변경
- fix: 버그 수정
- chore: 의존성, 문서 작업 등 코드 외 작업 (별도의 의존성 작업만 추가할 경우)

### Commit
커밋 메시지 형태: `[카테고리]: 커밋 내용`

카테고리
- FEAT: 기능 추가, 기능 변경
- REFAC: 리팩토링, 구조 변경
- FIX: 버그 수정, 오류 수정
- CHORE: 의존성 추가, 코드 외 작업

EX
`[FEAT]: OAuth2.0 추가 - Google, Naver Authentication`
`[CHORE]: pytest 의존성 추가`

### PR 컨벤션
**템플릿을 준수**

제목 형태: `[카테고리#이슈번호] PR 제목`

카테고리
- FEAT: 기능 추가, 기능 변경
- REFAC: 리팩토링, 구조 변경
- FIX: 버그 수정, 오류 수정
- CHORE: 의존성 추가, 코드 외 작업
**카테고리는 커밋과 동일**

EX
`[FEAT#18] Google, Naver OAuth 2.0 추가`

### 아키텍처 다이어그램
#### 1. 하이브리드 클라우드 인프라 구성도
<p align="center">
<img src="./asset/하이브리드 클라우드 인프라 구성도.drawio.png" 
     width="50%" 
     alt="하이브리드 클라우드 인프라 구성도">
</p>

#### 2. AWS 구조
<p align="center">
<img src="./asset/aws구조.drawio.png" 
     width="50%" 
     alt="aws구조">
</p>


#### 3. CI/CD 파이프라인 구성도
<p align="center">
<img src="./asset/CI_CD Pipe line.drawio.png" 
     width="50%" 
     alt="CI/CD 파이프라인 구성도">
</p>


### 인프라 재현 방법(How to run)
#### 사전 요구사항 및 배포 절차
#### 1. **Mgmt git, Ansible, Terraform, AWS cli, Tailscale 설치 완료 상태**
> `git` 및 `AWS CLI`는 자격 증명(로그인/Configure)이 완료된 상태
#### 2. **On-Premise 서버는 ssh 연결 가능해야 함**
> `username: user1@{서버}`, `pw: user1` 으로 로그인 가능하다는 전제 
#### 3. **defaultkey.pem, one_key을 ~/.ssh에 보유해야 함**
> 접근 권한 600 설정이 필요하며, DB는 별도 세팅
```bash
chmod 600 ~/.ssh/defaultkey.pem ~/.ssh/one_key
```
#### 4. **Ansible Collection 사전 설치 (`amazon.aws`, `prometheus.prometheus`)**
> Terraform으로 구성할 수도 있으나, 본 아키텍처에서는 통일화된 환경을 위해 사전 설치를 전제
```bash
ansible-galaxy collection install amazon.aws prometheus.prometheus
```
#### 5. **local 환경 python3.12 jmespath 사용 가능한 상태로 유지**
```bash
pip install jmespath
```
#### 6. **Terraform 버전 통일 (~>1.15.0)**
   > 코드 호환성 및 상태 파일(State) 충돌 방지를 위해 테라폼 버전을 일치
#### 7. **github actions runner 세팅 필수**
   - workflow를 통한 자동 배포 환경(CI/CD)을 구성
#### 8. **동일한 이름의 aws 객체, tailscale 그룹이 없는지 확인**
   - 자원 생성 에러를 방지하기 위해 기존 인프라와의 이름 중복 여부를 사전 검증
#### 9. **workflow에서 Deploy 트리거**
   - 모든 사전 준비가 완료되면 GitHub Actions 탭에서 배포 워크플로우를 실행

### 재해 복구 시나리오
#### 1. **평시 운영**
> 온프레미스 상 서비스 운영
#### 2. **장애 감지**
> 온프레미스 부하 발생, Telegram에 알림 발송(약 2분의 지연 있음)
```bash
cd ansible && ansible-playbook load_test.yml
```
#### 3. **트래픽 전환**
> ALB(Application Load Balancer) 단일 진입점을 통한 흐름 유지
#### 4. **ALB 가중치에 따라 클라우드로 전환**
> 가중치 포워딩 정책 및 헬스체크 기반의 Failover
> ASG 스케일 아웃
#### 5. **트래픽 과다 상태에 따른 ASG 자동 대응**
> Min: 1 / Desired: 1 / Max: 4
#### 6. **부하 해제**
> 온프레미스 부하 해제
```bash
cd ansible && ansible-playbook load_stop.yml
```
#### 7. **정상화** 
> 메인 서버 복귀 및 자원 최적화(Scale-In)

### 환경 변수 설정

`테라폼 변수 설정 `
-보안이 필요한 부분 하드코딩을 배제하고 외부 환경 변수 패턴을 사용하여 설계

#### [~/.bashrc 작성 예시]
```bash
export TF_VAR_domain_name="도메인이름"
export TF_VAR_BOOTSTRAP_USER="user1"
```

#### [variables.tf 작성 예시]
```hcl
# 도메인 네임
variable "domain_name" {
  description = "본인이 소유한 도메인 이름"
  type        = string 
}

# 대상서버에 원격 접속 시도할때 사용하는 로그인 아이디,비밀번호
variable "BOOTSTRAP_USER" {
  description = "ansible_user, ansible_become_password"
  type = string
}

# Tailscale 로 도달할 온프레미스 사설 대역
variable "onprem_cidr" {
  description = "Bastion+Tailscale 을 통해 도달할 온프레미스 사설 네트워크 CIDR"
  type        = string
  default     = "172.16.8.0/24"
}

# ALB 가중치 분배 - AWS / 온프레미스
variable "alb_aws_weight" {
  description = "ALB HTTPS default action 에서 AWS target group 가중치"
  type        = number
  default     = 1
}

variable "alb_onprem_weight" {
  description = "ALB HTTPS default action 에서 온프레미스 target group 가중치"
  type        = number
  default     = 100
}
```
`엔서블 변수 설정`
- Ansible Role은 하드코딩을 배제하고 외부 환경 변수 패턴을 사용하여 설계


#### [~/.bashrc 작성 예시]

```bash
# 발급처: Tailscale Admin Console > Settings > Keys > Auth Keys
export TAILSCALE_AUTH_KEY="tskey-auth-kX721aB..."
# 발급처: Tailscale Admin Console > Settings > Keys > API Keys
export TAILSCALE_API_KEY="tskey-api-vA931mZ..."
# Tailscale Admin Console 좌측 상단 확인 가능
export TAILNET_NAME="사용자@이메일"
```

- 기본값 오버라이딩 최적화:
defaults는 우선순위가 가장 낮기 때문에, lookup('env', ...)을 통해 환경 변수를 주입받고, 값이 없을 때만 default('기본값')이 작동하도록 유연하게 설계
#### [defaults/main.yml 작성 예시]
```yaml
tailscale_auth_key: "{{ lookup('env', 'TAILSCALE_AUTH_KEY') }}"
tailscale_api_key: "{{ lookup('env', 'TAILSCALE_API_KEY') }}"
tailnet_name: "{{ lookup('env', 'TAILNET_NAME') }}"
```

#### 수정된 환경 변수를 현재 터미널에 즉시 반영
```bash
source ~/.bashrc
```

#### GitHub Actions Secrets 설정 예시
| 구분 | 변수명 (Name) | 설명 / 발급 및 확인 방법 |
| :--- | :--- | :--- |
| **Secrets** | `TAILSCALE_AUTH_KEY` | 온프레미스-AWS 간 사설망 연결을 위한 디바이스 자동 등록 키<br>*(발급: Tailscale Admin Console > Settings > Keys > Auth Keys)* |
| **Secrets** | `TAILSCALE_API_KEY` | Tailscale 인프라 제어 및 서브넷 라우터 자동 승인을 위한 API 키<br>*(발급: Tailscale Admin Console > Settings > Keys > API Keys)* |
| **Secrets** | `TAILNET_NAME` | 본인의 Tailscale 조직명 (보통 `사용자계정@이메일` 형태)<br>*(확인: Tailscale Admin Console 좌측 상단)* |
| **Secrets** | `DOMAIN_NAME` | Route 53 및 ALB 장애 조치(Failover) 라우팅에 사용할 본인 소유의 도메인 (`example.com`) |
| **Secrets** | `SSH_PASSWORD` | 온프레미스 초기 프로비저닝 및 Ansible 내부 원격 접속용 패스워드 (`user1`) |
| **Secrets** | `TELEGRAM_BOT_TOKEN` | 장애 상황(온프레미스 부하 등) 발생 시 알림을 전송할 텔레그램 봇 토큰 값 |
| **Secrets** | `TELEGRAM_CHAT_ID` | 텔레그램 알림을 수신할 대상 대화방(채팅방)의 고유 ID 값 |
| **Secrets** | `GRAFANA_ADMIN_ID` | 모니터링 및 대시보드 확인을 위한 Grafana 관리자 로그인 ID |
| **Secrets** | `GRAFANA_ADMIN_PW` | 모니터링 및 대시보드 확인을 위한 Grafana 관리자 로그인 비밀번호 |
