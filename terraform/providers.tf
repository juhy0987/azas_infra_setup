terraform {
    required_version = "~>1.14.0"
    required_providers {
      aws = {
            source = "hashicorp/aws"
            version = "~> 6.0" 
      }
      cloudflare = {
            source  = "cloudflare/cloudflare"
            version = "~> 4.0"
      }
    }
}

# 1. Cloudflare 프로바이더 설정
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# 1. provider 설정
provider "aws" {
    region = "ap-northeast-2" # 서울
} 