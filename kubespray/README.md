
Kubespray 를 이용한 Kubernetes 설치 (Baremetal)

## 사전준비  

### 서버 노드 준비 

- 3대 Node 
    
```
192.168.28.15
192.168.28.16
192.168.28.17
```

### 서버 노드 환경설정 : [kubernetes-101 참고](/devops/kubernetes-101/)
- Swap 영역을 비활성화
- SELinux Disable
- 방화벽 Disable
- 브릿지 네트워크 할성화
- 설치 노드에서의 ssh 접속 허용 : SSH 키복사 `ssh-copy-id`


### 설치 준비
- Git : Repository Clone
- Python3 : Inventory 및 환경 설정을 위한 스크립트 실행
- Ansible : 원격 실행(설치) `ansible-playbook`

> Repository clone 및 Python package install 

```sh
$ git clone https://github.com/kubernetes-sigs/kubespray
$ cd kubespray

# Package install
$ pip3 install -r requirements.txt
```

---

## 설치 방법 1 : `inventory_builder`

> `inventory_builder` Python script 활용 inventory 구성 및 설치

```sh
# Install 을 위한 Inventory 생성을 위한 공간 생성(복사)
$ cp -rfp inventory/sample inventory/glass

# IP 3개 지정, Node 설정 → inventory/glass/hosts.yaml
$ declare -a IPS=(192.168.28.15 192.168.28.16 192.168.28.17)
$ CONFIG_FILE=inventory/glass/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
DEBUG: Adding group all
DEBUG: Adding group kube_control_plane
DEBUG: Adding group kube_node
DEBUG: Adding group etcd
DEBUG: Adding group k8s_cluster
DEBUG: Adding group calico_rr
DEBUG: adding host node1 to group all
DEBUG: adding host node2 to group all
DEBUG: adding host node3 to group all
DEBUG: adding host node1 to group etcd
DEBUG: adding host node2 to group etcd
DEBUG: adding host node3 to group etcd
DEBUG: adding host node1 to group kube_control_plane
DEBUG: adding host node2 to group kube_control_plane
DEBUG: adding host node1 to group kube_node
DEBUG: adding host node2 to group kube_node
DEBUG: adding host node3 to group kube_node

# inventory 자동 구성 - 3개 노드 
#   kube_control_plane: node1,node2 
#   workder: node3
$ cat inventory/glass/hosts.yaml
all:
  hosts:
    node1:
      ansible_host: 192.168.28.15
      ip: 192.168.28.15
      access_ip: 192.168.28.15
    node2:
      ansible_host: 192.168.28.16
      ip: 192.168.28.16
      access_ip: 192.168.28.16
    node3:
      ansible_host: 192.168.28.17
      ip: 192.168.28.17
      access_ip: 192.168.28.17
  children:
    kube_control_plane:
      hosts:
        node1:
        node2:
    kube_node:
      hosts:
        node1:
        node2:
        node3:
    etcd:
      hosts:
        node1:
        node2:
        node3:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}


## Install // 오래 걸림 
$ ansible-playbook -i inventory/glass/hosts.yaml  --become --become-user=root cluster.yml
```

### Cluster 확인 

```sh
$ kubectl get node
NAME    STATUS   ROLES                  AGE   VERSION
node1   Ready    control-plane,master   40m   v1.18.6
node2   Ready    control-plane,master   40m   v1.18.6
node3   Ready    <none>                 38m   v1.18.6

$ kubectl get pod -A
NAMESPACE     NAME                                       READY   STATUS             RESTARTS   AGE
kube-system   calico-kube-controllers-8575b76f66-kx2sv   0/1     CrashLoopBackOff   12         40m
kube-system   calico-node-g9xmm                          1/1     Running            0          40m
kube-system   calico-node-pg7dt                          1/1     Running            0          40m
kube-system   calico-node-rwbcf                          1/1     Running            0          40m
kube-system   coredns-8474476ff8-26p2b                   1/1     Running            0          39m
kube-system   coredns-8474476ff8-j5k4w                   1/1     Running            0          39m
kube-system   dns-autoscaler-7df78bfcfb-7r474            1/1     Running            0          39m
kube-system   kube-apiserver-node1                       1/1     Running            0          42m
kube-system   kube-apiserver-node2                       1/1     Running            0          41m
kube-system   kube-controller-manager-node1              1/1     Running            0          42m
kube-system   kube-controller-manager-node2              1/1     Running            0          41m
kube-system   kube-proxy-4lqh5                           1/1     Running            0          40m
kube-system   kube-proxy-6tg8t                           1/1     Running            0          40m
kube-system   kube-proxy-brljv                           1/1     Running            0          40m
kube-system   kube-scheduler-node1                       1/1     Running            0          42m
kube-system   kube-scheduler-node2                       1/1     Running            0          41m
kube-system   nginx-proxy-node3                          1/1     Running            0          40m
kube-system   nodelocaldns-76jw6                         1/1     Running            0          39m
kube-system   nodelocaldns-k87js                         1/1     Running            0          39m
kube-system   nodelocaldns-lnlqt                         1/1     Running            0          39m

```


