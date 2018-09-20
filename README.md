## Kubernetes 설정 

### 사전 준비 
#### ■ Kubernetes 설치 전 서버 구성 변경 
- Swap 영역을 비활성화 

```bash
# 일시적인 설정 
swapoff -a

# 영구적인 설정 
# 아래 swap 파일 시스템을 주석처리 
vi /etc/fstab

# /dev/mapper/kube--master--vg-swap_1 none            swap    sw              0       0
```

- SELinux, 방화벽 Disable
```bash
setenforce 0
systemctl disable firewalld
systemctl stop firewalld
```

- 브릿지 네트워크 할성화 

```bash
# Centos
/etc/sysctl.d/k8s.conf

net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
```

```bash
# Ubuntu
vi /etc/ufw/sysctl.conf

net/bridge/bridge-nf-call-ip6tables = 1
net/bridge/bridge-nf-call-iptables = 1
net/bridge/bridge-nf-call-arptables = 1

```

- 참고 : https://www.mirantis.com/blog/how-install-kubernetes-kubeadm/

---

### 설치 및 설정

#### ■ Kubernetes 설치 : Centos7 기준
- Kubernetes 버전에 맞는 Docker 버전을 확인해야 함 
- Docker 설치 
```bash
yum install -y docker
systemctl enable docker && systemctl start docker
```

- kubeadm, kubelet, kubectl : Repo 추가 및 패키지 설치
```bash
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF


yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable kubelet && systemctl start kubelet
```

