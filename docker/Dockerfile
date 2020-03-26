FROM centos:7
RUN yum install -y epel-release && yum clean all
RUN yum install -y iperf && yum clean all
ENTRYPOINT ["/usr/bin/iperf"]
