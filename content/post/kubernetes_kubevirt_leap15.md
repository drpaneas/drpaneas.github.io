+++
categories = ["tutorial"]
date = "2018-03-15T20:46:35+02:00"
tags = ["tutorial", "kubernetes", "kubevirt", "minikube", "kvm"]
title = "Deploy openSUSE Leap15 VM in Kubernetes using KubeVirt"

+++

## Introduction

If you think that Kubernetes is a cluster for managing
containers, then you are dead wrong. Kubernetes is a cluster
for managing `Pods`. In most cases, a Pod is considered to be
an abstraction of an container object, so Pod talks to
Docker and they know each other. What happens though when
we introduce a new guy called libvirt and we learn Pod
to talk to it? We have **KubeVirt**. KubeVirt is the
technology that allows Kubernetes to be a cluster for
both containers **and** virtual-machines!

### What's the use-case?

In the next 5 years it's expected that lot's of companies
will try to migrate their applications and services from
monotlith into microservices. Now, we all now that for
most of them, this is a very difficult thing to do.
Especiall when there are services running in machines
that they haven't been touched in years... So, what
will happen is that all these companies are doomed
to have 2 infrastractures. One infrastructure based
on what they already do (*e.g. OpenStack*) and one
with containers and Kubernetes. Now, this project,
KubeVirt comes into play and tells them that you just
need one infrastructure in Kubernetes. In case you
have any VM, they can easily be migrated to run
in Kubernetes -- that's it.

## Install Minikube

### Wait... why?

In this guide, I am going to use **minikube** simply
because this is the fastest way to deploy a *k8s* cluster
and do some dirty testing. Now, this is not just my opinion
but in general, *minikube* is considered to be the
*hello-world* of Kubernetes. Actually, it's nothing
more than a toolbox which we are using via the command
line in order to setup a local k8s cluster. However,
this is not going to be a cluster similar to the ones
of AWS or Azure, but a small single-node cluster
for educational purposes -- which seems to be quite
enough for someone who wants just to have a taste of
Kubernetes or test his own apps locally.

Since, the purpose of this article is not to show you
the features of Kubernetes which are related to the
management of applications in a multi-node environment,
it's sure more than enough to demo the basic functionality
of **KubeVirt**. Also another reason I prefered to use
*minikube* in this article is simply because it's
*cross-platform*. So, if you are using Mac or Windows PC,
you can still follow this guide. Last thing, is that with
minikube our Kubernetes cluster is always running with the
latest bleeding-edge version of Kubernetes, so you can be
up to date with the modern stuff and also keep an eye on
the documentation. So, if we can be updated and also learn
something in the meantime, then *why-not?*

### KVM Configuration (you should have but you never did)

As I said, there are many ways that someone can install
a Kubernetes cluster. Everyone  nowadays *re*-invents
the wheel by offering their own *N-th*-kubernetes
installer. Anyway, in this article I have decided we are
going to use Minikube **purely because of lazyness**, so if
you feel more adventourus than me, feel free to deploy
Kubernetes in whatever way makes you happy.

Minikube requires some
kind of virtualization technology to be present, so since
we are in Linux, there's no better choice than *KVM*. To
install *KVM* in openSUSE, do the following in *YaST*:

* Start *YaST* and choose *Virtualization*. Install
*Hypervisor and Tools*.

* Select *KVM server* and *KVM tools* because we
want to have a libvirt based management stack. Confirm with 
*Accept*.

