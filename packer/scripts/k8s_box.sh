#!/bin/bash 

echo Updating OS
yum update -y

echo Install kubernetes and docker
yum install -y bash-completion kubelet kubeadm kubectl device-mapper-persistent-data lvm2 containerd.io docker-ce docker-ce-cli git --disableexcludes=kubernetes

echo enable and start docker and kubelet
systemctl enable kubelet

echo Running kubeadm and setting up flannel
kubeadm init --pod-network-cidr=10.244.0.0/16
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml

echo Allowing vagrant user access to kubectl
kubectl completion bash >/etc/bash_completion.d/kubectl
su vagrant -c 'mkdir -p $HOME/.kube'
cp -i /etc/kubernetes/admin.conf ~vagrant/.kube/config 
sudo chown $(id -u vagrant):$(id -g vagrant) ~vagrant/.kube/config 

echo allowing things to run on control plane node
kubectl taint nodes --all node-role.kubernetes.io/master-
