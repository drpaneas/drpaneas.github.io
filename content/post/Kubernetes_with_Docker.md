+++
categories = ["tutorial"]
date = "2017-05-08T22:08:35+02:00"
tags = ["tutorial", "kubernetes", "docker", "containers", "cluster"]
title = "Kubernetes Basics"

+++

## What is Kubernetes

By definition, Kubernetes is an open source container cluster manager, and it is
usually referred to by its internal name withing Google development - **k8s**.
Google donated it to the open source world as a *"seed technology"* at 2015, to
the newly formed *CNCF - Cloud Native Computing Foundation*, which established
partnership with *The Linux Foundation*. The primary goal of Kubernetes is to
provide a platform for automating deployment, scaling and operations of
application containers across a cluster of hosts. In fact, withing Google they
have been using Kubernetes-like tools in order to run daily billions of
containers within their services.

### Design Overview

Kubernetes is built through a set of components (building blocks or
*primitives*), which when they are used collectively, then they provide a
method for the deployment, maintenance and scalability or container based
application clusters. These *primitives* are designed to operate without
requiring any kind of special knowledge from the user. They are really easy to
work with and they are also highly extensible through an API. All the
components of Kubernetes (internal, extensions and containers) are making use
of the API.

Although Kubernetes was originally designed withing Google's infrastructure,
nowadays it's considered the default option for other majer public cloud
providers, such as AWS and Azure.

### Components

So, what are the components (building blocks) that are going into to
Kubernetes:

* Nodes (often referred to as minions)
* Pods
* Labels
* Selectors
* Controllers (multiple kinds of them)
* Services
* Control Pane (the master controller)
* API

Some of these topics are relatively involved, so you need to practice by
yourself and manage your own Kubernetes environment, in order to be able to
understand at 'experience' level, how these things work.

### Architecture

In a very-very high-level view, we have these kubernetes building-blocks we
talked about. This is really how the whole environment looks like:

![Kubernetes Architecture](/images/kubernetes_architecture.png)

We have *one* **master/controller**  and we have *1-to-N* **nodes** which can
have *1-to-N* **pods** and each pod can have *1-to-N* **containers**. How many
of those *N* things you need, it is based upon the desired state of the
configuration which is located in the *master/controller* via *YAML* form.
Also, this depends on the minion resources (either physical or virtual) that
you can allocate.

Each node has to have at least some container management engine installed, such
as Docker.

#### Nodes (Minions)

You can think of these as *container clients* and they can be either physical
or virtual. Also, your container management engine has to be installed on, (such
as Docker) and hosts the various containers within your managed cluster.

Furthermore, each minion will run **ETCD**, as well as the *master/controller*.
ETCD is a key-pair management and communication service, used by Kubernetes
for exchanging messages and reporting on cluster status. It's a way for us to
keep everything in-sync and exchange information from the individual minions to
our master controller and as well as our Kubernetes Proxy -- that's the other
item that runs on each of the minions. So, for each minion there are two things
that are running and are specific to Kubernetes, which is ETCD and Kubernetes
Proxy, and last but not least, Docker has to be installed as well. During this
tutorial we will go over all these packages and install them.

#### Pods

The simplest definition is that a pod consists of one or more containers. Going
further, these containers are then guaranteed (by the master controller) to be
located on the same host machine in order to facilitate shared resources
(volumes, services mapped through ports). Pods are assigned with unique IPs
within each cluster, so these allow our application to use ports for the Pod
without having to worry about conflicting port utilization. In another words, I
can have multiple Pods running at port `80` or `443` or `whatever`, on the same
host, because I am not re-mapping those ports but I am giving each Pod a unique
IP address within the cluster, so I don't have to worry about port conflicts.

Pods can contain definitions of disk volumes or share, and then provide
access from those to all the containers within the pod.

An the finally, pod management is done through the API or delegated to a
controller.

#### Labels

Clients can attach "key-value pairs" to any object in the system (like Pods or
Nodes). These become the labels that identify them in the configuration and
management of them. And this is where *Selectors* come in, because they are
used in conjuction.

#### Selectors

Label Selectors represent queries that are made against those labels. They
resolve to the corresponding matching objects and will show when we are
managing our Pods in our cluster how we use the built-in API and tools for
Kubernetes in order to get a selection of objects based on these label
selectors.

These two items (Labels and Selectors) are the primary way that grouping is
done in Kubernetes and determine which components that a given operation
applies to when indicated.

#### Controllers

These are used in the management of your cluster. Controllers are the mechanism
by which your desired configuration state is enforced. In fact the controllers
main purpose is to enforce the desired state of your configuration to your
cluster. They manage a set of pods and, depending on the desired configuration
state, may engage other controllers to handle replication and scaling (through the
**Replication Controller**) of XX number of containers and pods across the cluster.
It is also responsible for replacing any container in a pod that fails or any
container in the cluster that fails (based on the desired state of the cluster).
And again, all these are representing a desired state written in YAML files.

Other controllers that can be engaged include **DaemonSet Controller** which
enforces a 1:1 ration of pods to minions and a **Job Controller** that runs
pods to "completion", such as in batch jobs. Each set of pods any controller
manages, is determined by the label selectors that are part of its definition.

## Setup and Configuration

### Packages and Dependencies

One of the first things we need to do is to install NTP. NTP has to be 
enabled and running in **all** of the servers we are going to have in
our cluster. In this example, I have four terminals open:

```
- centos-master		[172.31.28.38] 		[54.154.199.96]
- centos-minion1	[172.31.120.121]	[54.171.6.143]
- centos-minion2	[54.246.160.157]	[172.31.110.96]
- centos-minion3	[54.246.220.156]	[172.31.23.169]
```

So we are going to use 3 minions as worker nodes, and then 1 server as the
master in our cluster. So, lets us install ntp:

```bash
yum install -y ntp
```

We want to be sure that all the servers in our cluster are time-synchronised
down to the second. This is because we are going to use a service that logs
what happen to our cluster upon special conditions and it is important that
our servers are reporting as close and as accurate as possible.

```bash
systemctl enable ntpd
systemctl start ntpd
```

Feel free to check the status in order to verify that is running:

```bash
systemctl status ntpd
```

As soon as we finish with the installation of `ntp` in all of our servers in
the cluster, then we need to make sure that we have full name resolution for
the servers in our environment. If you are installing this locally and you
do not port-forward this ports externally, then it is best to use your internal
IP addresses rather than the external ones. Similarly, this means that you cannot
use the name of the server, because this will refer to the external IP address.
But, to make things look as they supposed to be, I am going to create a file
`/etc/hosts` with the corrersponding nickname of these servers. This file has to
be into each server that is part of my cluster and it has to resolve the nicknames
against the internal/private IP address. In that case, I will be able to use those
internal hostnames in my configuration file:

```bash
vim /etc/hosts

172.31.28.38    centos-master
172.31.120.121  centos-minion1
172.31.110.96   centos-minion2
172.31.23.169   centos-minion3
```

Put this into every server and then make sure that all of them can ping each other
based on those nicknames:

```bash
ping centos-master
ping centos-minion1
ping centos-minion2
ping centos-minion3
```

As soon as you finished this and your verified that all server can ping each other
based on their internal IP address, it is about time to add a repository that we
can use to install the latest version of `Docker` and `Kubernetes`.

```bash
vim /etc/yum.repos.d/virt7-docker-common-release.repo
[virt7-docker-common-release]
name=virt7-docker-common-release
baseurl=https://cbs.centos.org/repos/virt7-docker-common-release/x86_64/os/
gpgcheck=0
```

Save it and then update the cache of the system:

```bash
yum update
```

Make sure you do this for all the server in the cluster.

Next, make sure that all firewalls are disabled, since this is a demo and not
a production environment, so we need to avoid problems of port filtering.

```bash
systemctl status iptables  --> disabled
systemctl status firewalld --> disabled
```

