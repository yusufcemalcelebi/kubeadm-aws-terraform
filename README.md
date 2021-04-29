# kubeadm-aws-terraform

- This repository includes terraform files and required configuration files to create the AWS Networking components and a kubernetes cluster with kubeadm.   
- Additionally, jenkins configuration files are added to create a Jenkins instance on k8s.   

To create the all components:   

```bash   
# when successfully provisioned, terraform will download the KUBECONFIG file to access to the k8s cluster   
terraform apply -auto-approve   

# install Jenkins   
helm upgrade -i my-release jenkins/jenkins -f ./jenkins/jenkins-values.yml   

# create a service account with the required capabilities to run a Jenkins agent during the job   
kubectl apply -f ./jenkins/agent-sa.yml   

```   

## Configuration Files  
jenkins/agent.dockerfile -> This dockerfile provides image for our jenkins agents   
jenkins/agent.yml -> Example agent yml, to use with Jenkins Kubernetes plugin   
templates/kubeadm-init.sh.tmpl -> k8s setup script with kubeadm   
templates/policy.json -> policy for our k8s master node 
templates/assumerole.json -> assumerole file