### 서비스 설치 및 확인 

- mvcapp-deploy-service.yaml
 
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mvcapp
spec:
  selector:
    matchLabels:
      app: mvcapp
  replicas: 4 
  template: 
    metadata:
      labels:
        app: mvcapp
    spec:
      containers:
      - name: mvcapp
        image: cdecl/mvcapp:0.6
        imagePullPolicy: Always
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
    nodePort: 30010
```

```sh
$ kubectl apply -f mvcapp-deploy-service.yaml
deployment.apps/mvcapp created
service/mvcapp created

$ kubectl get pod -owide
NAME                      READY   STATUS    RESTARTS   AGE   IP            NODE    NOMINATED NODE   READINESS GATES
mvcapp-5c56c55f76-c245s   1/1     Running   0          44s   10.233.96.4   node2   <none>           <none>
mvcapp-5c56c55f76-nt7bw   1/1     Running   0          44s   10.233.92.5   node3   <none>           <none>
mvcapp-5c56c55f76-pjr8c   1/1     Running   0          44s   10.233.96.3   node2   <none>           <none>
mvcapp-5c56c55f76-xthgs   1/1     Running   0          44s   10.233.92.6   node3   <none>           <none>]

$ kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.233.0.1      <none>        443/TCP        8m42s
mvcapp       NodePort    10.233.12.111   <none>        80:30010/TCP   83s

# cluster ip 로 호출
$ curl -s 10.233.12.111:80
    * Project           : mvcapp
    * Version           : 0.6 / net5.0
    * Hostname          : mvcapp-5c56c55f76-frbfs
    * Sleep(sync)       : 0
    * RemoteAddr        : 10.233.90.0
    * X-Forwarded-For   : 
    * Request Count     : 1
    * User-Agent        : curl/7.29.0

# node port (kube-proxy) 호출 
$ curl -s node1:30010
    * Project           : mvcapp
    * Version           : 0.6 / net5.0
    * Hostname          : mvcapp-5c56c55f76-c82ws
    * Sleep(sync)       : 0
    * RemoteAddr        : 10.233.90.0
    * X-Forwarded-For   : 
    * Request Count     : 1
    * User-Agent        : curl/7.29.0

```

---

## 설치 방법 2 : inventory 직접 수정 

> inventory.ini 수정 및 설치

```sh
# Install 을 위한 Inventory 생성을 위한 공간 생성(복사)
$ cp -rfp inventory/sample inventory/glass
```

- inventory/glass/inventory.ini 
  - `kube_control_plane` 1개만 설정 :  `node1`

```ini
# ## Configure 'ip' variable to bind kubernetes services on a
# ## different ip than the default iface
# ## We should set etcd_member_name for etcd cluster. The node that is not a etcd member do not need to set the value, or can set the empty string value.
[all]
node1 ansible_host=192.168.28.15
node2 ansible_host=192.168.28.16
node3 ansible_host=192.168.28.17

# ## configure a bastion host if your nodes are not directly reachable
# [bastion]
# bastion ansible_host=x.x.x.x ansible_user=some_user

[kube_control_plane]
node1

[etcd]
node1
node2
node3

[kube_node]
node2
node3
# node4
# node5
# node6

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr
```

```sh
## Install
$ ansible-playbook -i inventory/glass/inventory.ini  --become --become-user=root cluster.yml
```

### Cluster 확인 

```sh
$ kubectl get node
NAME    STATUS   ROLES                  AGE     VERSION
node1   Ready    control-plane,master   3m41s   v1.18.6
node2   Ready    <none>                 2m37s   v1.18.6
node3   Ready    <none>                 2m38s   v1.18.6

