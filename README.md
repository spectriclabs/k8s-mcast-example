Kubernetes multicast example
------------------------------

This repo serves as an example of how to setup and configure kubernetes
for multicast support using the [Intel Multus CNI](https://github.com/intel/multus-cni) plugin.


Walkthrough
------------

Ensure you have [Vagrant](https://www.vagrantup.com/) installed, clone this repo and cd into the Vagrant directory. Run `vagrant up` to bring up the VMs:

```bash
[ylb@spectric ~]$ cd k8s-mcast-example/Vagrant
[ylb@spectric Vagrant]$ vagrant up
```

You now have 2 nodes, `k8s` and `mcastsrc`. You can ssh to either via:
```bash
[ylb@spectric Vagrant]$ vagrant ssh <node name>
```

The k8s node is a single-node Kubernetes installation and the mcast host will act as our multicast source.

**Multicast Outside of Kuberentes:**

Verify multicast works outside of kubernetes first by using `iperf` and the hosts network.
The following iperf command will subscribe to multicast packets for the IGMP group address
`224.0.67.67`. We will do this on the k8s VM and send the multicast packets on the 
mcastsrc VM

```bash
[ylb@spectric Vagrant]$ vagrant ssh k8s
[vagrant@k8s ~] docker run --net=host --rm bagoulla/iperf:2.0 -s -u -B 224.0.67.67%eth1 -i 1
...
```

From a new terminal, ssh into our mcastsrc VM and begin sending the mcast packets, you should see the successful reception in the other terminal.
```bash
[ylb@spectric Vagrant]$ vagrant ssh mcastsrc
[vagrant@mcastsrc ~]$ docker run --net=host --rm bagoulla/iperf:2.0  -c 224.0.67.67 -u --ttl 5 -t 60 -B 10.0.0.12
...
```

You can `ctrl+c` to break out of iperf. We now want to mimic these results from within Kubernetes.

**Multicast within Kuberentes:**

From the k8s VM, apply the intel multus daemonset which will allow us to mount in specific host network interfaces:

```bash
[ylb@spectric Vagrant]$ vagrant ssh k8s
[vagrant@k8s ~]$ kubectl apply -f https://raw.githubusercontent.com/intel/multus-cni/master/images/multus-daemonset.yml
```

We now must apply a NetworkAttachmentDefinition which tells multus which network interface we want to expose to our containers and how. We need to specify which interface on the parent to pass and an IP range to assign an addresses from. Many other optional parameters may be specified including a default gateway and custom routes; see the multus documentation for additional configuration options. Below is the NetworkAttachmentDefinition we will use to expose eth1, a copy has been placed in `/vagrant`:

```yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: eth1-multicast
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "eth1",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "10.0.0.0/24",
        "rangeStart": "10.0.0.13",
        "rangeEnd": "10.0.0.254"
      }
    }'
```

Apply the configuration:
```bash
[vagrant@k8s ~]$ kubectl apply -f /vagrant/net-config.yml 
```

Now simply reference that network configuration in our pod spec to pass the interface into our Pod. This can be done within a pod definition, deployment, etc. Apply the example pod shown below from `/vagrant/example-mcast-pod.yml` to kick off our multicast consumer.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multicast-example
  annotations:
    k8s.v1.cni.cncf.io/networks: eth1-multicast@eth1
spec:
  containers:
  - name: example-multicast-pod
    command: ["iperf", "-s", "-u", "-B", "224.0.67.67%eth1", "-i", "1"]
    image: bagoulla/iperf:2.0
```

Once it has successfully deployed tail the logs:
```bash
[vagrant@k8s ~]$ kubectl apply -f /vagrant/example-mcast-pod.yml
pod/multicast-example created
...  # Use "kubectl describe pod multicast-example"
...  # to track the launch
[vagrant@k8s ~]$ kubectl logs -f multicast-example
```

While tailing those logs, kick off the multicast sender from our mcastsrc VM and verify reception.
```bash
[vagrant@mcastsrc ~]$ docker run --net=host --rm bagoulla/iperf:2.0  -c 224.0.67.67 -u --ttl 5 -t 5 -B 10.0.0.12
...
```

Rebuilding the image
------------------

There are two images used here, the first is a base image that has docker installed and the kubernetes yum repositories configured. The second has kubernetes installed. Our docker image is used as the mcastsrc while the kubernetes image is the k8s VM.

Both are built using [packer](https://packer.io/). To rebuild both run:

```bash
[ylb@spectric ~]$ cd k8s-mcast-example/packer
[ylb@spectric packer]$ packer build docker_box.json
[ylb@spectric packer]$ vagrant box add bagoulla/docker-centos7 build/bagoulla/docker-centos7/package.box
[ylb@spectric packer]$ packer build k8s_box.json
[ylb@spectric packer]$ vagrant box add bagoulla/k8s-centos7 build/bagoulla/k8s-centos7/package.box
```

The configuration and installation of both the docker and Kubernetes image are found within `packer/scripts/`.