Ok, now it is about time to install `etcd`. This is the mechanism that helps
all the members of the cluster to communicate and advertise their status,
availability, and their logs. So, we need to install `etcd` and `kubernetes`.
These two, will also pull `cadvisor` which for containers and containerized
apps. Then we will, start configuring the master and the minion, but right
now I will finish by installing the software:

```
yum install -y --enablerepo=virt7-docker-common-release kubernetes docker
```

### Configure the Master

Since we are into the master, we first need to configure the Kubernetes
itself:

```bash
vim /etc/kubernetes/config

# If you want to log errors in the systemd-journal for Kubernetes
KUBE_LOGTOSTDERR="--logtostderr=true"

# If you want to have debug level log files in your systemd journal
# 0 is the most verbose (debug level)
KUBE_LOG_LEVEL="--v=0"

# Disable privileged docker containers within the cluster
KUBE_ALLOW_PRIV="--allow-privileged=false"

# Define the API Server
# How the controller-manager, scheduler, and proxy find the apiserver
KUBE_MASTER="--master=https://centos-master:8080"

# Define the ETCD Server
KUBE_ETCD_SERVER="--etcd-servers=https://centos-master:2379"
```

This is the initial configuration for our master kubernetes node. Notice
that I used domain names, and not IP address, in that way if the IP address
of the Kubernetes ETCD server changes, the cluster will still be able to
resolve it, using the DNS server.

#### Configure ETCD

Install it:

```bash
yum install -y etcd
```

Configure it:

```bash
vim /etc/etcd/etcd.conf

# It is OK to leave these two with their default values
ETCD_NAME=default
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"

# Listen on all interfaces and accept connections from anywhere
ETCD_LISTEN_CLIENT_URLS="https://0.0.0.0:2379"

# Listen on all interfaces and accept connections from anywhere
ETCD_ADVERTISE_CLIENT_URLS="https://0.0.0.0:2379"
```

The master kubernetes nodes is the only place where we are going
to be running ETCD.

#### Configure API

```bash
vim /etc/kubernetes/apiserver

# Accept connections from all interfaces
KUBE_API_ADDRESS="--address=0.0.0.0"

# Make sure that port for API is listening on 8080
KUBE_API_PORT="--port=8080"

# Make sure that port for Kubelet is listing on 10250
KUBELET_PORT="--kubelet-port=10250"

# Comma separated list of nodes in the etcd cluster
KUBE_ETCD_SERVERS="--etcd-servers=https://127.0.0.1:2379"

# Address range to use for services (Feel free to change it based on your environment)
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"

# Add your own!
KUBE_API_ARGS=""
```

#### Start the services

First, you need to start with `etcd`:

```bash
systemctl enable etcd
systemctl start etcd
systemctl status etcd
```

Then, follow up with `kube-apiserver`:

```bash
systemctl enable kube-apiserver
systemctl start kube-apiserver
systemctl status kube-apiserver
```

Follow up with `kube controller manager`:

```bash
systemctl enable kube-controller-manager
systemctl start kube-controller-manager
systemctl status kube-controller-manager
```

Last, `kube-scheduler`:
```bash
systemctl enable kube-scheduler
systemctl start kube-scheduler
systemctl status kube-scheduler
```

Make sure that all of these 4 services are started. They **have** to be up and running
otherwise, it makes no sense to ignore them and configure the minions. This is the univeral
configuration for our cluster.

### Configure Minions

The following configuration has to be applied to all the minions
of the cluster. The first thing we want to do is to apply our
Kubernetes configuration:

```bash
vim /etc/kubernetes/config
# logging to stderr means we get it in the systemd journal
KUBE_LOGTOSTDERR="--logtostderr=true"

# journal message level, 0 is debug
KUBE_LOG_LEVEL="--v=0"

# Disable privileged docker containers from running into the cluster
KUBE_ALLOW_PRIV="--allow-privileged=false"

# How the minion talks with the API Server
KUBE_MASTER="--master=https://centos-master:8080"

# How the minion talks with the ETCD Server
KUBE_ETCD_SERVERe="--etcd-servers=https://centos-master:2379"
```

Next, we are going to edit the `kubelet` configuration:

```bash
vim /etc/kubernetes/kubelet

# kubernetes kubelet (minion) config

# The address for the info server to serve on (set to 0.0.0.0 or "" for all interfaces)
KUBELET_ADDRESS="--address=0.0.0.0"

# The port for the info server to serve on (it has to corresponds the port of the master)
KUBELET_PORT="--port=10250"

# You may leave this blank to use the actual hostname
KUBELET_HOSTNAME="--hostname-override=centos-minion1"

# location of the api-server
KUBELET_API_SERVER="--api-servers=https://centos-master:8080"

# Add your own!
KUBELET_ARGS=""
```


Now start and enable the services:

```bash
systemctl enable kube-proxy
systemctl start kube-proxy
systemctl status kube-proxy
```

```bash
systemctl enable kubelet
systemctl start kubelet
systemctl status kubelet
```

```bash
systemctl enable docker
systemctl start docker
systemctl status docker
```

As soon as we verify that all of the are working as expedted, now we have
to verify also that docker works. To do, I am going to use a simple
containerized app, called `hello world` -- what a surprise.

```bash
docker pull hello-world
docker images
docker run hello-world
docker ps
docker ps -a
```

Now we have our minion configuration complete and actually it has to
be registered against our master. Please make sure that the same config
exists in the rest 2 minions, before you proceed.

### Interact with the cluster

The main utility for interacting with the kubernetes cluster, is called
`kubectl` -- kubecontrol.

```bash
man kubectl
```

Usually, either you **get** sth or **set** something. For example,
if you want to see the nodes which are registerested againsto our
master:

```bash
kubectl get nodes
```

But, how do I know what are the potential parameteres for that command?

```bash
man kubectl-get
```

For example, I can get some information about those nodes:

```bash
kubectl describe nodes
```

I can also request this in JSON format:

```bash
kubectl get nodes -o jsonpath='pattern'
```

In the future, we will do `kubectl get pods`. A minion is a node
that is registered in our cluster in which we can install pods on.
Pods contain containers of things, such as services (apache, ngix, etc).

## Run Containers in Pods

So, after having our environment set and all of our nodes are registered
against the master node, it is about time to run containers inside of
Pod in our cluster. For now, we are going to go through the initial
configuration of setting up Pods in our 3 minions. For the shake of
less complexity, I am going to turn-off the 2 out of the 3 minions,
so I am going to to deploy Pods into a single node.

```bash
[root@drpaneas1 ~]# kubectl get nodes
NAME             STATUS     AGE
centos-minion1   Ready      19h
centos-minion2   NotReady   19h
centos-minion3   NotReady   19h
```

As I said, 3 minions are registered, but only one of them is ready
to use.

### Create a Pod

First of all, we need to create a Build directory:

```bash
mkdir Builds
cd Builds
```

Now there are two ways that we can begin to generate Pods which will
contain Docker containers in our environment.

1. We can create configuration file using JSON
2. We can create configuration file using YAML

From the configuration point of view, I am going to focus only to YAML.
From a definition stand point, YAML is better for configuration and
JSON is preffered as output. But, for input and configuration, I like
to use YAML because I think it is simpler to use.

So, to create a Pod, we need to create a *definition*. So, *keep in mind*
that a Pod Definition is like telling Kubernetes the *desired state of 
our Pod*. It is really important to understand that the desired state
is a key concept, because it is the key reponsibility of Kubernetes to
ensure that the current state of the cluster matches the defined as
desired state. So, if any of the things in desired state is not functioning
then it us up to Kubernetes to relocate them or recreated them in order
to drive our cluster to the desired state until the administrator says
otherwise (e.g. delete the Pod). So, I am going to create a very simple
configuration for out first Pod, a `nginx` yaml configuration and also
follow the examples from kubernetes documentation. Make sure you are
into the `Builds` directory and create our first Pod definition:

```bash
vim nginx.yaml
```

I will create a Pod that has just one single container in it. The Pod will
be named after `nginx` and so does the container also. In the container, I
would like to run `nginx version 1.7.9` and port forward (expose) `TCP 80`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.7.9
    ports:
    - containerPort: 80
```

Now, if you remember, using `kubectl` we can see what `pods` we have. So, right
now we should not have any pods created yet. Also, if I go to our minion and
look for currently active containers `docker ps` there will be none. So, the
current state is that I have no `pods`, no `services`, no `replication controllers`.
So, now, I am going to launch a Pod within my cluster, and Kubernetes is going
to determine based on the current available worker nodes (minions) where to launch
the container. It is very easy to do:

```bash
kubectl create -f ./nginx.yaml
pod "nginx" created
```

So, if I check for Pod now in my cluster:

```bash
# kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE
nginx     1/1       Running   0          26s
```

As you can see, my Pod called `nginx` is already running. Let us go to the minion
and verify that the container `nginx` is also running:

```bash
[root@drpaneas2 ~]# docker ps
CONTAINER ID        IMAGE                                      COMMAND                  CREATED              STATUS              PORTS               NAMES
9fc275cd7597        nginx:1.7.9                                "nginx -g 'daemon off"   About a minute ago   Up About a minute                       k8s_nginx.b0df00ef_nginx_default_d4dfb568-45ec-11e7-91f
e-0a35c9149e00_ece8325b
bef1f611ff9b        gcr.io/google_containers/pause-amd64:3.0   "/pause"                 About a minute ago   Up About a minute                       k8s_POD.b2390301_nginx_default_d4dfb568-45ec-11e7-91fe-
0a35c9149e00_3ce7af06
```

Now there is our `nginx` container, but there is also another container that is
neccessarry for Kubernetes, which is a `google_container` and it is under `pause`.
If for example we want describe our current Pod, we can do:

```bash
[root@drpaneas1 Builds]# kubectl describe pod nginx
Name:           nginx
Namespace:      default
Node:           centos-minion1/172.31.120.121
Start Time:     Wed, 31 May 2017 10:35:14 +0000
Labels:         <none>
Status:         Running
IP:             172.17.0.2
Controllers:    <none>
Containers:
  nginx:
    Container ID:               docker://9fc275cd7597e315a90826ac4558a5120fdca913bcc46e2895c608d0a0c36c1c
    Image:                      nginx:1.7.9
    Image ID:                   docker-pullable://docker.io/nginx@sha256:e3456c851a152494c3e4ff5fcc26f240206abac0c9d794affb40e0714846c451
    Port:                       80/TCP
    State:                      Running
      Started:                  Wed, 31 May 2017 10:35:31 +0000
    Ready:                      True
    Restart Count:              0
    Volume Mounts:              <none>
    Environment Variables:      <none>
Conditions:
  Type          Status
  Initialized   True 
  Ready         True 
  PodScheduled  True 
No volumes.
QoS Class:      BestEffort
Tolerations:    <none>
Events:
  FirstSeen     LastSeen        Count   From                            SubObjectPath           Type 	     	 Reason                   Message
  ---------     --------        -----   ----                            -------------           --------     	 ------                   -------
  4m            4m              1       {default-scheduler }                                    Normal           Scheduled 	          Successfully assigned nginx to centos-minion1
  4m            4m              1       {kubelet centos-minion1}        spec.containers{nginx}  Normal           Pulling           	  pulling image "nginx:1.7.9"
  4m            4m              2       {kubelet centos-minion1}                                Warning          MissingClusterDNS        kubelet does not have ClusterDNS IP configured and cannot create Pod using "ClusterFirst" policy. Falling back to DNSDefault policy.
  4m            4m              1       {kubelet centos-minion1}        spec.containers{nginx}  Normal           Pulled                  Successfully pulled image "nginx:1.7.9"
  4m            4m              1       {kubelet centos-minion1}        spec.containers{nginx}  Normal           Created                 Created container with docker id 9fc275cd7597; Security:[seccomp=unconfined]
  4m            4m              1       {kubelet centos-minion1}        spec.containers{nginx}  Normal           Started                 Started container with docker id 9fc275cd7597
```

Some important information here is that you see the docker container `ID`
that is running, the `minion` that is running and its IP Address. So far
there are no `labels`, no `controllers` (e.g. we are not doing any
replication). Just to be clear though:

```bash
# kubectl describe pod nginx | grep 'Node:\|IP:'
Node:           centos-minion1/172.31.120.121 <-- IP of the minion
IP:             172.17.0.2 <-- IP of the container inside the Pod
```

So, can I do anything with the IP of the container?

```bash
# ping 172.17.0.2
PING 172.17.0.2 (172.17.0.2) 56(84) bytes of data.
^C
--- 172.17.0.2 ping statistics ---
20 packets transmitted, 0 received, 100% packet loss, time 18999ms
```

The answer is *No*. There is no route externally to that Pod. But what
I can do, is to run other containers within my Pod and as long as they
are in the same host they can see those containers which are defined
within that Pod. So, I am going to run another container: `busybox` image.
This is very minimal installation of Linux running Busybox, that will
allows us to connect/test our `nginx` container.

Instead of creating a proper YAML file, this is just a shortcut, mostly
because this is just for test reasons. So this is going to create a Pod
called `busybox` and create also inside of it a docker container with
the docker image `--image=busybox` and it will be also be
an ephemeral `--restart=Never`. As soon as it will be ready it will be
spawn interactivly here `--tty -i` and it runs in api version 1.

```bash
[root@drpaneas1 Builds]# kubectl run busybox --image=busybox --restart=Never --tty -i --generator=run-
pod/v1
Waiting for pod default/busybox to be running, status is Pending, pod ready: false
Waiting for pod default/busybox to be running, status is Pending, pod ready: false
If you dont see a command prompt, try pressing enter.
/ # 
```

So, now we have two Pods into the same minion:

```bash
[root@drpaneas1 ~]# kubectl get nodes
NAME             STATUS     AGE
centos-minion1   Ready      20h
centos-minion2   NotReady   20h
centos-minion3   NotReady   20h

[root@drpaneas1 ~]# kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE
busybox   1/1       Running   0          14m
nginx     1/1       Running   0          44m
```

This command prompt indicates that I am actually in the Pod `busybox` running a
container in it. The point is that this container can now see the `nginx`

```bash
/ # wget --quiet --output-document - https://172.17.0.2
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
<p>For online documentation and support please refer to
<a href="https://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="https://nginx.com/">nginx.com</a>.</p>
<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

In order to delete the `busybox` Pod, first we `exit` and then we issue
the `delete` command:

```bash
[root@drpaneas1 Builds]# kubectl delete pod busybox
pod "busybox" deleted
```

So now if we go back to the minion and look for the busybox container, we will
see that it has been already stopped:

```bash
[root@drpaneas2 ~]# docker ps
CONTAINER ID        IMAGE                                      COMMAND                  CREATED             STATUS              PORTS               NAMES
9fc275cd7597        nginx:1.7.9                                "nginx -g 'daemon off"   47 minutes ago      Up 47 minutes                           k8s_nginx.b0df00ef_nginx_default_d4dfb568-45ec-11e7-91fe-0a35c9149e00_ece8325b
bef1f611ff9b        gcr.io/google_containers/pause-amd64:3.0   "/pause"                 47 minutes ago      Up 47 minutes                           k8s_POD.b2390301_nginx_default_d4dfb568-45ec-11e7-91fe-0a35c9149e00_3ce7af06
```
Now let us also remove the nginx container:

``bash
kubectl delete pod nginx
[root@drpaneas1 Builds]# kubectl delete pod nginx
pod "nginx" deleted
```

I can also `cheat` in a way in order to get access to the services that might be
running on one of my containers. This is by port-forwarding locally to a remote
copy of what happens to be happen within our Pod. So, because we already removed
the `nginx` pod. I am going to create one again:

```bash
[root@drpaneas1 Builds]# kubectl create -f ./nginx.yaml 
pod "nginx" created
[root@drpaneas1 Builds]# kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE
nginx     1/1       Running   0          17s
```

So, now let us port forward it locally:

```bash
[root@drpaneas1 Builds]# kubectl port-forward nginx :80 &
[1] 2512
[root@drpaneas1 Builds]# Forwarding from 127.0.0.1:43873 -> 80
Forwarding from [::1]:43873 -> 80
```

As you can see I am now port forwarding the port 80 from the Pod
`nginx` into my local port `43873`. So, I should be able to do:

```bash
[root@drpaneas1 Builds]# curl https://localhost:43873
Handling connection for 43873
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
<p>For online documentation and support please refer to
<a href="https://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="https://nginx.com/">nginx.com</a>.</p>
<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

