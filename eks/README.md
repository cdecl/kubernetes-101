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

---

### Ingress 설치 
https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/alb-ingress.html

#### 1. VPC의 서브넷에 태그를 지정, ALB 수신 컨트롤러 사용 알림
#### 2. IAM OIDC 공급자를 생성하고 클러스터에 연결
- 실패시 `IAMFullAccess` Role 추가 

```sh
$ eksctl utils associate-iam-oidc-provider 
  --region ap-northeast-2 \
  --cluster infra-eks-cdecl 
  --approve
```

#### 3. `ALBIngressControllerIAMPolicy` 정책 생성 
```sh
$ curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.8/docs/examples/iam-policy.json

$ aws iam create-policy 
    --policy-name ALBIngressControllerIAMPolicy \
    --policy-document file://iam-policy.json
```

#### 4. rbac-role 추가  
```sh
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.8/docs/examples/rbac-role.yaml
```

#### 5. ALB 수신 컨트롤러에 대한 IAM 역할을 생성

```sh
$ eksctl create iamserviceaccount \
    --region ap-northeast-2 \
    --name alb-ingress-controller \
    --namespace kube-system \
    --cluster infra-eks-cdecl \
    --attach-policy-arn arn:aws:iam::xxxxxxxxxx47:policy/ALBIngressControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --approve
```

#### 6. Ingress ALB 수신 컨트롤러 배포 
```sh 
# kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.8/docs/examples/alb-ingress-controller.yaml
$ curl -O kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.8/docs/examples/alb-ingress-controller.yaml

# 파일내 수정 
# REQUIRED
  # Name of your cluster. Used when naming resources created
  # by the ALB Ingress Controller, providing distinction between
  # clusters.
  # - --cluster-name=devCluster
  - --cluster-name=infra-eks-cdecl

# ingress-controller 생성 
$ kubectl apply -f alb-ingress-controller.yaml

# ingress-controller 확인
$ kubectl get pods -n kube-system
NAME                                     READY   STATUS    RESTARTS   AGE
alb-ingress-controller-8b8f79bb7-t5mwg   1/1     Running   0          10s
aws-node-p8ppq                           1/1     Running   0          27h
aws-node-qpg95                           1/1     Running   0          27h
coredns-7dd7f84d9-bc4rd                  1/1     Running   0          28h
coredns-7dd7f84d9-hntpx                  1/1     Running   0          28h
kube-proxy-9kfz9                         1/1     Running   0          27h
kube-proxy-fr4xt                         1/1     Running   0          27h
```

#### 7. 서비스 Deploy/Service 적용 
- 서비스 타입 `NodePort` 구성 
  - `LoadBalancer` 서비스 별 CBL 생성  

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mvcapp
spec:
  type: NodePort
  #type: LoadBalancer
  selector:
    app: mvcapp
  ports:
  - port: 80
    targetPort: 80
```

#### 8. Ingress 리소스 적용 
- ALB 사용 Annotations 추가  

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: eks-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    #alb.ingress.kubernetes.io/target-type: ip  # ip, instance
    alb.ingress.kubernetes.io/scheme: internet-facing # internal, internet-facing
spec:
  rules:
  - host: mvcapp.cdecl.net     
    http:
      paths:               
      - backend:           
          serviceName: mvcapp
          servicePort: 80
```

```sh
$ kubectl apply -f ingress-rule-aws.yml

# 1분내 Adreess 할당 
$ kubectl get ing
NAME          HOSTS              ADDRESS   PORTS   AGE
eks-ingress   mvcapp.cdecl.net             80      4s

$ kubectl get ing
NAME          HOSTS              ADDRESS                                                                       PORTS   AGE
eks-ingress   mvcapp.cdecl.net   xxxxxxxx-default-eksingres-ea83-2001898420.ap-northeast-2.elb.amazonaws.com   80      21s

$ curl xxxxxxxx-default-eksingres-ea83-2001898420.ap-northeast-2.elb.amazonaws.com -H 'Host: mvcapp.cdecl.net'
```

---

### 기타
- 인스턴스 스펙 당 Pod 개수
	- https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt


