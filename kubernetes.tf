# Single node kubernetes setup with kubeadm 

resource "random_pet" "cluster_name" {}

locals {
  cluster_name = var.cluster_name != null ? var.cluster_name : random_pet.cluster_name.id
  tags         = merge(var.tags, { "terraform-kubeadm:cluster" = local.cluster_name })
}

resource "aws_key_pair" "main" {
  key_name_prefix = "${local.cluster_name}-"
  public_key      = file(var.public_key_file)
  tags            = local.tags
}

#------------------------------------------------------------------------------#
# Security groups
#------------------------------------------------------------------------------#

# The AWS provider removes the default "allow all "egress rule from all security
# groups, so it has to be defined explicitly.
resource "aws_security_group" "egress" {
  name        = "${local.cluster_name}-egress"
  description = "Allow all outgoing traffic to everywhere"
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags
  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress_internal" {
  name        = "${local.cluster_name}-ingress-internal"
  description = "Allow all incoming traffic from nodes and Pods in the cluster"
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags
  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    self        = true
    description = "Allow incoming traffic from cluster nodes"

  }
  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = null
    description = "Allow incoming traffic from the Pods of the cluster"
  }
}

resource "aws_security_group" "ingress_k8s" {
  name        = "${local.cluster_name}-ingress-k8s"
  description = "Allow incoming Kubernetes API requests (TCP/6443) from outside the cluster"
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags
  ingress {
    protocol    = "tcp"
    from_port   = 6443
    to_port     = 6443
    cidr_blocks = var.allowed_k8s_cidr_blocks
  }
}

resource "aws_security_group" "ingress_ssh" {
  name        = "${local.cluster_name}-ingress-ssh"
  description = "Allow incoming SSH traffic (TCP/22) from outside the cluster"
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }
}

#------------------------------------------------------------------------------#
# Elastic IP for master node
#------------------------------------------------------------------------------#

# EIP for master node because it must know its public IP during initialisation
resource "aws_eip" "master" {
  vpc  = true
  tags = local.tags
}

resource "aws_eip_association" "master" {
  allocation_id = aws_eip.master.id
  instance_id   = aws_instance.master.id
}

#------------------------------------------------------------------------------#
# Bootstrap token for kubeadm
#------------------------------------------------------------------------------#

# Generate bootstrap token
# See https://kubernetes.io/docs/reference/access-authn-authz/bootstrap-tokens/
resource "random_string" "token_id" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "token_secret" {
  length  = 16
  special = false
  upper   = false
}

locals {
  token = "${random_string.token_id.result}.${random_string.token_secret.result}"
}


#------------------------------------------------------------------------------#
# EC2 instances
#------------------------------------------------------------------------------#

data "aws_ami" "ubuntu" {
  owners      = ["099720109477"] # AWS account ID of Canonical
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}

data "template_file" "script" {
  template = "${file("./templates/kubeadm-init.sh.tmpl")}"

  vars = {
    master_ip = "${aws_eip.master.public_ip}"
    token     = "${local.token}"
  }
}

data "template_file" "policy" {
  template = "${file("./templates/policy.json")}"
}

data "template_file" "assume_role" {
  template = "${file("./templates/assumerole.json")}"
}

resource "aws_iam_role" "role" {
  name = "k8s-master-role"

  assume_role_policy = "${data.template_file.assume_role.rendered}"
}

resource "aws_iam_policy" "policy" {
  name        = "k8s-master-policy"
  description = "A test policy"

  policy = "${data.template_file.policy.rendered}"
}

resource "aws_iam_role_policy_attachment" "k8s-master-role-attachment" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_instance_profile" "k8s-master" {
  name = "k8s-master"
  role = aws_iam_role.role.name
}

resource "aws_instance" "master" {
  ami                  = data.aws_ami.ubuntu.image_id
  instance_type        = var.master_instance_type
  subnet_id            = module.vpc.public_subnets[0]
  iam_instance_profile = "${aws_iam_instance_profile.k8s-master.name}"
  key_name             = aws_key_pair.main.key_name
  vpc_security_group_ids = [
    aws_security_group.egress.id,
    aws_security_group.ingress_internal.id,
    aws_security_group.ingress_k8s.id,
    aws_security_group.ingress_ssh.id
  ]
  root_block_device {
    volume_size = 30
  }

  tags      = merge(local.tags, { "terraform-kubeadm:node" = "master", "kubernetes.io/cluster/kubernetes" = "owned" })
  user_data = "${data.template_file.script.rendered}"
}

#------------------------------------------------------------------------------#
# Wait for bootstrap to finish on the master node
#------------------------------------------------------------------------------#

resource "null_resource" "wait_for_bootstrap_to_finish" {
  provisioner "local-exec" {
    command = <<-EOF
    alias ssh='ssh -q -i ${var.private_key_file} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    while true; do
      sleep 2
      ! ssh ubuntu@${aws_eip.master.public_ip} [[ -f /home/ubuntu/done ]] >/dev/null && continue
      break
    done
    EOF
  }
  triggers = {
    instance_ids = aws_instance.master.id
  }
}

#------------------------------------------------------------------------------#
# Download kubeconfig file from master node to local machine
#------------------------------------------------------------------------------#

locals {
  kubeconfig_file = "${abspath(pathexpand(var.kubeconfig_dir))}/${local.cluster_name}.conf"
}

resource "null_resource" "download_kubeconfig_file" {
  provisioner "local-exec" {
    command = <<-EOF
    alias scp='scp -q -i ${var.private_key_file} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    scp ubuntu@${aws_eip.master.public_ip}:/home/ubuntu/admin.conf ${local.kubeconfig_file} >/dev/null
    EOF
  }
  triggers = {
    wait_for_bootstrap_to_finish = null_resource.wait_for_bootstrap_to_finish.id
  }
}