So now we have a Pod Definition created but one of the things we do not have
is an easy way to talk about what that Pod is all about and what it might
contain. So, I am goin to apply labels and selectors.

### Labels and Selectors

Labels are often reffered to as `tags` in order to differentiate more easily
the Pods running in our system. Because you might run some thousands of Pods
in your system, so it makes sense to apply some common naming scheme to know
how you can sort the information that is available. All that a label does
is to give us a easy-readable plain text to something we can refer to later.
It is a key value that we can also define in our YAML file, and we can also
use it later to get or set information.

```bash
# cp nginx.yaml nginx-pod-label.yaml 
[root@drpaneas1 Builds]# vim nginx-pod-label.yam
```

All we are going to add is a section `labels` and give a name for the `app`
that we are going to run (in that case `nginx`).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.7.9
    ports:
    - containerPort: 80
```

And create the Pod:

```bash
[root@drpaneas1 Builds]# kubectl create -f nginx-pod-label.yaml 
pod "nginx" created
[root@drpaneas1 Builds]# kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE
nginx     1/1       Running   0          9s
```

Now, what I can do (that I could not do it before) is to ask
for a specific key-value pair, called `nginx`:

```bash
[root@drpaneas1 Builds]# kubectl get pods -l app=nginx
NAME      READY     STATUS    RESTARTS   AGE
nginx     1/1       Running   0          1m
```

Let us create another nginx app:

```bash
[root@drpaneas1 Builds]# cp nginx-pod-label.yaml nginx2-pod-label.yaml 
[root@drpaneas1 Builds]# vim nginx2-pod-label.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: nginx2
  labels:
    app: nginx2
spec:
  containers:
  - name: nginx2
    image: nginx:1.7.9
    ports:
    - containerPort: 80
```

As you can see I had to change `nginx` into `nginx2`. Let us create is also:

```bash
[root@drpaneas1 Builds]# kubectl create -f nginx2-pod-label.yaml 
pod "nginx2" created
[root@drpaneas1 Builds]# kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE
nginx     1/1       Running   0          4m
nginx2    1/1       Running   0          9s
```

This also means that in our minion, we are running now 4 containers:

```bash
[root@drpaneas2 ~]# docker ps
CONTAINER ID        IMAGE                                      COMMAND                  CREATED             STATUS              PORTS               NAMES
f9007379f757        nginx:1.7.9                                "nginx -g 'daemon off"   50 seconds ago      Up 49 seconds                           k8s_nginx2.428f0121_nginx2_default_5f91234f-45f6-11e7-91fe-0a35c9149e00_ad9421e1
75c528f64f3f        gcr.io/google_containers/pause-amd64:3.0   "/pause"                 50 seconds ago      Up 49 seconds                           k8s_POD.b2390301_nginx2_default_5f91234f-45f6-11e7-91fe-0a35c9149e00_1cf67320
b1582754a595        nginx:1.7.9                                "nginx -g 'daemon off"   5 minutes ago       Up 5 minutes                            k8s_nginx.b0df00ef_nginx_default_b4dcc3c9-45f5-11e7-91fe-0a35c9149e00_8810d6a3
e98169846a83        gcr.io/google_containers/pause-amd64:3.0   "/pause"                 5 minutes ago       Up 5 minutes                            k8s_POD.b2390301_nginx_default_b4dcc3c9-45f5-11e7-91fe-0a35c9149e00_e2f1104f
```

So, why would I do it that way? We might have thousands of pods running.
So let us use again the listing for the `app` key-pair-value:

```bash
[root@drpaneas1 Builds]# kubectl get pods -l app=nginx2
NAME      READY     STATUS    RESTARTS   AGE
nginx2    1/1       Running   0          2m
```

This is cool, because now I can only get the description per app, in that
case `nginx2`:

```bash
[root@drpaneas1 Builds]# kubectl describe pods -l app=nginx2
Name:           nginx2
Namespace:      default
Node:           centos-minion1/172.31.120.121
Start Time:     Wed, 31 May 2017 11:43:32 +0000
Labels:         app=nginx2
Status:         Running
IP:             172.17.0.3
Controllers:    <none>
Containers:
  nginx2:
    Container ID:               docker://f9007379f7572c49769164d9b31d9814cd30404ab93c8b73258b672fba449205
    Image:                      nginx:1.7.9
    Image ID:                   docker-pullable://docker.io/nginx@sha256:e3456c851a152494c3e4ff5fcc26f240206abac0c9d794affb40e0714846c451
    Port:                       80/TCP
    State:                      Running
      Started:                  Wed, 31 May 2017 11:43:33 +0000
    Ready:                      True
    Restart Count:              0
    Volume Mounts:              <none>
    Environment Variables:      <none>
Conditions:
  Type          Status
  Initialized   True 
  Ready         True 
  PodScheduled  True 
No volumes.
QoS Class:      BestEffort
Tolerations:    <none>
Events:
  FirstSeen     LastSeen        Count   From                            SubObjectPath           Type 		Reason                   Message
  ---------     --------        -----   ----                            -------------           --------      	------      	         -------
  4m            4m              1       {default-scheduler }                                    Normal		Scheduled               Successfully assigned nginx2 to centos-minion1
  4m            4m              2       {kubelet centos-minion1}                                Warning         MissingClusterDNS       kubelet does not have ClusterDNS IP configured and cannot create Pod using "ClusterFirst" policy. Falling back to DNSDefault policy.
  4m            4m              1       {kubelet centos-minion1}        spec.containers{nginx2} Normal		Pulled                  Container image "nginx:1.7.9" already present on machine
  4m            4m              1       {kubelet centos-minion1}        spec.containers{nginx2} Normal		Created                 Created container with docker id f9007379f757; Security:[seccomp=unconfined]
  4m            4m              1       {kubelet centos-minion1}        spec.containers{nginx2} Normal		Started                 Started container with docker id f9007379f757
```

This is an easy way to refer to complex infrastucture that I am  virtualizing as
a container in my cluster. So these tags or labels are what is called selectors
when we are getting information or when we apply information to a pod. This is because
we can selectively apply things like deployments to a specific Pod in my environment.
That is all what labels are for, to differentiate key-value pairs in YAML that later
I can identify various parts. We can assign any label we want that we can refer to later.

### Deployment

One of the advantages of labelling is that we can use deployment type. Before, we just
launched a Pod, but now we are going to launch a Deployment. The reason we are going to
differenciate launching a Pod from a Deployment is because it gives us felxibility 
and easier management over our cluter. This means that we are going to deploy a Pod
that is goint to be a *production* `nginx server` container, and then we are going to
deploy one that is going to be the development. Then we are going to label them
appropriately so we can update one, and not the other. So let us copy the current
configuration and modify it later on:

```bash
cp nginx-pod-label.yaml nginx-deployment-prod.yaml
```

Well, obviously the `kind` is going to change from `Pod` into `Deployment`, but before
we do that, we have to change the `API` version. This is because we are not going to 
use the standard API but some of the extensions which is available for Kubernetes.
This extension gives us the ability to create a kind of deployment, as right now is
only available to beta. Then, we are going to change the name into `nginx-deployment-prod`
and also the same for the `app`. In addition, we are going to introduce a new key-value
per, called `replicas` because deployments usually deploy multiple Pods in the same time.
However, currently we just need only 1. The next thing we are going to add is a `template`.
In this way, I am going to create `metadata` that are going to be specific to this item
(template). All the others are intendted into the template. In that way we converted a
Pod definition into a production deployment.

```bash
vim nginx-deployment-prod.yaml

[root@drpaneas1 Builds]# cat nginx-deployment-prod.yaml 
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-deployment-prod
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx-deployment-prod
    spec:
     containers:
     - name: nginx
       image: nginx:1.7.9
       ports:
       - containerPort: 80
```

Now let us create the deployment and list our Pods:

```bash
[root@drpaneas1 Builds]# kubectl create -f nginx-deployment-prod.yaml 
[root@drpaneas1 Builds]# kubectl get pods
NAME                                    READY     STATUS    RESTARTS   AGE
nginx                                   1/1       Running   0          2h
nginx-deployment-prod-872137609-z8n9m   1/1       Running   0          24s
nginx2                                  1/1       Running   0          2h
```

Do you notice that next to the name, there is a `-872137609-z8n9m` string? Why is that?
This is because it ends with the ID of the deployment:

```bash
[root@drpaneas1 Builds]# kubectl get deployments
NAME                    DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment-prod   1         1         1            1           1m
```

So now I have a deployment called `nginx-deployment-prod` which has a Pod
called `nginx-deployment-prod-872137609-z8n9m`, which runs an `nginx` 
container. Looks like we made things even more complicated ... Indeed.
This is because nobody uses a deployment structure for just one nod
with just one worker, with just one container. So, let us create another
deployment so to see the benefit of it:

```bash
# cp nginx-deployment-prod.yaml nginx-deployment-dev.yaml
```

And let just modify the `nginx-deployment-prod` into `nginx-deployment-dev`.

```bash
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-deployment-dev
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx-deployment-dev
    spec:
     containers:
     - name: nginx
       image: nginx:1.7.9
       ports:
       - containerPort: 80
```

So, now both deployments are running:

```bash
[root@drpaneas1 Builds]# kubectl get deployments
NAME                    DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment-dev    1         1         1            1           15s
nginx-deployment-prod   1         1         1            1           7m
```

and I can also do:

```bash
[root@drpaneas1 Builds]# kubectl describe deployments -l app=nginx-deployment-dev
Name:                   nginx-deployment-dev
Namespace:              default
CreationTimestamp:      Wed, 31 May 2017 14:45:33 +0000
Labels:                 app=nginx-deployment-dev
Selector:               app=nginx-deployment-dev
Replicas:               1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  1 max unavailable, 1 max surge
Conditions:
  Type          Status  Reason
  ----          ------  ------
  Available     True    MinimumReplicasAvailable
OldReplicaSets: <none>
NewReplicaSet:  nginx-deployment-dev-3607872275 (1/1 replicas created)
Events:
  FirstSeen     LastSeen        Count   From                            SubObjectPath   Type            Reason                  Message
  ---------     --------        -----   ----                            -------------   --------        ------                  -------
  1m            1m              1       {deployment-controller }                        Normal          ScalingReplicaSet       Scaled up replica set nginx-deployment-dev-3607872275 to 1
```

So, we have 4 containers runnings, the dev and the prod. Why we did that?
By using the deployment type, we can now do updates to any of our pods
just by applying a deployment update to that specific pod. What this means?
For example, we are going to update the `nginx` version to 1.8.

```bash
# cp nginx-deployment-dev.yaml nginx-deployment-dev-update.yaml
```

All we want to do is to update the nginx version from 1.7.9 up to 1.8 and I
am going to do that by changing the image. Everything else will be the same.

```bash
vim nginx-deployment-dev-update.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-deployment-dev
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx-deployment-dev
    spec:
     containers:
     - name: nginx
       image: nginx:1.8
       ports:
       - containerPort: 80
```

In that way we are going to `apply` this change into our `dev` deployment:

```bash
# kubectl apply -f nginx-deployment-dev-update.yaml 
deployment "nginx-deployment-dev" configured
```

Now, the deployment has successfully created the Pod that now runs a 
container with `nginx 1.8`. To verify this:

```bash
# kubectl describe deployments -l app=nginx-deployment-dev
Name:                   nginx-deployment-dev
Namespace:              default
CreationTimestamp:      Wed, 31 May 2017 14:45:33 +0000
Labels:                 app=nginx-deployment-dev
Selector:               app=nginx-deployment-dev
Replicas:               1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  1 max unavailable, 1 max surge
Conditions:
  Type          Status  Reason
  ----          ------  ------
  Available     True    MinimumReplicasAvailable
OldReplicaSets: <none>
NewReplicaSet:  nginx-deployment-dev-3767386797 (1/1 replicas created)
Events:
  FirstSeen     LastSeen        Count   From                            SubObjectPath   Type            Reason                  Message
  ---------     --------        -----   ----                            -------------   --------        ------                  -------
  13m           13m             1       {deployment-controller }                        Normal          ScalingReplicaSet       Scaled up replica set nginx-deployment-dev-3607872275 to 1
  6m            6m              1       {deployment-controller }                        Normal          ScalingReplicaSet       Scaled up replica set nginx-deployment-dev-3767386797 to 1
  6m            6m              1       {deployment-controller }                        Normal          ScalingReplicaSet       Scaled down replica set nginx-deployment-dev-3607872275 to 0
```

As you can see the `StrategyType` has changed into `RollingUpdate` and the
`Replicas` say `1 updates` which means that it got succeded. Of course if
we had mutliple replicas running, they will be updated as well. So, with one
command I would be able to update the whole container infrastructure even
though running in multiple places.

### Replication Controller

So far, we have been using only one Pod, but it is about time to use
multiple pod (containers). There are two ways to run a Pod, either via
a deployment or directly by referring to the Pod. The first way allows
us to have multiple containers doing different things, for example
you have a layered application running within a Pod, so you have a
webserver and a fileserver and also a database server, and I use
server in terms of individual containers. All those three run in a Pod,
and this Pod might be called a webserver environment. Howerver, the
second thing that you can do is t haty ou  can run multiple containers
within a Pod, or at least you can defined multiuple containers within
a single definition. They way we do that, is something called the
replication controller. This is a different type of `kind` of the deployment
kind in order to deploy 1-N pods for a particular container.

First of all, let us start the other two minions. Just make sure that the
VMs are online and `kubelet`, `kube-proxy` services are running:

```bash
systemctl start kubelet kube-proxy
```

then make sure you can see their online status from the master node:

```bash
# kubectl get nodes
NAME             STATUS    AGE
centos-minion1   Ready     1d
centos-minion2   Ready     1d
centos-minion3   Ready     1d
```

Now let us create the configuration:

```bash
vim nginx-multi-label.yaml
```

As I said earlier, we are going to use a different kind of kind, called
`ReplicationController`. Then we define the name of this one as `nginx-www`
and then we are writing the specifications. Over there, the first thing we do
is to specify the `replicas`. In this case I am going to use *3* Pods per
selector. Speaking of selector, we specify it as `app: nginx`. Next, we
define our template. Nothing new here. In the end, the file looks like this:

```bash
# cat nginx-multi-label.yaml 
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx-www
spec:
  replicas: 3
  selector:
    app: nginx
  template:
    metadata:
      name: nginx
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```

Fire this up:

```bash
[root@drpaneas1 Builds]# kubectl create -f nginx-multi-label.yaml 
replicationcontroller "nginx-www" created
```

Now if I ask for the pods:

```bash
[root@drpaneas1 Builds]# kubectl get pods
NAME              READY     STATUS    RESTARTS   AGE
nginx-www-m8x9q   1/1       Running   0          9m
nginx-www-vkvw5   1/1       Running   0          9m
nginx-www-xvjvb   1/1       Running   0          9m
```

I see 3 replicated copies being deployed all three of our container
in all of three of our minions.

```bash
# kubectl get pods
NAME              READY     STATUS    RESTARTS   AGE
nginx-www-m8x9q   1/1       Running   0          9m
nginx-www-vkvw5   1/1       Running   0          9m
nginx-www-xvjvb   1/1       Running   0          9m

