data "template_file" "user-data" {
  count    = "${length(var.hostnames)}"
  template = "${file("${element(var.hostnames, count.index)}")}"
}


# Resource-1: Create EC2 Instance
resource "aws_instance" "VIJAY-TERRAFORM" {
  count                       = var.instance_count
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.my-public-subnet.id
  vpc_security_group_ids      = [aws_security_group.public-SG.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.vijay_profile.name

  user_data                   = "${element(data.template_file.user-data.*.rendered, count.index)}"

  tags = {
    "Name"  = "Terraform-${count.index + 1}"
  }

}

resource "aws_ssm_parameter" "private_ips" {
 name        = "/Test/private-ip"
 description = "private ips"
 type        = "StringList"
 value       = join(",", aws_instance.VIJAY-TERRAFORM.*.private_ip)

 tags = {
   environment = "Testing-private"
 }
 depends_on = [
   aws_instance.VIJAY-TERRAFORM
 ]
}

resource "aws_ssm_parameter" "public_ips" {
 name        = "/Test/public-ip"
 description = "public ips"
 type        = "StringList"
 value       = join(",", aws_instance.VIJAY-TERRAFORM.*.public_ip)

 tags = {
   environment = "Testing-public"
 }
 depends_on = [
   aws_instance.VIJAY-TERRAFORM
 ]
}

resource "aws_ssm_parameter" "kafka-url" {
 count       = var.instance_count
 name        = "/Test/kafka${count.index + 1}/url"
 description = "public ips"
 type        = "StringList"
 value       = "kafka${count.index + 1}.vijay4devops.co"

 tags = {
   environment = "Kafka-public-url"
 }
 depends_on = [
   aws_instance.VIJAY-TERRAFORM
 ]
}

resource "aws_ssm_parameter" "zk-url" {
 count       = var.instance_count
 name        = "/Test/zk${count.index + 1}/url"
 description = "public ips"
 type        = "StringList"
 value       = "zk${count.index + 1}.vijay4devops.co"

 tags = {
   environment = "zk-public-url"
 }
 depends_on = [
   aws_instance.VIJAY-TERRAFORM
 ]
}


resource "aws_route53_record" "kafka-record" {

  count = length(aws_instance.VIJAY-TERRAFORM)

  zone_id = var.public_hosted_zone_id
  name    = "kafka${count.index + 1}.vijay4devops.co"
  type    = "A"
  ttl     = "300"

  records = [aws_instance.VIJAY-TERRAFORM[count.index].private_ip]
}

resource "aws_route53_record" "zk-record" {

  count = length(aws_instance.VIJAY-TERRAFORM)

  zone_id = var.public_hosted_zone_id
  name    = "zk${count.index + 1}.vijay4devops.co"
  type    = "A"
  ttl     = "300"

  records = [aws_instance.VIJAY-TERRAFORM[count.index].private_ip]
}

resource "null_resource" "local_provisioners1" {
  count = "${var.instance_count}"
  depends_on = [
   aws_ssm_parameter.private_ips
 ]
  provisioner "local-exec" {
    command = "echo ${element(aws_instance.VIJAY-TERRAFORM.*.private_ip, count.index)} >> hosts.private"
  }
}


resource "null_resource" "local_provisioners2" {
  count = "${var.instance_count}"
  depends_on = [
   aws_ssm_parameter.public_ips
 ]
  provisioner "local-exec" {
    command = "echo ${element(aws_instance.VIJAY-TERRAFORM.*.public_ip, count.index)} >> hosts.public"
  }
}

resource "null_resource" "ca_certs" {

 provisioner "local-exec" {
    command = "/bin/bash local-ca-upload-to-ssm.sh"
  }
}