$ kubectl get pod -A
NAMESPACE     NAME                                       READY   STATUS             RESTARTS   AGE
kube-system   calico-kube-controllers-8575b76f66-nm6ll   0/1     CrashLoopBackOff   5          4m35s
kube-system   calico-node-9xqmz                          1/1     Running            0          4m55s
kube-system   calico-node-dbr4p                          1/1     Running            0          4m55s
kube-system   calico-node-h4xcv                          1/1     Running            0          4m55s
kube-system   coredns-8474476ff8-6rx9f                   1/1     Running            0          4m20s
kube-system   coredns-8474476ff8-r7nrf                   1/1     Running            0          4m15s
kube-system   dns-autoscaler-7df78bfcfb-g482g            1/1     Running            0          4m17s
kube-system   kube-apiserver-node1                       1/1     Running            0          6m6s
kube-system   kube-controller-manager-node1              1/1     Running            0          6m6s
kube-system   kube-proxy-6rxsz                           1/1     Running            0          5m12s
kube-system   kube-proxy-jt2dl                           1/1     Running            0          5m12s
kube-system   kube-proxy-kdxch                           1/1     Running            0          5m12s
kube-system   kube-scheduler-node1                       1/1     Running            0          6m6s
kube-system   nginx-proxy-node2                          1/1     Running            0          5m12s
kube-system   nginx-proxy-node3                          1/1     Running            0          5m12s
kube-system   nodelocaldns-2tjm8                         1/1     Running            0          4m16s
kube-system   nodelocaldns-pzkjq                         1/1     Running            0          4m16s
kube-system   nodelocaldns-r9gbv                         1/1     Running            0          4m16s
```

```sh
$ kubectl apply -f mvcapp-deploy-service.yaml
deployment.apps/mvcapp created
service/mvcapp created

$ kubectl get pod -owide
NAME                      READY   STATUS    RESTARTS   AGE   IP            NODE    NOMINATED NODE   READINESS GATES
mvcapp-5c56c55f76-c82ws   1/1     Running   0          48s   10.233.96.3   node2   <none>           <none>
mvcapp-5c56c55f76-frbfs   1/1     Running   0          48s   10.233.92.2   node3   <none>           <none>
mvcapp-5c56c55f76-kx2bm   1/1     Running   0          48s   10.233.96.2   node2   <none>           <none>
mvcapp-5c56c55f76-xvlbp   1/1     Running   0          48s   10.233.92.1   node3   <none>           <none>
```

---

## 클러스터 고가용성 구조
- <https://github.com/kubernetes-sigs/kubespray/blob/master/docs/ha-mode.md>

### Etcd 클러스터 구성

### Kube-apiserver
- kubeadm 고가용성 구조의 경우 `kube-apiserver` 서버접근을 위한 HA (loadbalancer) 가 필요 
- kubespray 의 경우 `nginx-based` 기반 `reverse proxy` 각 node 에 내장되어 있어서 별도 LB 구성이 필요 없음
  - `local internal loadbalancer` 를 사용하지 않은 경우 별도 HA 구성 가능 

![](https://raw.githubusercontent.com/kubernetes-sigs/kubespray/master/docs/figures/loadbalancer_localhost.png)


---

## Node 추가 및 Cluster 변경
- <https://github.com/kubernetes-sigs/kubespray/blob/master/docs/nodes.md>

#### 1) Control-plane 변경 
- Change order of current control planes
- Upgrade the cluster

> inventory 수정 후, cluster.yml 실행 

```sh
$ ansible-playbook -i inventory/glass/hosts.yaml cluster.yml
```

#### 2) Adding/replacing a worker node

> inventory 수정 후, scale.yml 실행 

```sh
# 전체 갱신 
$ ansible-playbook -i inventory/glass/hosts.yaml scale.yml

# 추가된 node3 만 갱신 
$ ansible-playbook -i inventory/glass/hosts.yaml scale.yml --limit=node3
```

#### 3) Remove a worker node

```sh
$ ansible-playbook -i inventory/glass/hosts.yaml remove-node.yml -e node=node3
...

$ kubectl get node
NAME    STATUS                        ROLES                  AGE   VERSION
node1   Ready                         control-plane,master   86m   v1.18.6
node2   Ready                         control-plane,master   85m   v1.18.6
node3   NotReady,SchedulingDisabled   <none>                 19m   v1.18.6


$ kubectl delete node node3
node "node3" deleted

$ kubectl get node
NAME    STATUS   ROLES                  AGE   VERSION
node1   Ready    control-plane,master   88m   v1.18.6
node2   Ready    control-plane,master   87m   v1.18.6
```

---

### 초기화 : 클러스터 삭제 

```sh
$ ansible-playbook -i inventory/glass/hosts.yaml  --become --become-user=root reset.yml
```

