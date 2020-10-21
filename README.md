## Kubernetes 설정 

### 사전 준비 
#### ○ Kubernetes 설치 전 서버 구성 변경 
- Swap 영역을 비활성화 

```sh
# 일시적인 설정 
sudo swapoff -a

# 영구적인 설정 
# 아래 swap 파일 시스템을 주석처리 
sudo vi /etc/fstab

# /dev/mapper/kube--master--vg-swap_1 none            swap    sw              0       0
```

- SELinux Disable
```sh
# 임시 
sudo setenforce 0

# 영구
sudo vi /etc/sysconfig/selinux

SELinux=disabled  
```

-  방화벽 Disable
```
sudo systemctl disable firewalld
sudo systemctl stop firewalld
```

- 브릿지 네트워크 할성화 

```sh
# Centos
/etc/sysctl.d/k8s.conf

net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
```

```sh
# Ubuntu
sudo vi /etc/ufw/sysctl.conf

net/bridge/bridge-nf-call-ip6tables = 1
net/bridge/bridge-nf-call-iptables = 1
net/bridge/bridge-nf-call-arptables = 1

```

- 참고 : https://www.mirantis.com/blog/how-install-kubernetes-kubeadm/

---

### 설치 및 설정

#### ○ Kubernetes 설치 : Centos7 기준
- Kubernetes 버전에 맞는 Docker 버전을 확인해야 함 
- Docker 설치 
```sh
sudo yum install -y docker
sudo systemctl enable docker && systemctl start docker

sudo usermod -aG docker $USER
```

- kubeadm, kubelet, kubectl : Repo 추가 및 패키지 설치
```sh
$ cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

$ sudo yum install -y kubelet kubeadm kubectl

$ sudo systemctl enable kubelet && systemctl start kubelet

# 버전이 안맞을 경우 지정 
# sudo yum install kubelet-[version] kubeadm-[version] kubectl-[version]
```

- kubectl 자동완성
```
# sh
source <(kubectl completion sh)
echo "source <(kubectl completion sh)" >> ~/.shrc 

# zsh
source <(kubectl completion zsh) 
echo "if [ $commands[kubectl] ]; then source <(kubectl completion zsh); fi" >> ~/.zshrc 
```


