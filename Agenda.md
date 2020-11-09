# kubernetes-101

## Docker 

### Docker Network 
- None
- **Bridge**
- Host
- Container

### Kubernetes Pod
- 관리되는 Docker Container(s) : 하나 이상의 컨테이너의 그룹
- 고유한 IP 주소가 할당/관리

## Kubernetes 
- Container Orchestration :  컨테이너의 배포, 관리, 확장, 네트워킹을 자동화합니다
> 쿠버네티스는 컨테이너화된 워크로드와 서비스를 관리하기 위한 이식성이 있고, 확장가능한 오픈소스 플랫폼이다. 쿠버네티스는 선언적 구성과 자동화를 모두 용이하게 해준다. 쿠버네티스는 크고, 빠르게 성장하는 생태계를 가지고 있다. 쿠버네티스 서비스, 기술 지원 및 도구는 어디서나 쉽게 이용할 수 있다.

### 관리툴 
- kubectl : 클러스터를 제어하기 위한 커맨드 라인 도구
- kubeadm : 실행 가능한 최소 클러스터를 시작하고 실행하는 데 필요한 작업을 수행
- kubelet : 클러스터의 모든 머신에서 실행되며 Pod 및 컨테이너 시작 등의 작업을 수행하는 구성 요소이다 (Service daemon)

### 설치준비 (OS)
- swap disable
- selinux disable
- firewalld(iptable) disable
- bridge network setup

### Kubernetes  설치 
- Master Node Init
- Overlay network Install
- Worker Node Join

### Kubernetes Workloads (Controller type)
- Deployments (ReplicaSet) : Stateless 
  - 애플리케이션의 인스턴스를 어떻게 생성하고 업데이트해야 하는지 지시 
- DaemonSets 
  - 특정 노드 또는 모든 노드에 항상 실행, 특정 Pod 관리
- Jobs
  - 한번 실행되고 끝나는 Pod
- CronJob
  - 반복적인 작업을 실해하는 Pod  
- StatefulSets
  - 상태 유지가 필요한(stateful) 애플리케이션 (Pod 독자성 유지)

### Kubernetes Service 
- Pod 집합에서 실행중인 애플리케이션을 네트워크 서비스로 노출하는 추상화 방법

#### Service Type
- ClusterIP
- NodePort
- LoadBalancer

#### Ingress

### Kubernetes DNS

### Service exposes
- Cloud (LoadBalancer)
- MetalLB :  Load-balancer implementation for bare metal Kubernetes clusters
- Over a NodePort Service
- External IPs
- Via the host network

### Pod Network Routes