[root@drpaneas1 Builds]# kubectl describe replicationcontroller
Name:           nginx-www
Namespace:      default
Image(s):       nginx
Selector:       app=nginx
Labels:         app=nginx
Replicas:       3 current / 3 desired
Pods Status:    3 Running / 0 Waiting / 0 Succeeded / 0 Failed
No volumes.
Events:
  FirstSeen     LastSeen        Count   From                            SubObjectPath   Type            Reason                  Message
  ---------     --------        -----   ----                            -------------   --------        ------                  -------
  10m           10m             1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginx-www-xvjvb
  10m           10m             1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginx-www-vkvw5
  10m           10m             1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginx-www-m8x9q
```

The replication controller tells me that I have 3 of these running,
but Ialso have 3 pods.

```bash
# kubectl describe pods | grep Node
Node:           centos-minion3/172.31.23.169
Node:           centos-minion2/172.31.110.96
Node:           centos-minion1/172.31.120.121
```

As you can see, these 3 Pods are running into 3 different nodes. So, in every minion
I have 2 containers as individual items, but they are all being controller by my
YAML file for Kubernetes as replication controller. Now, as a replication controller
Kubernetes gets services, but we have not defined any so far:

```bash
# kubectl get services
NAME         CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   10.254.0.1   <none>        443/TCP   1d
```

Thus, the only service available is Kubernetes itself. In my cluster I have 3 pods,
one pod per minion:

```bash
]# kubectl get pods
NAME              READY     STATUS    RESTARTS   AGE
nginx-www-m8x9q   1/1       Running   0          15m
nginx-www-vkvw5   1/1       Running   0          15m
nginx-www-xvjvb   1/1       Running   0          15m
```

So, what happens if I delete on of those Pods?

```bash
[root@drpaneas1 Builds]# kubectl get pods
NAME              READY     STATUS    RESTARTS   AGE
nginx-www-m8x9q   1/1       Running   0          15m  <--- delete this one
nginx-www-vkvw5   1/1       Running   0          15m
nginx-www-xvjvb   1/1       Running   0          15m

[root@drpaneas1 Builds]# kubectl delete pod nginx-www-m8x9q
pod "nginx-www-m8x9q" deleted

[root@drpaneas1 Builds]# kubectl get pods
NAME              READY     STATUS    RESTARTS   AGE
nginx-www-b5h6t   1/1       Running   0          3s	<--- new pod
nginx-www-vkvw5   1/1       Running   0          16m
nginx-www-xvjvb   1/1       Running   0          16m
```

As you can see Kubernetes detected that a Pod got remoded from one of our minions
and immediately detected that this is wrong, because it has to always run 3 of
those. So, it automatically created a new one in order to apply the desired state
in the cluster. No matter what I do, unless I delete the replication controller
these Pods are going to be spawned up again again until it matches my YAML definition.
This is:

```bash
# kubectl get replicationcontrollers
NAME        DESIRED   CURRENT   READY     AGE
nginx-www   3         3         3         19m
```

As you can see the desired state is `3` and I currently have `3`. So, Kubernetes
is fine. But as I said, If I delete the replicationcontroller itself:

```bash
# kubectl delete replicationcontroller nginx-www
replicationcontroller "nginx-www" deleted

[root@drpaneas1 Builds]# kubectl get pods
No resources found.
```

Then I have none. Also, in the individual minions, the containers are stopped.

### Deploy Services

We learned how to create, pods, deployments, replication controller, so far we can
deploy one or more containers in a node replicated in our multi-node cluster. So
lets us go ahead and re-run our configuration for our replication controller:

Our `nginx-multi-label.yaml` deploys 3 replicas of an `nginx` container accross
all 3 of our minions. Actually it does not neccessarrilly deploys that in all
of our minions; if our minions are doing other things, it would round-robin
those connections: if we had 4 minions, it would use 3, if we had 10 it would use
3, etc. In this case, we have 3 minions completely empty, so it makes sense for
Kubernetes to run one Pod on them:

```bash
# kubectl create -f nginx-multi-label.yaml 
replicationcontroller "nginx-www" created
```

Since we have created the `replicationcontroller` we see our pods:

```bash
[root@drpaneas1 Builds]# kubectl get replicationcontrollers
NAME        DESIRED   CURRENT   READY     AGE
nginx-www   3         3         3         44s

[root@drpaneas1 Builds]# kubectl get pods
NAME              READY     STATUS    RESTARTS   AGE
nginx-www-9v2lq   1/1       Running   0          50s
nginx-www-ljpsz   1/1       Running   0          50s
nginx-www-wcd1s   1/1       Running   0          50s
```

that are running. Now, We need to create a service definition. A service
definition starts to tighted together. The services are not exposed outside
of their host. However, when we define a service, we actually referring to
a resource that can exist in any of our minions. It shoulds a little bit confusing.
All I am doing is abstracting what is running behind the scenes, providing a mechanism
for Kubernetes to simply assign a single IP address to those multiple Pods that we
reffered to by name or label (in our `selector` field in YAML) so that we can
connect to them and do something. They are going to have unique IP address and the
subsquent assign port, so any of the hosts can use these and work with the entire cluster
instead of just into their own local host.

```bash
vim nginx-service.yaml
```

```
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  ports:
  - port: 8000
    targetPort: 80
    protocol: TCP
  selector:
    app: nginx
```

So once again, here we are defining a kind `Service` that we are calling it `nginx-service`
and then in the specification we are port forwarding the TCP 80 of nginx into our cluster
port 8000 (I have to manually verify that nothing is running there). Then the application
that I am going to run and provide access to, is defined by the label app. called `nginx`.

```bash
[root@drpaneas1 Builds]# kubectl  create -f nginx-service.yaml 
service "nginx-service" created
```

So, let us see the services:

```bash
[root@drpaneas1 Builds]# kubectl get services
NAME            CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
kubernetes      10.254.0.1     <none>        443/TCP    1d
nginx-service   10.254.78.47   <none>        8000/TCP   5s
```

As you can see, I am running now 2 services. The kubernetes service and the `nginx-service`
which runs at the port TCP 8000. Now, I can connect to any of my minions by referring just
to this `10.254.78.47` IP Address and port 8000 and now I am load-balancing and round-robin
among all three nginx-servers that are running in the background, without knowing their IP.
In fact, their IP is likely the same of each of the individual minions.

```bash
[root@drpaneas1 Builds]# kubectl describe service nginx-service
Name:                   nginx-service
Namespace:              default
Labels:                 <none>
Selector:               app=nginx
Type:                   ClusterIP
IP:                     10.254.78.47
Port:                   <unset> 8000/TCP
Endpoints:              172.17.0.2:80,172.17.0.2:80,172.17.0.2:80
Session Affinity:       None
No events.
```

As you can see the `nginx-service` is running in my Cluster with the IP
10.254.78.47 and it uses the port 8000 TCP. It says `<unset>` because
I have not associated this port with something in my system. If I were
using the port 80, then it would not say `unsert` by `http` instead.
Notice that the `endpoints` for each minion, all of them have the
very same IP Address. This would normally be a problem, but: Kubernetes
is managing my configuration and its know manageing my connectvity on the
backend through this cluster IP, now I have the ability to get information
from any one of these, depending on which one is next up in the chain --
it does not make any difference. So this is an easy way to load-balance
your environment. You can use other load-balancers to do others things
but what we are currently doing is round-robin load-balancing between
these end-points on port 8000 for this particular IP.

So how do I connect do? All this go back to `busybox` we did in the
beginning.

```bash
[root@drpaneas1 Builds]# kubectl run busybox --generator=run-pod/v1 --image=busybox --restart=Never --tty -i
Waiting for pod default/busybox to be running, status is Pending, pod ready: false
Waiting for pod default/busybox to be running, status is Pending, pod ready: false
If you dont see a command prompt, try pressing enter.
/ # 
```

Now we can check the IP of our cluster on port 8000 to get back the
nginx which runs on port 80.

```bash
/ # wget --quiet --output-document - https://10.254.78.47:8000
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
<p>For online documentation and support please refer to
<a href="https://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="https://nginx.com/">nginx.com</a>.</p>
<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

