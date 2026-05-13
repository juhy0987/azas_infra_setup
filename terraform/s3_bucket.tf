
resource "random_id" "bucket_suffix" {
    byte_length = 4
}

resource "aws_s3_bucket" "app_bucket" {
    bucket = "azas-backup-bucket-${random_id.bucket_suffix.hex}"
    tags   = { Name = "azas-s3" }
}

resource "aws_iam_role" "ec2_s3_role" {
    name = "azas-ec2-s3-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action    = "sts:AssumeRole"
            Effect    = "Allow"
            Principal = { Service = "ec2.amazonaws.com" }
        }]
    })
    tags = { Name = "azas-ec2-s3-role" }
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
    role       = aws_iam_role.ec2_s3_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
    name = "azas-ec2-instance-profile"
    role = aws_iam_role.ec2_s3_role.name
}

# 생성 버킷이름 local_file 로 넘김 (ansible에서 사용)
resource "local_file" "ansible_s3_vars" {
    filename = "${path.module}/../ansible/roles/pg_backup/vars/s3_vars.yml"
    content  = yamlencode({
        s3_bucket_name = aws_s3_bucket.app_bucket.id
    })
}