//This Terraform Template creates a Jenkins Server using JDK 11 on EC2 Instance.
//Jenkins Server is enabled with Git, Docker and Docker Compose,
//AWS CLI Version 2, Python 3, Ansible, Terraform and Boto3.
//Jenkins Server will run on Amazon Linux 2 EC2 Instance with
//custom security group allowing HTTP(80, 8080) and SSH (22) connections from anywhere.

provider "aws" {
  region = var.region
  //  access_key = ""
  //  secret_key = ""
  //  If you have entered your credentials in AWS CLI before, you do not need to use these arguments.
}

## JENKINS-SG ##
resource "aws_security_group" "jenkins-sec-gr" {
  name = var.jenkins_server_secgr
  tags = {
    Name = "jenkins-sg"
  }
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    protocol    = "tcp"
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
## JENKINS-ROLE-PROFILE ##
resource "aws_iam_role" "jenkins-server-role" {
  name               = "jenkins-server-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess", "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess", "arn:aws:iam::aws:policy/AdministratorAccess"]
}

resource "aws_iam_instance_profile" "jenkins-server-profile" {
  name = "jenkins-server-profile"
  role = aws_iam_role.jenkins-server-role.name
}

## JENKINS-SERVER ##
resource "aws_instance" "jenkins-server" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.mykey
  vpc_security_group_ids = [aws_security_group.jenkins-sec-gr.id]
  iam_instance_profile = aws_iam_instance_profile.jenkins-server-profile.name
  ebs_block_device {
    device_name = "/dev/xvda"
    volume_type = "gp2"
    volume_size = 16
  }
  tags = {
    Name = "jenkins-server"
  }
  connection {
    host = aws_instance.jenkins-server.public_ip
    type = "ssh"
    user = "ec2-user"
    private_key = file("${var.mykey}.pem")
    # Do not forget to define your key file path correctly!
  }
  provisioner "file" {
    source      = "./userdata"
    destination = "/tmp"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/userdata/jenkinsdata.sh",
      "/tmp/userdata/jenkinsdata.sh args",
      "sudo chmod +x /tmp/userdata/jenkins-script.sh",
      "/tmp/userdata/jenkins-script.sh args",
      "sudo cat /var/lib/jenkins/secrets/initialAdminPassword ",
      
    
      
    ]
  }
}


output "JenkinsDNS" {
  value = aws_instance.jenkins-server.public_dns
}

output "JenkinsURL" {
  value = "http://${aws_instance.jenkins-server.public_dns}:8080"
}
output "ssh_connection" {
  value ="ssh -i ${var.mykey}.pem ec2-user@${aws_instance.dev-server.public_ip}"
}