If we wanted to we could have defined the cluster to have volume mount
so that we could indicate which container we are pointed to, but in this
case we did not execute any commands within our YAML to mount external
directory for any of our nginx containers. This is why we are getting
the same page back, there is no differenciation other than knowing that this
particular cluster IP is point to a cluster of minions that we have
configured to reffered to the backend Pods and their containers on Port 80
through 8000 at this cluster IP. So, regardless of how many resources are
running the backend, our service is associated with only one cluster IP address
and I do not have to know anything about the backend. Not the containers, not
their ports, nothing. So, as long as I have the cluster IP which I have to
later register it via our DNS -- because this ClusterIP will be persistent
only until it stopped. Once I stopped this, then my Cluster IP is going to go
away:

```bash
[root@drpaneas1 Builds]# kubectl delete pod busybox
pod "busybox" deleted

[root@drpaneas1 Builds]# kubectl delete service nginx-service
service "nginx-service" deleted
```

This just deletes the service, but not the Pods:

```bash
[root@drpaneas1 Builds]# kubectl get services
NAME         CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   10.254.0.1   <none>        443/TCP   1d

[root@drpaneas1 Builds]# kubectl get nodes
NAME             STATUS    AGE
centos-minion1   Ready     1d
centos-minion2   Ready     1d
centos-minion3   Ready     1d
```

The individual pods are continuing running as part of my multi-container
deployment. Those individual pods are running, but now in order to communicate
with them I have to launch busy-box and use their IP address of the particular
container in order to access the nginx service within the Pod in the minion in
which my busybox is running.

## Logs Logs Logs

How can I pull logs from my Pods? There is a facility that is provided as
part of the `kubectl` utility.

```bash
# kubectl logs <pod>
```

I can also specify the number of lines I want to see:

```
bash
# kubectl logs --tail=1 <pod>
```

You can also specify  the time-frame you want to see the logs:

```bash
# kubectl logs --since=24h <pod>
```

Finally, if I want to live monitor the logs:

```bash
# kubectl logs -f <pod>
```

If I want to see the logs on a particular container I need to now the container
ID (CID):

```bash
# kubectl logs -f -c CID <pod>
```

For example, if you try to start a docker image that does not exists
you will see:

```bash
# kubectl run apache --image=apache --port=80 --labels=app=apache
deployment "apache" created

[root@drpaneas1 Builds]# kubectl get pods
NAME                      READY     STATUS         RESTARTS   AGE
apache-2837101164-qxqlv   0/1       ErrImagePull   0          7s

[root@drpaneas1 Builds]# kubectl logs apache-2837101164-qxqlv
Error from server (BadRequest): container "apache" in pod "apache-2837101164-qxqlv" is waiting to start: image cant be pulled
```

This is very useful because you can generate health reports for your services.
You can also specify things like 'if this thing happens' then re-reploy this service.

## Scalability of the cluster

We have control over the initial scalability of our cluster when we create Pods
inside of either deployments, Pod definitions, Replica sets or ReplicationControllers.
But what happens if the initial configuration that we have set inside of our definition
needs to be adjusted for one reason or another, or we want to add scalling to a deployment
that has not had one in the past. We can use something that is called the
`autoscale` directive in order to add and autoscale our definition. We can define
a minimum state (the minimum number of Pods) that should be running in any particular
time, as well as the maximum state (the maximum number of pods) andthen we can also
target various CPU utilization thresholds in order to deploy additional services.
In other words, once we get to 80% CPU utilization on a minion that it has pods on it,
then it will create the next set of Pods on a different minion for example.

We could create a set of Pods based on a ReplicationController set that already has defined
a number of replicas in it. For example, in the `nginx-multi-label.yaml` we have indicated
that we want 3 replicas of this particular pod running in our infrastructure. Right now
we have got two minions available to us (I have taken the 3rd minion offline), so let
us create a temporary pod using the `kubectl run` command. We are going to create a basic
pod that is going to have a single container in it that is going to run an `nginx` image.
We are also going to expose port 80, so our containers will be able to connect to the
service running there. Last but not least, I am not going to indicate a number of replicas
on purpose.

```bash
[root@drpaneas1 Builds]# kubectl run myautoscale --image=nginx --port=80 --labels=app=myautoscale
deployment "myautoscale" created
```

As we saw before, `kubectl run` creates a deployment. A deployment is something that
once it has been defined, we can apply changes to it.

```bash
# kubectl get deployments
NAME          DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
myautoscale   1         1         1            1           1m
```

This is running just one pod on the `minion1`:

```bash
# kubectl describe pods -l app=myautoscale | grep Node:
Node:           centos-minion1/172.31.120.121
```

Which means that is running 2 docker containers:

```bash
# docker ps
CONTAINER ID        IMAGE                                      COMMAND                  CREATED             STATUS              PORTS               NAMES
1bd5a0915963        nginx                                      "nginx -g 'daemon off"   5 minutes ago       Up 5 minutes                            k8s_myautoscale.f898ffdc_myautoscale-3958947512-3p5l4_default_ffa4bfb9-46fa-11e7-8983-0a35c9149e00_8d846e33
40c5b1cf3a4d        gcr.io/google_containers/pause-amd64:3.0   "/pause"                 5 minutes ago       Up 5 minutes                            k8s_POD.b2390301_myautoscale-3958947512-3p5l4_default_ffa4bfb9-46fa-11e7-8983-0a35c9149e00_4cb76f9d
```

Now, I may need to autoscale this depending upon various conditions. The one that I have
complete control is the amount of CPU that is utilized in within my cluster. For this
I am going to use the `autoscale` directive. First I need to know the name of the deployment
(in my case `myautoscale`) and then I need to spacify at least on parameter. I am going to
say I need to deploy at least 2 pods (because I know already I have 2 minions to utilize)
and I am going to also say that I would like to have a maximum deployment of 6 pods.
And last but not least, my CPU percent is goingto be equal to some number (`--cpu-precent`)
but since the cpu load on my minions is really low, I know that  I am not going to utlize
this, so I am going to skip this and use the default scaling police. The default policy says
that when the number of pods exceeds the number of resources on the minion (or it stops
responding) then it will spin up new pods in on other minions. So, it should automatically
scale up to at least 2 pods.

```bash
# kubectl autoscale deployments myautoscale --min=2 --max=6
deployment "myautoscale" autoscaled
```

That is it. My deployment called `myautoscale` is now *autoscalling*.
I see that I have now at least two pods running:

```bash
# kubectl get pods
NAME                           READY     STATUS    RESTARTS   AGE
myautoscale-3958947512-3p5l4   1/1       Running   0          16m
myautoscale-3958947512-lt2cg   1/1       Running   0          43s
```

The second pod is not running on the second minion as well:

```bash
# kubectl describe pods -l app=myautoscale | grep Node:
Node:           centos-minion1/172.31.120.121
Node:           centos-minion2/172.31.110.96
```

And of course the deployment has changed:

```bash
# kubectl get deployments
NAME          DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
myautoscale   2         2         2            2           18m
```

Now, if I want to have at least *4* pods as minimum in my deployments,
I can simply re-run the previous command by changing the `--min`
parameter.

```bash
# kubectl autoscale deployments myautoscale --min=4 --max=6
Error from server (AlreadyExists): horizontalpodautoscalers.autoscaling "myautoscale" already exists
```

But I got an error. What this means? So, what that means is that I have
changed my deployment to an `autoscale` and once the autoscale exists,
just like a pod that is called 123, I cannot create another one called 123,
that means that I do not have the ability to scale further my current environment
without deleting it. I can apply a different directive called `scale`. So,
up to these point, I already have an *autoscale* but I also need to *scale*
it further. In that case I have first to tell it what is my current auto-scale
plan (`--current-replicas=2) and then the target I want to scale into.

```bash
# kubectl scale --current-replicas=2 --replicas=4 deployment/myautoscale
deployment "myautoscale" scaled
```

This applies my new rule without changing the fact that `autoscale` has already
been deployed. When I applied my autoscale, autoscaled was **created**, but all I
am doing now is that I applying a change (I am not re-creating something).

```bash
# kubectl get deployments
NAME          DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
myautoscale   4         4         4            4           26m
```

As you can see, my deployment has not changed to 4 replicas. Two of them on
minion1 and two of them on minion2.

```bash
# kubectl describe pods -l app=myautoscale | grep Node:
Node:           centos-minion1/172.31.120.121
Node:           centos-minion2/172.31.110.96
Node:           centos-minion1/172.31.120.121
Node:           centos-minion2/172.31.110.96
```

Now the question is: *can I scale down?*. Yes but there is a limitation
to what you can scale down to. You cannot scale pass the point when you
applied the autoscale to `--min` value. In other words, I cannot apply a
scale rule that has a lower value than 2. Because when I originally applied
the autoscale, I said that I wantto have 2 minimum pods. So, even if I now say
that I want to scale down to 1, it will still deploy 2. But, I can scale down
to 3.

```bash
# kubectl scale --current-replicas=4 --replicas=3 deployment/myautoscale
deployment "myautoscale" scaled

[root@drpaneas1 Builds]# kubectl get pods
NAME                           READY     STATUS    RESTARTS   AGE
myautoscale-3958947512-3p5l4   1/1       Running   0          31m
myautoscale-3958947512-lt2cg   1/1       Running   0          15m
myautoscale-3958947512-mkqv4   1/1       Running   0          6m
```

The cluster is terminating the instances that have been running for
the shortest amount of time. Many people thing that Kubernetes terminates the latest
instance, but this is not true. If you for example restart you first instance
the running time of it is going to go back to zero, so, this is goingto be
terminated first in a scenario like that (scale down).

So what is is important to keep in mind is that as long as I have a deployment
or a replicaset or a replication controller definition, no matter if I am
doing this automatically or via a YAML file, I can autoscale that by applying
an autoscale defintion into it, and then I can further scale it by using
scale. But I cannot go lower than my original minimum limit.

If now I fire up my 3rd minion, then Kubernetes will understand that my environment
has now the capacity to run more minions:



## Failure and Recovery

**Before version 1.5**

Kubernetes has the ability to detect when something has failed and the ability
to recover when this failure has been corrected an then to react to that failure
by taking action. One of the things to keep in mind, is that parts of the
underlying functionality is that one a Pod has been deployed to a minion, it is
guaranteed to be on that particular minion for its entire lifecycle. That means
until the Pod is deleted, you will always have that Pod there. That means, in
case of a failure, the Pod is just going to go down, but not picked up and moved
somewhere else. The reason is double:

1. There might be IP Addresses and back-end services which that Pod is tight to
that particular minion (e.g. volume mounts) -- such stuff are not portable
between minions; because it cannot depend upon minion configuration.

2. Other pods that exists on that host, espect to have access to those recourses
but if it moves somewhere else, then other Pods on that minion, if it was a
service failure and you just re-deployed the Pod to a different minion in order
to recover, would not neccessarrily have access to that resources.

But the recovery works OK, because the Pod will be re-deployed in its entirety
and its exact configuration once the minion is available. So let us go ahead
and deploy a deployment which has at least 2 Pod on each of the two minions
we have in our configuration right now.

```bash
# kubectl run myrecovery --image=nginx --port=80 --replicas=2 --labels=app=myrecovery
deployment "myrecovery" created

[root@drpaneas1 ~]# kubectl get deployments
NAME         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
myrecovery   2         2         2            2           25s
```

My deployment `myrecovery` has been created. Now if I want to scale this up
or down we can apply an `autoscale` definition to it. Anyways, looking
what is running in our minions, we see that in every minion there are
2 containers. One for apache and one for google. So, we are running 4
containers in total.

minion_1

```bash
[root@drpaneas2 ~]# docker ps
CONTAINER ID        IMAGE                                      COMMAND                  CREATED             STATUS              PORTS               NAMES
e7ce117e9c0f        nginx                                      "nginx -g 'daemon off"   31 seconds ago      Up 30 seconds                           k8s_myrecovery.1371ff8a_myrecovery-3755654676-qfc71_default_481562fa-46f2-11e7-8983-0a35c9149e00_9b42bd0c
e1f60db6cd12        gcr.io/google_containers/pause-amd64:3.0   "/pause"                 32 seconds ago      Up 31 seconds                           k8s_POD.b2390301_myrecovery-3755654676-qfc71_default_481562fa-46f2-11e7-8983-0a35c9149e00_e69fa223
```

minion_2

```bash
CONTAINER ID        IMAGE                                      COMMAND                  CREATED              STATUS              PORTS               NAMES
d0cf0b3c8c3b        nginx                                      "nginx -g 'daemon off"   About a minute ago   Up About a minute                      k8s_myrecovery.1371ff8a_myrecovery-3755654676-t4064_default_48158b96-46f2-11e7-8983-0a35c9149e00_e04e7997
715206a85679        gcr.io/google_containers/pause-amd64:3.0   "/pause"                 About a minute ago   Up About a minute                      k8s_POD.b2390301_myrecovery-3755654676-t4064_default_48158b96-46f2-11e7-8983-0a35c9149e00_ab638246
```

Also, just to clarify that I am using only two minion, and not 3.

```bash
kubectl get nodes
NAME             STATUS    AGE
centos-minion1   Ready     10m
centos-minion2   Ready     10m
```

So, now the question is *what happens if one of those servers go down?*
The behavior might be a little bit different from what someone whould
expect from Kubernetes. So let us go to the *minion_1* and shutdown
the services: `docker`, `kubelet`, `kube-proxy`.

```bash
# systemctl stop docker kubelet kube-proxy
```

As a result, now this minion cannot register with `etcd` daemon running
in my master controller and cannot report to it. Back to the master
controller, it is going to take up to *minute* to its `etcd` to pick
up the fact that *minion_1* is no longer available. So, for some time
frame kubectl will print wrong information about running Pods and
connected nodes. But as I said, after some time, it picks up the failure:

```bash
[root@drpaneas1 Builds]# kubectl get nodes
NAME             STATUS     AGE
centos-minion1   NotReady   16m
centos-minion2   Ready      15m
```

So additional implementations will all go to *minion2* because it is the only
one reporting as ready. But what I would expect from Kubernetes is to make sure
that whatever was running minion1, it will be moved to minion2. But it does not.
And this is for the reason I told you before. Because this pod might have containers
which utilize dependencies on the underlying minion host and/or may have other pods
that need access to those services. In that case the pod would have attempted to be
restarted because I have applied replicas to it, but that **only** applies when a
failed replica gets restarted on its original minion. So, in this case, if the
original host is not available, you never gonna see the pod to move to minion1
in order to match the desired state of replica 2.

As soon as you start the services in minion1, Kubernetes will detect this
and respawn the Pod in minion1.

**After Kuberentes 1.5**

With the introduction of version 1.5, there is a notable change in this behavior.
Kubernetes quickly detects that a node is down, and it marks that Pod as in unknown
state for some minutes. If the minion is not getting up, then Kuberentes moves this pod
into another minion.

```bash
[root@drpaneas1 Builds]# kubectl get pods
NAME                          READY     STATUS    RESTARTS   AGE
myrecovery-3755654676-b7fvz   1/1       Running   0          3m
myrecovery-3755654676-qfc71   1/1       Unknown   0          13m  <--- Dead Node
myrecovery-3755654676-t4064   1/1       Running   0          13m
```

After re-activating the minion1, Kubernetes removes the failed pod
(in that case `qfc71`) completely and keeps maintaining the new pod
(with new ID `b7fvz`) on minion2. So, you end up with 4 containers
running in the same host.

minion1:

```bash
[root@drpaneas2 ~]# docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
```

minion2:

```bash
# docker ps -q
d43d52fc738d
f73b10adb841
d0cf0b3c8c3b
715206a85679
``` 

However, if you run this as a service, then you do not actually care because
it uses load-balancing round-robin.
