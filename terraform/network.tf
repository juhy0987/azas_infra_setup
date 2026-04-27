# vpc 및 네트워크 생성 
resource "aws_vpc" "vpc" {
    cidr_block              = "192.168.0.0/16"
    enable_dns_hostnames    = true
    tags = { Name           = "azas-vpc" }
}

# 인터넷 게이트 웨이
resource "aws_internet_gateway" "igw" {
    # 위에서 만들어진 vpc
    vpc_id          = aws_vpc.vpc.id
    tags = { Name   = "azas-igw" }
}

# 멀티 가용 영역 서브넷 설정 (ALB 필수 조건)
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.8.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = { Name           = "azas-public-2a" }
}

resource "aws_subnet" "public_subnet_c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.9.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags = { Name           = "azas-public-2c" }
}

# private subnet(ec2)
resource "aws_subnet" "private_subnet_a" {
    vpc_id                = aws_vpc.vpc.id
    cidr_block            = "192.168.1.0/24" # 256개의 ip를 이방에 할당
    availability_zone     = "ap-northeast-2a"
    tags = { Name         = "azas-private-subnet" }
}

# NAT 게이트웨이 설정 (프라이빗 서버 외출용)
resource "aws_eip" "nat_eip" {
  domain  = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_a.id # 퍼블릭에 위치
  tags          = { Name = "azas-nat-gw" }
}

# 라우팅 테이블 및 연결
resource "aws_route_table" "public_rt" {
    # 어떤 vpc의 소속인지 설정
    vpc_id          = aws_vpc.vpc.id
    # 라우팅 규칙 (0.0.0.0/0)으로 가는 트래픽은 인터넷게이트(igw) 웨이로 보내라
    route {
        cidr_block  = "0.0.0.0/0"
        gateway_id  = aws_internet_gateway.igw.id
    }
    tags = {
        Name        = "azas-route"
    }
}

# public subnet 을  public_rt 라우팅 테이블로 연결
resource "aws_route_table_association" "pub_a" {
    subnet_id       = aws_subnet.public_subnet_a.id # 퍼블릿 서브넷 id
    route_table_id  = aws_route_table.public_rt.id # public_rt 라우팅 테이블로 연결
}

resource "aws_route_table_association" "pub_c" {
  subnet_id      = aws_subnet.public_subnet_c.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id           = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
}

resource "aws_route_table_association" "pri_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}