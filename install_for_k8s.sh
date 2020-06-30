# Config network, make sure access internet

# 关闭Selinux，Firewalld
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
setenforce 0
systemctl disable firewalld
systemctl stop firewalld

# 关闭Swap虚拟内存
swapoff -a
sed -i '/swap/d' /etc/fstab
# free

modprobe br_netfilter
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
# sysctl -p

yum -y install yum-utils lvm2 device-mapper-persistent-data nfs-utils xfsprogs wget net-tools

yum -y remove docker-client docker-client-latest docker-common docker-latest \
    docker-logrotate \docker-latest-logrotate docker-selinux docker-engine-selinux docker-engine

yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum -y install docker-ce docker-ce-cli containerd.io

systemctl enable docker
systemctl start docker

cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
    "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "registry-mirrors":[
        "https://kfwkfulq.mirror.aliyuncs.com",
        "http://hub-mirror.c.163.com",
        "https://docker.mirrors.ustc.edu.cn",
        "https://registry.docker-cn.com"
    ]
}
EOF

systemctl daemon-reload
systemctl restart docker
# docker info

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
    http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

yum install kublet-1.18.2 kubeadm-1.18.2 kubectl-1.18.2 -y
# yum安装指定版本的软件，查看版本信息的方法是：yum list kubelet --showduplicates |expand

systemctl enable kubelet
systemctl start kubelet

wget https://docs.projectcalico.org/v3.8/manifests/calico.yaml

sed -i "s#192\.168\.0\.0/16#10\.10\.0\.0/16#" calico.yaml
kubectl apply -f calico.yaml

# watch -n 2 kubectl get pods -n kube-system -o wide

kubectl apply -f https://kuboard.cn/install-script/v1.16.0/nginx-ingress.yaml

hostnamectl set-hostname master1
# 设置 hostname，保存在 /etc/hostname

export MASTER_IP=192.168.0.132
export APISERVER_NAME=master1
echo "${MASTER_IP}    ${APISERVER_NAME}" >> /etc/hosts
# 设置Master节点的IP地址和Hostname，并保存在DNS本地解析配置文件 /etc/hosts

export POD_SUBNET=10.100.0.1/16nets
# 设置Kubernetes 容器组所在的网段，该网段安装完成后，由 kubernetes 创建，事先并不存在于您的物理网络中

kubeadm init \
    --apiserver-advertise-address 0.0.0.0 \
    --apiserver-bind-port 6443 \
    --cert-dir /etc/kubernetes/pki \
    --control-plane-endpoint master1 \
    --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers \
    --kubernetes-version 1.18.2 \
    --pod-network-cidr 10.11.0.0/16 \
    --service-cidr 10.20.0.0/16 \
    --service-dns-domain cluster.local \
    --upload-certs

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# 在$HOME/.kube下生成config文件，保存master的登录信息

sudo chown $(id -u):$(id -g) $HOME/.kube/config
# 用于为普通用户分配kubectl权限

kubectl apply -f https://kuboard.cn/install-script/kuboard.yaml
kubectl apply -f https://addons.kuboard.cn/metrics-server/0.3.6/metrics-server.yaml

# kubectl get pods -l k8s.kuboard.cn/name=kuboard -n kube-system