variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "private_key_file" {
  type        = string
  description = "Filename of the private key of a key pair on your local machine. This key pair will allow to connect to the nodes of the cluster with SSH."
  default     = "~/.ssh/id_rsa"
}

variable "public_key_file" {
  type        = string
  description = "Filename of the public key of a key pair on your local machine. This key pair will allow to connect to the nodes of the cluster with SSH."
  default     = "~/.ssh/id_rsa.pub"
}

variable "kubeconfig_dir" {
  type        = string
  description = "Directory on the local machine in which to save the kubeconfig file of the created cluster. The basename of the kubeconfig file will consist of the cluster name followed by \".conf\", for example, \"my-cluster.conf\". The directory may be specified as an absolute or relative path. The directory must exist, otherwise an error occurs. By default, the current working directory is used."
  default     = "."
}

variable "cluster_name" {
  type        = string
  description = "**This is an optional variable with a default value of null**. Name for the Kubernetes cluster. This name will be used as the value for the \"terraform-kubeadm:cluster\" tag that is assigned to all created AWS resources. If null, a random name is automatically chosen."
  default     = "kubeadm-single-node"
}

variable "allowed_ssh_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks from which it is allowed to make SSH connections to the EC2 instances that form the cluster nodes. By default, SSH connections are allowed from everywhere."
  default     = ["0.0.0.0/0"]
}

variable "allowed_k8s_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks from which it is allowed to make Kubernetes API request to the API server of the cluster. By default, Kubernetes API requests are allowed from everywhere. Note that Kubernetes API requests from Pods and nodes inside the cluster are always allowed, regardless of the value of this variable."
  default     = ["0.0.0.0/0"]
}

variable "master_instance_type" {
  type        = string
  description = "EC2 instance type for the master node (must have at least 2 CPUs)."
  default     = "t3.large"
}

variable "tags" {
  type        = map(string)
  description = "A set of tags to assign to the created AWS resources. These tags will be assigned in addition to the default tags. The default tags include \"terraform-kubeadm:cluster\" which is assigned to all resources and whose value is the cluster name, and \"terraform-kubeadm:node\" which is assigned to the EC2 instances and whose value is the name of the Kubernetes node that this EC2 corresponds to."
  default     = {}
}