* To enable normal networking for the VM Guest, using
a network bridge is recommended. YaST offers to automatically
configure a bridge on the VM Host Server. Agree to do so by
choosing *Yes*. In case you have problems with setting up your
bridge, use my [create_bridge](https://github.com/drpaneas/uzful-scripts)
script.

```bash
~/github/uzful-scripts # ./create_bridge.sh 
Main Interface: enp0s25
YaST Interface ID: 0
Creating bridge...
Bridge Interface: br0
YaST bridge ID: 2
# To restore back to the original state, do:
yast lan delete id=2
yast lan edit id=0 bootproto='dhcp'
```

By now, you should have installed the following packages:

```bash
rpm -q libvirt-daemon-qemu qemu-kvm
```

and also a perfectly working bridge interface:

```bash
br0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.178.136  netmask 255.255.255.0  broadcast 192.168.178.255
        ether d0:50:99:83:db:5f  txqueuelen 1000  (Ethernet)
        RX packets 192  bytes 29515 (28.8 KiB)
        RX errors 0  dropped 39  overruns 0  frame 0
        TX packets 123  bytes 12889 (12.5 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

Then let's make sure that any normal user is able
to connect and interact with libvirt, without any
need for *root* priviledges. First off, we
configure the sockets to be owned and
be accessible by a certain group (*e.g.* libvirt group).
Before doing that, make sure that the group *libvirt*
already exists in your system:

```bash
getent group | grep libvirt
libvirt:x:462
```

If it doesn't exist, then just create it:

```bash
root # groupadd libvirt
```

Now, make your normal user is part of *libvirt* group:

```bash
sudo usermod --append --groups libvirt $(whoami)

# Verification:
grep $(whoami) /etc/group | grep libvirt
libvirt:x:462:drpaneas
```

Also, we need to change the configuration which is
related to the access of the Unix socket. The group
ownership should be `libvirt`, the permissions for the
socket should be `srwxrwx---` and lasty disable other
authentication methods in order to handle this solely
by the socket permissions itself. To do all of those,
change the configuration in `/etc/libvirt/libvirtd.conf`
as follows:

```bash
# grep  ^[^#]  /etc/libvirt/libvirtd.conf

unix_sock_group = "libvirt"
unix_sock_dir = "/var/run/libvirt"
auth_unix_rw = "none"
```

After configuring the socket. Let's do the same
for `qemu`. Edit `/etc/libvirt/qemu.conf` and change the
configuration as follows:

```bash
# grep ^[^#] /etc/libvirt/qemu.conf

security_default_confined = 0
user = "drpaneas"	# <--- put your normal user username
group = "libvirt"
dynamic_ownership = 1
```

Then, make your normal user a member of
the group `kvm`:

```bash
usermod --append --groups kvm $(whoami)

# Verification
grep $(whoami) /etc/group | grep kvm
kvm:x:484:qemu,drpaneas
```

This step is needed to grant access to `/dev/kvm`,
which is required to start VM Guests as *drpaneas*.

To take the changes into effect, restart libvirtd:

```bash
root # systemctl restart libvirtd

# Verification
root # systemctl is-active libvirtd
active
```

From now on, `drpaneas` is able to communicate with
*virsh*. You can test this, to make sure of it:

```bash
drpaneas@localhost:~> virsh -c 'qemu:///system' list
 Id    Name                           State
----------------------------------------------------
```

### Install KVM2 driver plugin for docker machine

Typically, we would use `kvm driver` but by the time of writing this
blogspot, it's considered deprecated. This is why we are going to use
the new modern **kvm2 driver**. To install it, type the following:

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/docker-machine-driver-kvm2 && chmod +x docker-machine-driver-kvm2 && sudo mv docker-machine-driver-kvm2 /usr/bin/
```

Make no mistake here: this is not a binary, but a docker machine plugin.
These are not intended to be invoked directly, but use them through the
main `docker-machine` binary. This is the one that *minikube* uses.

### Install Minikube

Unfortunatelly, there is no *minikube* package in our official repositories.
The *Containers Team* is building one, which you can use it if you add their
repository -- however I would strongly advise you to avoid it. Simply because
the version that is maintained there is quite old compared to the upstream.
So, the only option in that case is to pick-up the upstream binary directly:

```bash
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
```


## Deploy Kubernetes 1.9 or later

Using *minikube* we are going to deploy a Kubernetes cluster. This will utilize
*KVM* and run a single-node cluster inside a virtual-machine.

```bash
drpaneas@localhost:~> minikube start --vm-driver=kvm2

Starting local Kubernetes v1.9.0 cluster...
Starting VM...
Downloading Minikube ISO
 142.22 MB / 142.22 MB [============================================] 100.00% 0s
Getting VM IP address...
Moving files into cluster...
Downloading localkube binary
 162.41 MB / 162.41 MB [============================================] 100.00% 0s
 0 B / 65 B [----------------------------------------------------------]   0.00%
 65 B / 65 B [======================================================] 100.00% 0sSetting up certs...
Connecting to cluster...
Setting up kubeconfig...
Starting cluster components...
Kubectl is now configured to use the cluster.
Loading cached images from config file.
```

If everything went smoothly, you should be able to see your *minikube*
virtual-machine running:

```bash
drpaneas@localhost:~> virsh -c 'qemu:///system' list
 Id    Name                           State
----------------------------------------------------
 2     minikube                       running
```

JFYI whenever you want to get rid of it:

```bash
# minikube stop
Stopping local Kubernetes cluster...
Machinestopped.

# minikube delete
Deleting local Kubernetes cluster...
Machine deleted
```

## Talk with the cluster

In order to communicate and interact with the Kubernetes cluster,
we need `kubectl` -- kubecontrol, which is nothing more than just
a client which talks with our cluster using the command-line. This
time, openSUSE does provide a package, so let's trust our maintainers
in this:

### Install Kubectl

```bash
zypper -n install kubernetes-client
```

```bash
# kubectl cluster-info
Kubernetes master is running at https://192.168.39.11:8443

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

```bash
# kubectl get nodes
NAME       STATUS    ROLES     AGE       VERSION
minikube   Ready     <none>    4m        v1.9.0
```

```bash
drpaneas@localhost:~> kubectl get --all-namespaces pods
NAMESPACE     NAME                                    READY     STATUS    RESTARTS   AGE
kube-system   kube-addon-manager-minikube             1/1       Running   0          5m
kube-system   kube-dns-54cccfbdf8-89c9t               3/3       Running   0          5m
kube-system   kubernetes-dashboard-77d8b98585-hml7r   1/1       Running   0          5m
kube-system   storage-provisioner                     1/1       Running   0          5m
```

In case you are more of a visual guy, open the Kubernetes Dashboard:

```bash
minikube dashboard
Opening kubernetes dashboard in default browser...
```

## Deploy KubeVirt

With minikube running, you can easily deploy KubeVirt.
If you want to know more about it just read the
[online documentation](https://kubevirt.gitbooks.io/user-guide/)

```bash
$ export VERSION=v0.3.0
$ kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/$VERSION/kubevirt.yaml
```

> **Note:** The initial deployment to a new minikube instance can take
> a long time, because a number of containers have to be pulled from the
> internet. Use `watch kubectl get --all-namespaces pods` to monitor the progress.

Expected output:

```bash
clusterrole "kubevirt-controller" created
serviceaccount "kubevirt-controller" created
serviceaccount "kubevirt-privileged" created
clusterrolebinding "kubevirt-controller" created
clusterrolebinding "kubevirt-controller-cluster-admin" created
clusterrolebinding "kubevirt-privileged-cluster-admin" created
customresourcedefinition "virtualmachines.kubevirt.io" created
customresourcedefinition "virtualmachinereplicasets.kubevirt.io" created
deployment "virt-controller" created
daemonset "virt-handler" created
customresourcedefinition "virtualmachinepresets.kubevirt.io" created
customresourcedefinition "offlinevirtualmachines.kubevirt.io" created
```

At the end you should have these extra pods:

```bash
kube-system   virt-controller-5c74754ddd-clshx        1/1       Running   0          50s
kube-system   virt-controller-5c74754ddd-xgk7m        0/1       Running   0          50s
kube-system   virt-handler-5bcl4                      1/1       Running   0          50s
```

Please notice that `virt-controller-5c74754ddd-xgk7m` is not running
and this is OK. This is because this controller is just a hot-standby
in case that the primary controller (`virt-controller-5c74754ddd-clshx`)
has an issue.

### Download openSUSE Leap 15

Go to the official openSUSE website and download the new
Leap 15 ISO:

```bash
wget https://download.opensuse.org/distribution/leap/15.0/iso/openSUSE-Leap-15.0-DVD-x86_64-Current.iso
```

### Install the PVC plugin

KubeVirt works using PVCs -- Persistent Volume Claim -- and the easiest
way to create them is by using [fabian's](https://twitter.com/dummdida)
plugin:

```bash
curl -L https://github.com/fabiand/kubectl-plugin-pvc/raw/master/install.sh | bash
```

### Create leap15 PVC

In order to create a new PVC called `leap15` with a size of 10Gi and copy the local ISO into a file called `disk.img` on the new PVC.

```bash
$ kubectl plugin pvc create leap15 1Gi $PWD/openSUSE-Leap-15.0-DVD-x86_64-Current.iso disk.img

Creating PVC
persistentvolumeclaim "leap15" created
Populating PVC
pod "leap15" created
total 3168260
3168260 -rw-r--r--    1 1000     users       3.0G Mar 13 17:12 disk.img
Cleanup
pod "leap15" deleted
```


### Upload the VM

Create the object `leap15.yaml`:

```yaml
apiVersion: kubevirt.io/v1alpha1
kind: VirtualMachinePreset
metadata:
  name: large
spec:
  selector:
    matchLabels:
      kubevirt.io/size: large
  domain:
    resources:
      requests:
        memory: 8Gi
---
apiVersion: kubevirt.io/v1alpha1
kind: OfflineVirtualMachine
metadata:
  name: leap
spec:
  running: true
  selector:
    matchLabels:
      guest: leap
  template:
    metadata:
      labels:
        guest: leap
        kubevirt.io/size: large
    spec:
      domain:
        devices:
          disks:
            - name: leap
              volumeName: leap
              disk:
                bus: virtio
      volumes:
        - name: leap
          persistentVolumeClaim:
            claimName: leap15
```

Now apply this object specification using `kubectl`:

```bash
kubectl apply -f leap15.yaml
```

## Connect to your Virtual-Machine

That's it, your VM should now be online, converted
into a Kubernetes Pod object:

```bash
drpaneas@localhost:~/Documents> kubectl get pods
NAME                       READY     STATUS    RESTARTS   AGE
virt-launcher-leap-ht7zb   1/1       Running   0          24m
```

### Download virtctl

To connect to our VM, we need VNC, and especially `virtctl`:

```bash
export VERSION=v0.3.0
curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/$VERSION/virtctl-$VERSION-linux-amd64
chmod +x virtctl
```

Now, try to connect:


```bash
# Connect to the serial console
$ ./virtctl console --kubeconfig ~/.kube/config leap

# Connect to the graphical display
$ ./virtctl vnc --kubeconfig ~/.kube/config leap
```

![Leap 15 VM on Kubernetes](https://i.imgur.com/J3QE8FV.png)


To sum up, this is just a project in a **very early stage**. The
virtual-machines are running in **emulation mode**, which makes
them **horribly slow**. However, performance drop is affected
by a regression due to refactoring -- but they will soon
[fix](https://t.co/qGiviRL5I9) it, so stay tuned!

In the end of it, I hope you
guys liked that project and go over [KubeVirt](https://github.com/kubevirt/kubevirt)
GitHub page and *click at Star* to support the devs.

Have fun,
Panos