- 설치 참고 : [Installing kubeadm](https://kubernetes.io/docs/setup/independent/install-kubeadm/) 

#### ○ Master 초기화 : Kubernetes 의 Master 노드를 초기화 
- Kubernetes의 Master를 초기화 하려면 뒤에 설치할 Overlay network에 따른 옵션이 필요
- Overlay network으로는 flannel 사용 
	- 옵션에 네트워크 클래스 대역을 설정 필요 : `--pod-network-cidr 10.244.0.0/16`
- Master 초기화
```sh
sudo kubeadm init --pod-network-cidr 10.244.0.0/16
```

- Master 초기화 이후 아래의 메세지 출력 
	- mkdir로 시작하는 3줄 명령어는 kubectl 를 사용하기 위한 config 설정이므로 그대로 실행 
	- 초기화를 한번이라도 했따면 2번째 cp 명령만 실행 해도 됨
	- 마지막 `kubeadm join` 명령은 Master가 아닌 Worker Node 에서 Master 에 Join 하는 명령어 `나중에 실행 해야하므로 보관`
	
```sh
[init] Using Kubernetes version: v1.10.5
...
...

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

...

You can now join any number of machines by running the following on each node
as root:
  kubeadm join 192.168.28.15:6443 --token 1ovd36.ft4mefr909iotg0a --discovery-token-ca-cert-hash sha256:82953a3ed178aa8c511792d0e21d9d3283e7575f3d3350a00bea3e34c2b87d29 
```

- 초기화 이후 Pod 의 상태 확인하면 coredns 서비스가 Pending 상태 :
  - Overlay network 설치 후 정상 
```sh
$ kubectl get po -A
NAMESPACE     NAME                            READY   STATUS    RESTARTS   AGE
kube-system   coredns-66bff467f8-ktvsz        0/1     Pending   0          19s
kube-system   coredns-66bff467f8-nvvjz        0/1     Pending   0          19s
kube-system   etcd-node1                      1/1     Running   0          29s
kube-system   kube-apiserver-node1            1/1     Running   0          29s
kube-system   kube-controller-manager-node1   1/1     Running   0          29s
kube-system   kube-proxy-s582x                1/1     Running   0          19s
kube-system   kube-scheduler-node1            1/1     Running   0          29s
```

#### ○ Overlay network : Calico 설치
- Kubernetes의 클러스터를 관리하기 위한 오버레이 네트워크 설치 
- Overlay network 종류 
  - https://kubernetes.io/docs/concepts/cluster-administration/networking/
- Install Calico for on-premises deployments
  - https://docs.projectcalico.org/getting-started/kubernetes/self-managed-onprem/onpremises

```sh
# Install Calico for on-premises deployments
$ kubectl apply -f https://docs.projectcalico.org/manifests/calico-typha.yaml
```

- 설치 이후 Pod 의 상태 확인하면 coredns 서비스가 정상적으로 Running 

```sh
$ kubectl get po -A
NAMESPACE     NAME                                       READY   STATUS             RESTARTS   AGE
kube-system   calico-kube-controllers-799fb94867-bcntz   0/1     CrashLoopBackOff   3          2m6s
kube-system   calico-node-jtcmt                          0/1     Running            1          2m7s
kube-system   calico-typha-6bc9dd6468-x2hjj              0/1     Pending            0          2m6s
kube-system   coredns-66bff467f8-ktvsz                   0/1     Running            0          3m23s
kube-system   coredns-66bff467f8-nvvjz                   0/1     Running            0          3m23s
kube-system   etcd-node1                                 1/1     Running            0          3m33s
kube-system   kube-apiserver-node1                       1/1     Running            0          3m33s
kube-system   kube-controller-manager-node1              1/1     Running            0          3m33s
kube-system   kube-proxy-s582x                           1/1     Running            0          3m23s
kube-system   kube-scheduler-node1                       1/1     Running            0          3m33s

```

#### ○ Worker Node 추가(Join) 
- Master가 아닌 다른 머신에서 실행 

```sh
# Join 명령 가져오기 
$ kubeadm token create --print-join-command
kubeadm join 192.168.28.15:6443 --token 1ovd36.ft4mefr909iotg0a     --discovery-token-ca-cert-hash sha256:82953a3ed178aa8c511792d0e21d9d3283e7575f3d3350a00bea3e34c2b87d29 

# Worker node 에서 실행 
$ kubeadm join 192.168.28.15:6443 --token 1ovd36.ft4mefr909iotg0a --discovery-token-ca-cert-hash sha256:82953a3ed178aa8c511792d0e21d9d3283e7575f3d3350a00bea3e34c2b87d29 
```

- 노드 상태 확인
```
> kubectl get node
NAME    STATUS   ROLES    AGE     VERSION
node1   Ready    master   8m50s   v1.18.6
node2   Ready    <none>   16s     v1.18.6
node3   Ready    <none>   16s     v1.18.6
```

---
### 서비스 배포 : 명령어 기반 

#### ○ 배포 / 서비스 추가 
- Docker 이미지를 빌드하여 Docker Hub에 업로드 : 서비스에는 Private Hub 구성 필요 
	- run 명령으로 Pod, Deployment 생성 
	- expose 명령으로 Deployment 기준으로 서비스 생성 
  - [Kubernetes NodePort vs LoadBalancer vs Ingress? When should I use what?](https://medium.com/google-cloud/kubernetes-nodeport-vs-loadbalancer-vs-ingress-when-should-i-use-what-922f010849e0)


```sh
# pod 및 배포(deployment) 생성 
$ kubectl create deployment mvcapp --image=cdecl/mvcapp:0.3
deployment.apps/mvcapp created

# 서비스 생성 
$ kubectl expose deploy/mvcapp --type=NodePort --port=80 --name=mvcapp --target-port=80
service/mvcapp exposed
```

```sh
$ kubectl get deploy
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
mvcapp   1/1     1            1           24s

$ kubectl get po
NAME                      READY   STATUS    RESTARTS   AGE
mvcapp-7b6b66bd55-g26wg   1/1     Running   0          34s

$ kubectl get svc
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
mvcapp       NodePort    10.107.145.24   <none>        80:31521/TCP   20s


# 서비스 확인 - Nodeport 
$ curl localhost:31521
...
    <div>Project: Mvcapp</div>
    <div>Hostname: mvcapp-7b6b66bd55-g26wg</div>
    <div>Request Count : 1</div>
    <div>Version: 0.3</div>
...
```

#### ○ Scale / 이미지 변경(배포)

- Scale(노드개수) 조정 

```sh 
$ kubectl scale deployment/mvcapp --replicas=4
deployment.apps/mvcapp scaled

$ kubectl get pod -o wide
NAME                      READY   STATUS    RESTARTS   AGE     IP             NODE    NOMINATED NODE   READINESS GATES
mvcapp-7b6b66bd55-4gppf   1/1     Running   0          78s     10.244.135.3   node3   <none>           <none>
mvcapp-7b6b66bd55-4gssq   1/1     Running   0          78s     10.244.104.4   node2   <none>           <none>
mvcapp-7b6b66bd55-4lqrt   1/1     Running   0          78s     10.244.135.2   node3   <none>           <none>
mvcapp-7b6b66bd55-g26wg   1/1     Running   0          7m14s   10.244.104.3   node2   <none>           <none>
```

- 이미지 변경 (버전업 배포) : 0.3 → 0.4 

```sh
$ kubectl set image deployment/mvcapp mvcapp=cdecl/mvcapp:0.4
deployment.apps/mvcapp image updated
```

```sh
$  curl localhost:31521
...
    <div>Project: Mvcapp</div>
    <div>Hostname: mvcapp-78bbf7db4b-5fkdz</div>
    <div>RemoteAddr: 10.244.166.128</div>
    <div>X-Forwarded-For: </div>
    <div>Request Count : 1</div>
    <div>Version: 0.4</div>
...
``` 

```sh
$ kubectl rollout history deployment/mvcapp
deployment.apps/mvcapp 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

- 이전 버전으로 롤백 
```sh
$ kubectl rollout undo deployment/mvcapp
deployment.apps/mvcapp rolled back
```

---
### 서비스 배포 :  yaml 파일 기반 

#### ○ 배포 / 서비스 추가  
- 정책을 정의한 yaml 기반 정의 
- NodePort 기반의 Deployment 및 서비스 정의 

```yaml
# mvcapp-deploy-service.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: mvcapp
spec:
  selector:
    matchLabels:
      app: mvcapp
  replicas: 2 # --replicas=2 옵션과 동일 
  template: # create pods using pod definition 
    metadata:
      labels:
        app: mvcapp
    spec:
      containers:
      - name: mvcapp
        image: cdecl/mvcapp:0.3
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: mvcapp
spec:
  type: NodePort
  selector:
    app: mvcapp
  ports:
  - port: 80
    targetPort: 80

```

- yaml 파일 적용 

```sh

# yaml 파일 적용(생성)
kubectl create -f mvcapp-deploy-service.yaml

# yaml 파일 갱신 
# 파일 수정 후, apply 를 하게 되면  set image, replicas 등과 같이 정책 변경이 가능함 
kubectl apply -f mvcapp-deploy-service.yaml
``` 

```sh

> kubectl apply -f mvcapp-deploy-service.yaml
deployment.apps "mvcapp" created
service "mvcapp" created

```

---
### 서비스 노출 (Bare Metal 환경) 
- https://kubernetes.github.io/ingress-nginx/deploy/baremetal/


#### ○ Cloud (AWS)
- type: LoadBalancer : 서비스 타입을 LoadBalancer 지정하면 EXTERNAL-IP 자동으로 할당 
- Ingress 활용 : annotations 을 통해 alb 할당

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

#### ○ MetalLB 활용 - Bare Metal 환경 
![](https://kubernetes.github.io/ingress-nginx/images/baremetal/metallb.jpg)

- 설치 : https://metallb.universe.tf/installation/#installation-by-manifest
```sh
$ kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
$ kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml

# On first install only
$ kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```

- ConfigMap
```yml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.28.100-192.168.28.103   
```

- 서비스의 type: LoadBalancer 지정하면 addresses 범위 내 할당 (지정가능: loadBalancerIP)
```yml
apiVersion: v1
kind: Service
metadata:
  name: mvcapp
spec:
  type: LoadBalancer
  #loadBalancerIP: 192.168.28.100
  selector:
    app: mvcapp
  ports:
  - port: 80
    targetPort: 80
```

```sh
$ curl 192.168.28.100
```

#### ○ Over a NodePort Service
![](https://kubernetes.github.io/ingress-nginx/images/baremetal/nodeport.jpg)

- Nodeport 에서 자동으로 할당한 30000 over port 활용 
  - mvcapp       NodePort    10.107.145.24   <none>        80:**30010**/TCP   26m

```yml
apiVersion: v1
kind: Service
metadata:
  name: mvcapp
spec:
  type: NodePort
  selector:
    app: mvcapp
  ports:
  - port: 80
    targetPort: 80
    # nodePort: 30010  # 포트 임의지정 
```

```sh
# Master 및 Worker IP 
$ curl localhost:30010
$ curl 192.168.28.16:30010
```

- externalIPs 사용 : 일반적으로 권고하지 않음 
```yml
spec:
  externalIPs:
  - 192.168.28.15
  - 192.168.28.16
  - 192.168.28.17
```

```sh
$ netstat -an | grep 'LISTEN '
...
tcp        0      0 192.168.28.15:80        0.0.0.0:*               LISTEN 
...
```

---

#### ○ Ingress controller 
- 외부 서비스 접속을 위한 도메인, URL 기반 서비스 분기 역할 `L7 레이어 기능`
- RBAC 기반 설치 : 역할 기반 접근 제어(role-based access control)
- 그중 가장 많이 활성화 된 nginx 기반 Ingress 컨트롤러 이용 
- ingress-nginx repository : https://github.com/kubernetes/ingress-nginx
  - Installation Guide : https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md

```sh
# Bare-metal Using NodePort:
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/deploy.yaml

namespace/ingress-nginx created
serviceaccount/ingress-nginx created
configmap/ingress-nginx-controller created
clusterrole.rbac.authorization.k8s.io/ingress-nginx created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx created
role.rbac.authorization.k8s.io/ingress-nginx created
rolebinding.rbac.authorization.k8s.io/ingress-nginx created
service/ingress-nginx-controller-admission created
service/ingress-nginx-controller created
deployment.apps/ingress-nginx-controller created
validatingwebhookconfiguration.admissionregistration.k8s.io/ingress-nginx-admission created
serviceaccount/ingress-nginx-admission created
clusterrole.rbac.authorization.k8s.io/ingress-nginx-admission created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
role.rbac.authorization.k8s.io/ingress-nginx-admission created
rolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
job.batch/ingress-nginx-admission-create created
job.batch/ingress-nginx-admission-patch created
```

- Ingress Rule 적용 
```yml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: main-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
#  - host: mvcapp.cdecl.net     
   - http:
      paths:               
      - backend:           
          serviceName: mvcapp
          servicePort: 80
```

- Ingress 확인
```sh
$ kubectl get ing 
NAME           CLASS    HOSTS   ADDRESS         PORTS   AGE
main-ingress   <none>   *       192.168.28.16   80      25s
```

#### Ingress : MetalLB
- Ingress 서비스를 type: LoadBalancer 으로 설정 → MetalLB

#### Ingress : NodePort Port 
- ingress-nginx ingress-nginx-controller NodePort 10.111.152.85 <none> 80:**32293**/TCP,443:**32325**/TCP   3m56s
```
$ kubectl get svc -A
NAMESPACE       NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
...
default         mvcapp                               NodePort    10.106.102.27   <none>        80:30010/TCP                 5m6s
ingress-nginx   ingress-nginx-controller             NodePort    10.111.152.85   <none>        80:32293/TCP,443:32325/TCP   3m56s
...
```

#### Ingress : Via the host network
![](https://kubernetes.github.io/ingress-nginx/images/baremetal/hostnetwork.jpg)
- Deploy hostNetwork: true 설정  
  - Ingress Bind IP 만 설정됨 (Not DaemonSet)

```yaml
kind: Deployment
spec:
...
  template:
...
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirst
      containers:
        - name: controller
          image: k8s.gcr.io/ingress-nginx/controller:v0.40.2@sha256:46ba23c3fbaafd9e5bd01ea85b2f921d9f2217be082580edc22e6c704a83f02f
...
```

```sh
$ kubectl get ing -A
NAMESPACE   NAME           CLASS    HOSTS   ADDRESS         PORTS   AGE
default     main-ingress   <none>   *       192.168.28.16   80      76m

$ ansible all -m shell -a "netstat -an | grep 'LISTEN ' | grep ':80' "
node2 | CHANGED | rc=0 >>
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN     
tcp6       0      0 :::80                   :::*                    LISTEN     
node3 | FAILED | rc=1 >>
non-zero return code
node1 | FAILED | rc=1 >>
non-zero return code
```

#### Ingress : External IPs
- This method does not allow preserving the source IP of HTTP requests in any manner, it is therefore not recommended to use it despite its apparent simplicity.
- 일반적으로 권고하지 않음 

```yaml
# Source: ingress-nginx/templates/controller-service.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    helm.sh/chart: ingress-nginx-3.6.0
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/version: 0.40.2
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/component: controller
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  type: NodePort
  ports:
    - name: http
      port: 80
      protocol: TCP
      targetPort: http
    - name: https
      port: 443
      protocol: TCP
      targetPort: https
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/component: controller
  externalIPs:
    - 192.168.28.15
    - 192.168.28.16
    - 192.168.28.17
``` 

```sh
$ kubectl get svc -A
...
NAMESPACE       NAME                                 TYPE        CLUSTER-IP       EXTERNAL-IP                                 PORT(S)                      AGE
default         mvcapp                               NodePort    10.106.102.27    <none>                                      80:30010/TCP                 59m
ingress-nginx   ingress-nginx-controller             NodePort    10.109.74.44     192.168.28.15,192.168.28.16,192.168.28.17   80:32464/TCP,443:31106/TCP   4m29s
...
```

```sh
$ ansible all -m shell -a "netstat -an | grep 'LISTEN ' | grep ':80' "
node3 | CHANGED | rc=0 >>
tcp        0      0 192.168.28.17:80        0.0.0.0:*               LISTEN     
node1 | CHANGED | rc=0 >>
tcp        0      0 192.168.28.15:80        0.0.0.0:*               LISTEN     
node2 | CHANGED | rc=0 >>
tcp        0      0 192.168.28.16:80        0.0.0.0:*               LISTEN     
```

---

### Kubernetes 초기화 
```
sudo kubeadm reset -f
```

---

### 추가작업 
- Master Node 고가용성 확보 : 3대 NODE 구성
- 버전 업그레이드 방법 
 
