## EKS


### 클러스터 관리 준비 
- kubectl 설치 : https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/install-kubectl.html

```sh
$ curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.17.9/2020-08-04/bin/linux/amd64/kubectl

# PATH
$ chmod +x ./kubectl
$ mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
```

- eksctl 설치 : https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/eksctl.html
```sh
$ curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

$ sudo mv /tmp/eksctl /usr/local/bin

$ eksctl version
```	


### 클러스터 생성 via eksctl
- Cluster 정보 
```yaml
# vi eks-create.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: infra-eks-cdecl 
  region: ap-northeast-2 
vpc:
  id: "vpc-0c06bb4c4e3aea101"
  subnets:
    private:
      ap-northeast-2a:
        id: "subnet-0488fa9c1d7241e71"
      ap-northeast-2c:
        id: "subnet-00be6d5a6ba30bfb8"
  #cidr: "10.10.1.0/16" # 클러스터에서 사용할 VPC의 CIDR
nodeGroups:
  - name: infra-eks-cdecl-ng 
    instanceType: t3.medium
    desiredCapacity: 2
    volumeSize: 10  
    iam:
      withAddonPolicies:
        ImageBuilder: true 
        albIngress: true  
    ssh:
      allow: true 
      publicKeyName: infra-dev 
```

#### 클러스터 생성 
```sh
$ eksctl create cluster -f create-eks-cluster.yml 
```

#### 클러스터 삭제 
```sh
$ eksctl delete cluster -f create-eks-cluster.yml 
```

#### 기타 명령 
```sh
$ eksctl create cluster --name=infra-eks-cdecl --nodes=2 --node-ami=auto --region=ap-northeast-2
$ eksctl delete cluster --name=infra-eks-cdecl
```

### 클러스터 확인 
- kubectl config 설정 

```sh
# 정보 확인
$ aws sts get-caller-identity

# kubectl config 설정 
# aws eks --region region update-kubeconfig --name cluster-name
$ aws eks --region ap-northeast-2 update-kubeconfig --name infra-eks-cdecl 

$ kubectl get node
NAME                                               STATUS   ROLES    AGE   VERSION
ip-10-239-49-108.ap-northeast-2.compute.internal   Ready    <none>   21m   v1.17.9-eks-4c6976
ip-10-239-49-197.ap-northeast-2.compute.internal   Ready    <none>   21m   v1.17.9-eks-4c6976
```

- 서비스 테스트 
```sh
$ kubectl apply -f deploy//mvcapp-deploy-service.yaml

$ kubectl get svc
NAME         TYPE           CLUSTER-IP       EXTERNAL-IP                                                                   PORT(S)        AGE
kubernetes   ClusterIP      172.20.0.1       <none>                                                                        443/TCP        40m
mvcapp       LoadBalancer   172.20.118.131   xxxxxxxxxx6e04139ba42fb06701c329-xxxxx2588.ap-northeast-2.elb.amazonaws.com   80:31108/TCP   7m55s

```

### 기타
- 인스턴스 스펙 당 Pod 개수
	- https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt


