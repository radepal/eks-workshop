 ### Install 
 sudo curl -s --location -o /usr/local/bin/kubectl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
sudo yum -y install jq gettext
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

sudo mv -v /tmp/eksctl /usr/local/bin

sudo curl -s --location -o  /usr/local/bin/aws-iam-authenticator -LO https://amazon-eks.s3-us-west-2.amazonaws.com/1.13.7/2019-06-11/bin/linux/amd64/aws-iam-authenticator
sudo chmod +x /usr/local/bin/aws-iam-authenticator

### Credencials

rm -vf ${HOME}/.aws/credentials

export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

echo "export ACCOUNT_ID=${ACCOUNT_ID}" >> ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" >> ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region
aws sts get-caller-identity

### EKS 

cat <<EoF > ~/environment/cluster.yaml
# An example of ClusterConfig object using an existing VPC:
--- 
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: eksworkshop
  region: eu-west-1
  version: 1.13

vpc:
  id: "vpc-0GGG"  # (optional, must match VPC ID used for each subnet below)
  subnets:
    private:
      eu-west-1a:
        id: "subnet-XXX51fa923"

      eu-west-1b:
        id: "subnet-09aDDDf9004f"

      eu-west-1c:
        id: "subnet-0e67c5cdbcFFF"

nodeGroups:
  - name: ng-1
    instanceType: t3.medium
    desiredCapacity: 3

EoF

export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

eksctl create cluster  -f cluster.yaml

aws eks update-kubeconfig --name  eksworkshop

### Dashboard

https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml
kubectl proxy --port=8080 --address='0.0.0.0' --disable-filter=true &

/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

aws eks get-token --cluster-name eksworkshop | jq -r '.status.token'


#HELM
cd ~/environment

curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh

chmod +x get_helm.sh

./get_helm.sh


cat <<EoF > ~/environment/rbac.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EoF

kubectl apply -f ~/environment/rbac.yaml
helm init --service-account tiller

### Jenkins

helm install stable/jenkins --set rbac.create=true --name cicd
kubectl get pods -w
export SERVICE_IP=$(kubectl get svc --namespace default cicd-jenkins --template "{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}")
echo http://$SERVICE_IP:8080/login
printf $(kubectl get secret --namespace default cicd-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
