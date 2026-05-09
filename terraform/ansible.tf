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
resource "local_file" "ansible_config" {
    filename = local.config_path # 경로 확인 필요
    content = <<-EOF
        [defaults]
        inventory = ./inventory.yml
        host_key_checking = False
        stdout_callback = yaml

        # 권한 설정
        allow_world_readable_tmpfiles = True

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
resource "terraform_data" "ansible_provisioning" {
  # 인스턴스와 인벤토리 파일이 준비된 후 실행
  depends_on = [terraform_data.wait_for_instance]

  # EC2 인스턴스가 재생성될 때마다 Ansible 다시 실행
  triggers_replace = aws_instance.app_server.id

  provisioner "local-exec" {
    # ansible 디렉토리로 이동
    # SSH ProxyCommand를 환경변수나 인자로 주입하여 실행
    command = "cd ${local.ansible_dir} && ansible-playbook -i inventory.yml main.yml"
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