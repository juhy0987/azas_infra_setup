locals {
  # 프로젝트 루트 기준 ansible 디렉토리의 절대 경로
  ansible_dir = abspath("${path.module}/../ansible")
  
  # 자주 사용하는 파일 경로들을 미리 정의
  inventory_path = "${local.ansible_dir}/inventory.yml"
  config_path    = "${local.ansible_dir}/ansible.cfg"
}

# 테라폼이 생성한 Private IP를 Ansible 인벤토리에 업데이트
resource "local_file" "ansible_inventory" {
  # 상위 디렉토리의 ansible 폴더 inventory.yml로 지정
  filename = local.inventory_path
  content = yamlencode({
    all = {
      # 모든 호스트에 적용되는 기본 변수
      #   - baked AMI(AL2023) / Rocky / Ubuntu 모두 /usr/bin/python3 보유
      vars = {
        ansible_python_interpreter = "/usr/bin/python3"
      }
      children = {
        Local = { # [Local]
          hosts = {
            localhost = {
              ansible_connection = "local"
            }
          }
        }
        On-Premise = { # [On-Premise]
          hosts = {
            "${var.onprem_rocky_ip}" = { 
              ansible_user = var.BOOTSTRAP_USER
              ansible_become_password = var.BOOTSTRAP_USER
              ansible_ssh_private_key_file = var.onprem_key_path
            }
            "${var.onprem_ubuntu_ip}" = { 
              ansible_user = var.BOOTSTRAP_USER
              ansible_become_password = var.BOOTSTRAP_USER
              ansible_ssh_private_key_file = var.onprem_key_path
            }
          }
        }
        EC2 = { # [EC2]
          hosts = {
            # Bastion을 통해 접속하므로 Private IP를 사용합니다.
            "${aws_instance.app_server.private_ip}" = {
              ansible_user                  = "ec2-user"
              ansible_ssh_private_key_file  = var.aws_key_path
              # EC2 그룹에만 Bastion 프록시 설정을 주입
              ansible_ssh_common_args       = "-o ProxyCommand='ssh -i ${var.aws_key_path} -W %h:%p -q ec2-user@${aws_instance.bastion.public_ip}'"
            }
          }
        }
        DB = { # [DB]
          hosts = {
            "${var.db_server_ip}" = {
              ansible_user     = "ec2-user"
              ansible_ssh_private_key_file = var.db_key_path
            }
          }
        }
        Tailscale = { # [Tailscale] - bastion 자체에 적용
          hosts = {
            # bastion 의 public IP 로 직접 접속 (ProxyCommand 불필요)
            "${aws_instance.bastion.public_ip}" = {
              ansible_user                 = "ec2-user"
              ansible_ssh_private_key_file = var.aws_key_path
              # tailscale 롤이 사용하는 변수 오버라이드
              host_name                    = "azas-bastion"
              aws_vpc_cidr                 = aws_vpc.vpc.cidr_block
            }
          }
        }
      }
    }
  })
}

# ansible.cfg 파일 생성
#   - inventory 두 파일 병행:
#       inventory.yml  : Terraform 정적 (On-Premise / DB / Tailscale / Local + standalone EC2)
#       aws_ec2.yml    : amazon.aws 동적 (ASG 인스턴스를 매 실행시점에 자동 picksup)
resource "local_file" "ansible_config" {
    filename = local.config_path
    content = <<-EOF
        [defaults]
        inventory = ./inventory.yml,./aws_ec2.yml
        host_key_checking = False
        stdout_callback = yaml

        # 권한 설정
        allow_world_readable_tmpfiles = True

        [inventory]
        enable_plugins = amazon.aws.aws_ec2,yaml,ini

        [ssh_connection]
        # Bastion 경유 시 연결 유지를 위해 추천하는 옵션
        ssh_args = -o StrictHostKeyChecking=no -o ControlMaster=auto -o ControlPersist=60s
        pipelining = True
    EOF
}

# 1. 인프라 생성후 ansible play book 을 실행 가능한 시간 만큼 대기한다.
resource "terraform_data" "wait_for_instance" {
    # 서버, 인벤토리, 설정 파일이 모두 준비된 이후에 이 블럭이 실행되도록 순서 보장
    depends_on = [aws_instance.app_server, local_file.ansible_inventory]

    # ec2 인스턴스의 id가 변경된다면 다시 대기 실행하도록 방아쇠를 설치한다 ()
    # 즉 ec2가 새롭게 만들어지면 이블럭이 다시 실행되고 결과적으로 sleep 30 이 다시 실행된다. 
    triggers_replace = aws_instance.app_server.id

    # local computer (rocky linux)에서 실행할 명령
    provisioner "local-exec" {
        command = "sleep 60"
    }
}

# Ansible 실행 (Bastion 호스트를 통한 SSH 터널링 포함)
#   - tailscale_provisioning 이 끝난 뒤에 main.yml 실행
#   - main.yml 의 On-Premise 대상(172.16.8.x) 도달이 management 서버의 tailnet 가입에 의존
#   - AWS 자격증명 / 큐 URL 은 environment 블록으로 직접 주입 (ansible/.env 에 안 둠)
#   - boto3 + amazon.aws collection 도 1회 사전 설치하여 aws_ec2 동적 인벤토리/asg_consumer 가
#     첫 apply 부터 정상 동작하도록 함
resource "terraform_data" "ansible_provisioning" {
  depends_on = [terraform_data.tailscale_provisioning]

  triggers_replace = aws_instance.app_server.id

  provisioner "local-exec" {
    environment = {
      AWS_ACCESS_KEY_ID     = aws_iam_access_key.management_consumer.id
      AWS_SECRET_ACCESS_KEY = aws_iam_access_key.management_consumer.secret
      AWS_REGION            = "ap-northeast-2"
      AWS_DEFAULT_REGION    = "ap-northeast-2"
      ASG_TASKS_QUEUE_URL   = aws_sqs_queue.asg_tasks.url
      ANSIBLE_DIR           = local.ansible_dir
    }

    command = <<-EOT
      set -e
      cd ${local.ansible_dir}
      python3.12 -m pip install --user --quiet boto3 botocore 2>/dev/null \
        || python3.12 -m pip install --user --quiet --break-system-packages boto3 botocore 2>/dev/null \
        || true
      if [ -f .env ]; then set -a; . ./.env; set +a; fi
      ansible-playbook -i inventory.yml -i aws_ec2.yml main.yml
    EOT
  }
}

# Bastion 이 올라오면 Tailscale 자동 등록 + subnet route 광고/승인
#   - 롤 자체가 TAILSCALE_AUTH_KEY / TAILSCALE_API_KEY / TAILNET_NAME 환경변수를 lookup
#   - terraform apply 실행 환경에 위 env 가 export 되어 있어야 함
resource "terraform_data" "tailscale_provisioning" {
  depends_on = [terraform_data.wait_for_instance, local_file.ansible_inventory]

  # bastion 이 재생성될 때마다 Tailscale 다시 적용 (디바이스 등록/라우트 승인)
  triggers_replace = aws_instance.bastion.id

  provisioner "local-exec" {
    command = "cd ${local.ansible_dir} && ansible-playbook -i inventory.yml tailscale.yml"
  }
}