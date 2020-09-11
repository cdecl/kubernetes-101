# K3S 

## K3S 특징
- 기본 설치만으로 바로 배포 테스트 가능 
- Overlay Netowrk(Flannel), Load balancer, Ingress(Traefik), CoreDNS 등이 기본 설치 됨 
	- https://rancher.com/docs/k3s/latest/en/networking/
- etcd 대신 sqlite 운영
	- High Availability with an External DB
	- High Availability with Embedded DB (Experimental)
- Master node schedulable
	- uncordon 제외 가능 

## Install 
### Master 설치 
```sh 
$ curl -sfL https://get.k3s.io | sh -

$ kubectl get node
NAME     STATUS   ROLES    AGE    VERSION
centos   Ready    master   144m   v1.18.8+k3s1

$ kubectl get pod --all-namespaces
NAMESPACE     NAME                                     READY   STATUS      RESTARTS   AGE
kube-system   metrics-server-7566d596c8-8m7vc          1/1     Running     0          167m
kube-system   helm-install-traefik-7tvl4               0/1     Completed   0          167m
kube-system   coredns-7944c66d8d-gdddv                 1/1     Running     0          167m
kube-system   svclb-traefik-fsb2r                      2/2     Running     0          166m
kube-system   traefik-758cd5fc85-w4c5d                 1/1     Running     0          166m
kube-system   local-path-provisioner-6d59f47c7-h2jw9   1/1     Running     1          167m
```

### Agent 추가 
- 환경변수 세팅
```sh
$ sudo cat /var/lib/rancher/k3s/server/node-token	 > ~/.node-token
$ K3S_TOKEN=$(< ~/.node-token)
$ HOST_IP=$(ip a | sed -rn 's/.*inet ([0-9\.]+).*eth0/\1/p')
```

- Agent 등록 : 원격실행 OR Agent 머신에서 실행
```sh
# curl -sfL https://get.k3s.io | K3S_URL=https://$HOST_IP:6443 K3S_TOKEN=$K3S_TOKEN sh -
$ ansible cent01 -m shell -a "curl -sfL https://get.k3s.io | K3S_URL=https://$HOST_IP:6443 K3S_TOKEN=$K3S_TOKEN sh -" -v

$ kubectl get node
NAME     STATUS   ROLES    AGE    VERSION
centos   Ready    master   148m   v1.18.8+k3s1
cent01   Ready    <none>   31s    v1.18.8+k3s1


# Agent 추가 다른방법 
$ ansible cent01 -m shell -a "curl -sfL https://get.k3s.io | sh -s - agent --server https://$HOST_IP:6443 --token $K3S_TOKEN" -v

```

- K3S 삭제 
```sh
ls /usr/local/bin/k3s-* | xargs -n1 sh -
```



