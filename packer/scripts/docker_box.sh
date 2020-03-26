#!/bin/bash 

echo Updating OS
yum update -y

echo Disable swap and firewalld
swapoff -a
sed -i "s,/dev/mapper/centos_centos7-swap,#/dev/mapper/centos_centos7-swap,g" /etc/fstab
systemctl disable --now firewalld

echo Set SELinux in permissive mode
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

echo Setting required kernel flags
echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.d/99-k8s.conf
modprobe br_netfilter
sleep 1
sysctl -w net.bridge.bridge-nf-call-iptables=1

echo Adding kubernetes and docker yum repo
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

mkdir -p /etc/docker

echo Setup docker daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

echo Install kubernetes and docker
yum install -y device-mapper-persistent-data lvm2 containerd.io docker-ce docker-ce-cli git

echo Adding vagrant user to docker group
usermod -a -G docker vagrant

echo enable and start docker and kubelet
systemctl enable --now docker