- 설치 참고 : [Installing kubeadm](https://kubernetes.io/docs/setup/independent/install-kubeadm/) 

#### ■ Master 초기화 : Kubernetes 의 Master 노드를 초기화 
- Kubernetes의 Master를 초기화 하려면 뒤에 설치할 Overlay network에 따른 옵션이 필요
- Overlay network으로는 flannel 사용 
	- 옵션에 네트워크 클래스 대역을 설정 필요 : `--pod-network-cidr 10.244.0.0/16`
- Master 초기화
```bash
sudo kubeadm init --pod-network-cidr 10.244.0.0/16
```

- Master 초기화 이후 아래의 메세지 출력 
	- mkdir로 시작하는 3줄 명령어는 kubectl 를 사용하기 위한 config 설정이므로 그대로 실행 
	- 초기화를 한번이라도 했따면 2번째 cp 명령만 실행 해도 됨
	- 마지막 `kubeadm join` 명령은 Master가 아닌 Worker Node 에서 Master 에 Join 하는 명령어 `나중에 실행 해야하므로 보관`
	
```bash
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

  kubeadm join 192.168.137.20:6443 --token u1gxuf.b3us1m1998y3iwpc --discovery-token-ca-cert-hash sha256:540e45eebb85ca0a31f9002dde8180be37f3ccd3959ef444d40929394e1eeb3c

```

- 초기화 이후 Pod 의 상태 확인하면 dns 서비스가 Pending 상태

```
> kubectl get pod --all-namespaces
NAMESPACE     NAME                                  READY     STATUS    RESTARTS   AGE
kube-system   etcd-kube-master                      1/1       Running   0          4m
kube-system   kube-apiserver-kube-master            1/1       Running   0          4m
kube-system   kube-controller-manager-kube-master   1/1       Running   0          4m
kube-system   kube-dns-86f4d74b45-hc7wc             0/3       Pending   0          4m
kube-system   kube-proxy-6m8bw                      1/1       Running   0          4m
kube-system   kube-scheduler-kube-master            1/1       Running   0          5m
```

#### ■ Overlay network : flannel 설치
- Kubernetes의 클러스터를 관리하기 위한 오버레이 네트워크 설치 
- Overlay network 종류 : https://kubernetes.io/docs/concepts/cluster-administration/networking/
	- 개인적으로 weave-net 의 예제가 많았는데 뭔가 잘 되지 않았음 

```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

- 설치 이후 Pod 의 상태 확인하면 dns 서비스가 정상적으로 Running 

```bash
NAMESPACE     NAME                                  READY     STATUS    RESTARTS   AGE
kube-system   etcd-kube-master                      1/1       Running   0          37s
kube-system   kube-apiserver-kube-master            1/1       Running   0          37s
kube-system   kube-controller-manager-kube-master   1/1       Running   0          37s
kube-system   kube-dns-86f4d74b45-hc7wc             2/3       Running   0          1h
kube-system   kube-flannel-ds-amd64-f2ln5           1/1       Running   0          41s
kube-system   kube-proxy-6m8bw                      1/1       Running   0          1h
kube-system   kube-scheduler-kube-master            1/1       Running   0          36s
```

#### ■ Worker Node 추가(Join) 
- Master가 아닌 다른 머신에서 실행 

```bash
kubeadm join 192.168.137.20:6443 --token u1gxuf.b3us1m1998y3iwpc --discovery-token-ca-cert-hash sha256:540e45eebb85ca0a31f9002dde8180be37f3ccd3959ef444d40929394e1eeb3c
```

- 노드 상태 확인 (2개 노드)
```
> kubectl get node
NAME          STATUS    ROLES     AGE       VERSION
kube-master   Ready     master    1h        v1.10.3
kube-node01   Ready     <none>    4m        v1.10.3
kube-node02   Ready     <none>    4m        v1.10.3
```

---
### 서비스 배포 : 명령어 기반 

#### ■ 배포 / 서비스 추가 
- Docker 이미지를 빌드하여 Docker Hub에 업로드 : 서비스에는 Private Hub 구성 필요 
	- run 명령으로 Pod, Deployment 생성 
	- expose 명령으로 Deployment 기준으로 서비스 생성 
  - [Kubernetes NodePort vs LoadBalancer vs Ingress? When should I use what?](https://medium.com/google-cloud/kubernetes-nodeport-vs-loadbalancer-vs-ingress-when-should-i-use-what-922f010849e0)


```bash
# pod 및 배포(deployment) 생성 
kubectl run mvc --image=cdecl/mvcapp:0.1
# 서비스 생성 
kubectl expose deployment/mvc --type=NodePort --port=80 --name=mvc --target-port=80
```

```bash
> kubectl get pod
NAME                   READY     STATUS    RESTARTS   AGE
mvc-56b94948b9-qdpql   1/1       Running   0          22s

> kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP        1h
mvc          NodePort    10.107.73.137   <none>        80:32074/TCP   14s

# 서비스 확인 : NodePort 
> curl 10.107.73.137
<html>
    <head>

    </head>
    <body>
        Title : Home Page <br/>
        cdecl called 1 <br/>
        MachineName: mvc-56b94948b9-n5nj6 <br/>

    </body>
</html>
```

#### ■ Scale / 이미지 변경(배포)

- 복재 생성 : replicas 속성을 이용하여 scale(노드개수) 조정 

```bash 
kubectl scale deployment/mvc --replicas=4
```

- rollout 상태확인 : scale 이나 set 명령처럼 상태가 변경될때 확인 (완료될때 까지 명령이 홀딩됨)

```bash 
> kubectl rollout status deployment mvc
Waiting for rollout to finish: 1 of 4 updated replicas are available...
Waiting for rollout to finish: 2 of 4 updated replicas are available...
Waiting for rollout to finish: 3 of 4 updated replicas are available...
deployment "mvc" successfully rolled out

> kubectl get pod
NAME                   READY     STATUS    RESTARTS   AGE
mvc-56b94948b9-dfd9f   1/1       Running   0          7m
mvc-56b94948b9-qdpql   1/1       Running   0          11m
mvc-56b94948b9-s4cls   1/1       Running   0          7m
mvc-56b94948b9-w6lbj   1/1       Running   0          7m

```

- 이미지 변경 (버전업 배포) : 0.1 → 0.2 

```bash
kubectl set image deployment/mvc mvcapp=cdecl/mvcapp:0.2
```

```bash
> kubectl rollout status deployment mvc
Waiting for rollout to finish: 2 out of 4 new replicas have been updated...
Waiting for rollout to finish: 2 out of 4 new replicas have been updated...
Waiting for rollout to finish: 2 out of 4 new replicas have been updated...
Waiting for rollout to finish: 3 out of 4 new replicas have been updated...
Waiting for rollout to finish: 3 out of 4 new replicas have been updated...
Waiting for rollout to finish: 3 out of 4 new replicas have been updated...
Waiting for rollout to finish: 1 old replicas are pending termination...
Waiting for rollout to finish: 1 old replicas are pending termination...
Waiting for rollout to finish: 1 old replicas are pending termination...
Waiting for rollout to finish: 3 of 4 updated replicas are available...
deployment "mvc" successfully rolled out
``` 

```bash
➜  k8s_test git:(master) kubectl rollout history deployment/mvc
deployments "mvc"
REVISION  CHANGE-CAUSE
1         <none>
2         <none>

```

- 이전 버전으로 롤백 

```bash
> kubectl rollout undo deployment/mvc
deployment.apps "mvc"
```

---
### 서비스 배포 :  yaml 파일 기반 

#### ■ 배포 / 서비스 추가  
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
  replicas: 4 # --replicas=4 옵션과 동일 
  template: # create pods using pod definition 
    metadata:
      labels:
        app: mvcapp
    spec:
      containers:
      - name: mvcapp
        image: cdecl/mvcapp:0.2
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

```bash

# yaml 파일 적용(생성)
kubectl create -f mvcapp-deploy-service.yaml

# yaml 파일 갱신 
# 파일 수정 후, apply 를 하게 되면  set image, replicas 등과 같이 정책 변경이 가능함 
kubectl apply -f mvcapp-deploy-service.yaml
``` 

```bash

> kubectl apply -f mvcapp-deploy-service.yaml
deployment.apps "mvcapp" created
service "mvcapp" created

```

---
### 서비스 노출 

#### ■ Ingress 컨트롤러 설치 및 정의 
- Ingress 컨트롤러는 외부 서비스 접속을 위한 도메인, URL 기반 서비스 분기 역할 `L7 레이어 기능`
- 그중 가장 많이 활성화 된 nginx 기반 Ingress 컨트롤러 이용 
- ingress-nginx repository : https://github.com/kubernetes/ingress-nginx
- RBAC 기반 설치 : 역할 기반 접근 제어(role-based access control)
- 서비스 변경 : ClusterIP → NodePort
	- ingress-nginx 에서 제공하는 yaml 파일로 설치를 하면 ClusterIP 기반으로 서비스로 설치 
	- Bare Metal 환경에서는 ClusterIP를 지원하지 않기 때문에 NodePort 기반으로 수정  
		- --publish-service=$(POD_NAMESPACE)/ingress-nginx 라인 주석처리 후 서비스 생성추가
		- 별도 서비스까지 생성하는 버전 (NodePort 기반 서비스 생성) : [mandatory-0.17.yaml](mandatory-0.17.yaml)
	- 서비스 생성후 kubectl edit 명령으로 서비스를 수정 해도 됨 
		- `deployment nginx-ingress-controller  -n ingress-nginx`

```bash
# 공식 레포지토리 버전 
> kubectl apply -f mandatory-0.17.yaml
namespace "ingress-nginx" created
deployment.extensions "default-http-backend" created
service "default-http-backend" created
configmap "nginx-configuration" created
configmap "tcp-services" created
configmap "udp-services" created
serviceaccount "nginx-ingress-serviceaccount" created
clusterrole.rbac.authorization.k8s.io "nginx-ingress-clusterrole" created
role.rbac.authorization.k8s.io "nginx-ingress-role" created
rolebinding.rbac.authorization.k8s.io "nginx-ingress-role-nisa-binding" created
clusterrolebinding.rbac.authorization.k8s.io "nginx-ingress-clusterrole-nisa-binding" created
deployment.extensions "nginx-ingress-controller" created
service "ingress-nginx" created

# ingress-nginx namespace 로 생성을 해서 namespace를 지정 하던가 --all-namespaces 옵션으로 확인 
# mvc는 명령어 기반으로 생성, mvcapp는 yaml 파일로  생성한 pod 
> kubectl  get pod --all-namespaces
NAMESPACE       NAME                                        READY     STATUS    RESTARTS   AGE
default         mvc-56b94948b9-5pkqd                        1/1       Running   0          2h
default         mvc-56b94948b9-k2ddc                        1/1       Running   0          2h
default         mvc-56b94948b9-mzwrz                        1/1       Running   0          2h
default         mvc-56b94948b9-n5nj6                        1/1       Running   0          2h
default         mvcapp-8b478b47-2bsmq                       1/1       Running   0          39m
default         mvcapp-8b478b47-tsrpb                       1/1       Running   0          39m
default         mvcapp-8b478b47-vvzhf                       1/1       Running   0          39m
default         mvcapp-8b478b47-wgx5k                       1/1       Running   0          39m
ingress-nginx   default-http-backend-5c6d95c48-zpz8w        1/1       Running   0          28s
ingress-nginx   nginx-ingress-controller-77fb97cd77-5p6xt   1/1       Running   0          28s
kube-system     etcd-kube-master                            1/1       Running   0          2h
kube-system     kube-apiserver-kube-master                  1/1       Running   0          2h
kube-system     kube-controller-manager-kube-master         1/1       Running   0          2h
kube-system     kube-dns-86f4d74b45-hc7wc                   3/3       Running   0          4h
kube-system     kube-flannel-ds-amd64-7dl27                 1/1       Running   0          2h
kube-system     kube-flannel-ds-amd64-dnfdb                 1/1       Running   0          2h
kube-system     kube-flannel-ds-amd64-f2ln5                 1/1       Running   0          2h
kube-system     kube-proxy-54zhf                            1/1       Running   0          2h
kube-system     kube-proxy-6m8bw                            1/1       Running   0          4h
kube-system     kube-proxy-nsfqv                            1/1       Running   0          2h
kube-system     kube-scheduler-kube-master                  1/1       Running   0          2h

> kubectl get svc --all-namespaces
NAMESPACE       NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
default         kubernetes             ClusterIP   10.96.0.1        <none>        443/TCP                      4h
default         mvc                    NodePort    10.107.73.137    <none>        80:32074/TCP                 2h
default         mvcapp                 NodePort    10.101.149.34    <none>        80:30054/TCP                 39m
ingress-nginx   default-http-backend   ClusterIP   10.101.247.31    <none>        80/TCP                       50s
ingress-nginx   ingress-nginx          NodePort    10.110.129.111   <none>        80:32056/TCP,443:30485/TCP   50s
kube-system     kube-dns               ClusterIP   10.96.0.10       <none>        53/UDP,53/TCP                4h

```

- Ingress 서비스 IP:Port로 확인 : 현재는 Ingress 등록 서비스가 존재하지 않아 default-http-backend 로 리다이렉트

```bash 
> curl 10.110.129.111
default backend - 404
```

- Ingress 서비스 등록
	- mvcapp 서비스를 Ingress 기반 서비스에 등록
	- 주석과 같이 host 및 url 기반으로도 가능 

```yaml
# ingress-mvcapp.yaml

# 디폴트 서비스(backend)로 등록 
apiVersion: extensions/v1beta1          
kind: Ingress                           
metadata:                               
  name: mvcapp-ingress                    
spec: 
  backend:                        
    serviceName: mvcapp           
    servicePort: 80               

# 아래와 같이 host 기반으로 설정가능 
# spec:                                   
#   rules:                                
#   - host: mvc.cdecl.net                 
#     http:                               
#       paths:                            
#       - path: /                         
#         backend:                        
#           serviceName: mvcapp           
#           servicePort: 80               
                                        
```

```bash
> kubectl apply -f ingress-mvcapp.yaml
ingress.extensions "mvcapp-ingress" created

# 서비스 확인 
> kubectl get svc -n ingress-nginx
NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
default-http-backend   ClusterIP   10.105.95.173   <none>        80/TCP                       35m
ingress-nginx          NodePort    10.102.60.33    <none>        80:32673/TCP,443:31112/TCP   1m

# ingress 확인 
> kubectl get ingress
NAME             HOSTS     ADDRESS   PORTS     AGE
mvcapp-ingress   *                   80        24s

# Ingress 서비스 확인 : ingress-nginx IP:PORT 사용 
# Ingress → mvcapp → pod 
> curl 10.110.129.111

<html>
    <head>

    </head>
    <body>
        Title : Home Page <br/>
        cdecl called 2 <br/>
        MachineName: mvcapp-8b478b47-2bsmq <br/>
        ver: 0.2 <br/>

    </body>
</html>%

```

#### ■ 서비스 외부 노출 Expose direct ports on bare metal
- 레딧 : [Best way to expose direct ports on bare metal](https://www.reddit.com/r/kubernetes/comments/85ewlw/best_way_to_expose_direct_ports_on_bare_metal/)
- 서비스를 직접 노출하는 방법 
	- Reverse Proxy : Nginx 류의 서비스로 리버스 프록시 구성 
		- 외부 → Nginx(pass) → Ingress(내부서비스IP) → NodePort → Pod 
	- ExtenalPs 지정 : Bare Metal 장비의 Public IP를 세팅
		- 각 머신에서는 등록된 자신의 IP 기준으로 Listen  
		- 외부 → Ingress(externalIPs) → NodePort → Pod 
		- externalIPs에 등록된 서버에서 서비스가 구동되면 해당 IP로 외부서비스 노출 (LISTEN)

```yaml
kind: Service
apiVersion: v1
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  labels:
    app: ingress-nginx
spec:
  type: NodePort
  selector:
    app: ingress-nginx
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: https
    port: 443
    targetPort: https
  externalIPs:
  - 192.168.137.20
  - 192.168.137.116
  - 192.168.137.64

``` 

---

### Dashboard 설치  
- Kubernetes의 리소스 상태를 확인 할 수 있는 Dashboard 설치

```bash
# dashboard
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
```

- Role을 부여하여 Token Key로 접속하는 방법이 있으나 어플리케이션에 cluster-admin 부여하여 인증없이 접속 
	- [dashboard-admin.yaml](dashboard-admin.yaml)
	- Apply the full admin privileges to dashboard service account using the dashboard-admin YAML file.

```yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system

```

- Role 적용, Proxy 서비스 실행  
```bash
kubectl apply -f dashboard-admin.yaml
kubectl proxy --address=0.0.0.0 --accept-hosts=^*$
```

- Dashboard 접속 : http://kube-master:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

---

### 추가작업 
- Master Node 고가용성 확보 : 3대 NODE 구성
- 버전 업그레이드 방법 
 
