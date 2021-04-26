+++
categories = ["kubernetes"]
date = "2020-02-25T03:29:35+01:00"
tags = ["kubernetes", "controllers", "golang"]
title = "How to write your own Kubernetes controller"

+++

# Write your own controller

Before going down the operator framework out there, it is important to understand what is happening under the hood.
Then you would be able to appreciate the generated boilerplate code and feel more comfortable to _change_ it.

## Prereq

This tutorial assumes you have a cluster up and running and you can successfully communicate with it (e.g. `kubectl get pods -A` should work).
If you don't have a cluster, you can setup one locally using [CodeReadyContainers](https://code-ready.github.io/crc/#installation_gsg)(used by the tutorial) or minikube.


## Create a Manager

Every controller is technically run by a [Manager](https://godoc.org/github.com/kubernetes-sigs/controller-runtime/pkg/manager#Manager).
So, the first step to write a controller is that you need to write a Manager.
Manager is the logic reponsible for triggering the controllers.
Managers are responsible for running controllers, doing leader elections and handling graceful termination of the controller signals.
The Manager provides the client, the cache and a lot of dependencies the controller needs to run.

You can create a Manager by creating a new instance of a Manager (`manager.New()`).

```go
package main

import (
	"fmt"
	"os"

	"sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/manager"
)

func main() {

	mgr, err := manager.New(config.GetConfigOrDie(), manager.Options{Namespace: ""})
	if err != nil {
		fmt.Println(err, "Unable to setup manager. Please check if KUBECONFIG is available")
		os.Exit(1)
	}
	fmt.Println(mgr)	// To avoid Go complaining at mgr not getting used
}
```

> The `config.GetConfigOrDie()` tries to get a valid `$KUBECONFIG` to talk with the `apiserver`, as defined at [controller-runtime](https://github.com/kubernetes-sigs/controller-runtime/blob/master/pkg/client/config/config.go).

Run:

```bash
$ go mod init
$ go run main.go
```

## Create a controller

Every [Controller](https://godoc.org/github.com/kubernetes-sigs/controller-runtime/pkg#hdr-Controller) needs to be bound to a Manager.
To create a Controller, we need to pass the previously created Manager (`mgr`).
The Controller has a set of optional parameters you can leave out.
The controller will watch and reconcile for `pods`.
The most important parameter when you create a controller is the reconsile logic.
Every time the controller detects some drift in your cluster, it going to call this reconsile logic.

> JFYI: You can have more than one reconcilers at one time -- if you like.
> By adding: `controller.Options{MaxConcurrentReconciles: 2}`

For now, the `Reconcile` function will have no logic.
We just need to create it because it is needed to bound a Reconciler during the creation of a controller.

```go
package main

import (
	"fmt"
	"os"

	"sigs.k8s.io/controller-runtime/pkg/client"			// for the client.Client
	"sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/controller"		// for the controller.New
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"		// for the reconcile.Result
)

type ReconcilePod struct {
	client client.Client // it reads objects from the cache and writes to teh apiserver
}

func (r *ReconcilePod) Reconcile(request reconcile.Request) (reconcile.Result, error) {
	return reconcile.Result{}, nil
}

func main() {

	mgr, err := manager.New(config.GetConfigOrDie(), manager.Options{})
	if err != nil {
		fmt.Println(err, "Unable to setup manager. Please check if KUBECONFIG is available")
		os.Exit(1)
	}

	ctrl, err := controller.New("pod-what-crashes", mgr, controller.Options{
		Reconciler: &ReconcilePod{client: mgr.GetClient()},
	})
	if err != nil {
		fmt.Println(err, "Failed to setup controller")
		os.Exit(1)
	}
	fmt.Println(ctrl)	// To avoid Go complaining at ctrl not getting used
}
```

Run:

```bash
$ go mod tidy
$ go run main.go
```

## Put a Watcher

A controller is watching for [Events](https://godoc.org/sigs.k8s.io/controller-runtime/pkg/event) via a Watcher.
The Events are produced by [Sources](https://godoc.org/sigs.k8s.io/controller-runtime/pkg/source#Source) assigned to resources (e.g. _Pods_).
These events are transformed into **Requests** by [EventHandlers](https://godoc.org/sigs.k8s.io/controller-runtime/pkg/handler#hdr-EventHandlers) and then passed to `Reconcile()` function to trigger an action.

In our case, we put a Watcher to look for Pod events (provided by source `{Type: &v1.Pod{}`) and enqueue them as Requests for the `Reconciler()` with their Name and and Namespace by using an EventHandler, that is [EnqueueRequestForObject](https://godoc.org/sigs.k8s.io/controller-runtime/pkg/handler#example-EnqueueRequestForObject).
For each Add/Update/Delete event the reconcile loop will be sent a reconcile Request (a namespace/name key) for that Pod object.

> Best Practice: Use only a single reconciler function so that reconcilers are always indepodent.

```go
package main

import (
	"fmt"
	"os"

	v1 "k8s.io/api/core/v1"							// for v1.Pod type
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	"sigs.k8s.io/controller-runtime/pkg/source"		// for source.Kind{}
)

type ReconcilePod struct {
	client client.Client   // it reads objects from the cache and writes to teh apiserver
}

func (r *ReconcilePod) Reconcile(request reconcile.Request) (reconcile.Result, error) {
	return reconcile.Result{}, nil
}

func main() {

	mgr, err := manager.New(config.GetConfigOrDie(), manager.Options{Namespace: ""})
	if err != nil {
		fmt.Println(err, "Unable to setup manager. Please check if KUBECONFIG is available")
		os.Exit(1)
	}

	ctrl, err := controller.New("pod-what-crashes", mgr, controller.Options{
		Reconciler: &ReconcilePod{client: mgr.GetClient()},
	})
	if err != nil {
		fmt.Println(err, "Failed to setup controller")
		os.Exit(1)
	}

	if err := ctrl.Watch(&source.Kind{Type: &v1.Pod{}}, &handler.EnqueueRequestForObject{}); err != nil {
		fmt.Println(err, "Failed to watch pods")
		os.Exit(1)
	}
}
```

Run:

```bash
$ go mod tidy
$ go run main.go
```

## Starting the Manager

The last part is to setup a `SIGINT` and `SIGTERM` signal for the graceful start and stop of the manager in combination with k8s pod termination policy.

```go
package main

import (
	"fmt"
	"os"

	v1 "k8s.io/api/core/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/manager/signals"		// for handling the signals
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	"sigs.k8s.io/controller-runtime/pkg/source"
)

type ReconcilePod struct {
	client client.Client   // it reads objects from the cache and writes to teh apiserver
}

func (r *ReconcilePod) Reconcile(request reconcile.Request) (reconcile.Result, error) {
	return reconcile.Result{}, nil
}

func main() {

	mgr, err := manager.New(config.GetConfigOrDie(), manager.Options{Namespace: ""})
	if err != nil {
		fmt.Println(err, "Unable to setup manager. Please check if KUBECONFIG is available")
		os.Exit(1)
	}

	ctrl, err := controller.New("pod-what-crashes", mgr, controller.Options{
		Reconciler: &ReconcilePod{client: mgr.GetClient()},
	})
	if err != nil {
		fmt.Println(err, "Failed to setup controller")
		os.Exit(1)
	}

	if err := ctrl.Watch(&source.Kind{Type: &v1.Pod{}}, &handler.EnqueueRequestForObject{}); err != nil {
		fmt.Println(err, "Failed to watch pods")
		os.Exit(1)
	}

	fmt.Println("Starting the manager")
	if err := mgr.Start(signals.SetupSignalHandler()); err != nil {
		fmt.Println(err, "Failed to start manager")
		os.Exit(1)
	}
}
```

```bash
go mod tidy
do run main.go
```

The controller will start running outside of the cluster, using your own credentials (`admin` of the cluster).
Press `ctrl+c` to stop it.


## Add business logic

Every time there is an event (e.g. _Add/Update/Delete_) for the Pod resource type, then the controller will display a message at its logs.

```go
package main

import (
	"context"
	"fmt"
	"os"

	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/manager/signals"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	"sigs.k8s.io/controller-runtime/pkg/source"
)

var restartList map[string]int32

type ReconcilePod struct {
	client client.Client // it reads objects from the cache and writes to teh apiserver
}

func (r *ReconcilePod) Reconcile(request reconcile.Request) (reconcile.Result, error) {
	pod := &v1.Pod{} // Fetch the pod object
	err := r.client.Get(context.TODO(), request.NamespacedName, pod)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			// Owned objects are automatically garbage collected. For additional cleanup logic use finalizers.
			// Return and don't requeue
			fmt.Println("Pod Not Found. Could have been deleted")
			return reconcile.Result{}, nil
		}
		// Error reading the object - requeue the request.
		fmt.Println("Error fetching pod. Going to requeue")
		return reconcile.Result{Requeue: true}, err
	}

	// Write the business logic here
	for i := range pod.Status.ContainerStatuses {
		container := pod.Status.ContainerStatuses[i].Name
		restartCount := pod.Status.ContainerStatuses[i].RestartCount
		identifier := pod.Name + pod.Status.ContainerStatuses[i].Name
		if _, ok := restartList[identifier]; !ok {
			restartList[identifier] = restartCount
		} else if restartList[identifier] < restartCount {
			fmt.Println("Reconciling container: " + container)
			fmt.Println(container, restartCount)
			restartList[identifier] = restartCount
		}
	}
	return reconcile.Result{}, nil
}

func main() {
	restartList = make(map[string]int32)

	// Create a Manager, passing the configuration for KUBECONFIG
	// To watch all namespaces leave the namespace option empty: ""
	mgr, err := manager.New(config.GetConfigOrDie(), manager.Options{Namespace: ""})
	if err != nil {
		fmt.Println(err, "Unable to setup manager. Please check if KUBECONFIG is available")
		os.Exit(1)
	}

	ctrl, err := controller.New("pod-what-crashes", mgr, controller.Options{
		Reconciler: &ReconcilePod{client: mgr.GetClient()},
	})
	if err != nil {
		fmt.Println(err, "Failed to setup controller")
		os.Exit(1)
	}

	if err := ctrl.Watch(&source.Kind{Type: &v1.Pod{}}, &handler.EnqueueRequestForObject{}); err != nil {
		fmt.Println(err, "Failed to watch pods")
		os.Exit(1)
	}

	fmt.Println("Starting the manager")
	if err := mgr.Start(signals.SetupSignalHandler()); err != nil {
		fmt.Println(err, "Failed to start manager")
		os.Exit(1)
	}
}
```

The `Reconcile()` receives the Request (`reconcile.Request()` and returns a `reconsile.Result()` and an `error` code.
It is reading the state of the cluster by using the `client.Get()`.
Since the controller running in my local machine, it is using my `$HOME/.kube/config` file to connect to my Kubernetes cluster.
Since I have admin rights there, the controller is actually listing everything on the cluster.

Launch 2 terminals. One terminal will run the controller and the other one will spin up a deployment that is crashing every 30s.

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: controller-demo
spec:
  containers:
  - name: example
    image: busybox
    command: ["/bin/sh"]
	args: ["-c", "sleep 30"]
```

Run from Terminal 1:

```bash
$ go mod tidy
$ go run main.go
```

Run from Terminal 2:

```bash
$ kubectl create -f test.yaml
```

After 2 minutes the output would be similar to:

```
Reconciling container: example
example 1

Reconciling container: example
example 2

Reconciling container: example
example 3

...
```

## Add a logger

It is better to watch for timestamps and dates.
To do that, we will use `zap` pkg.
Setup the logger like this: `log := zapr.NewLogger(zap.NewExample()).WithName("pod-what-crashes")`.
Replace the `fmt.Println` either with `log.Info()` or `log.Error()`.

```go
package main

import (
	"context"
	"os"

	"github.com/go-logr/zapr"
	"github.com/prometheus/common/log"
	"go.uber.org/zap"
	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/manager/signals"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	"sigs.k8s.io/controller-runtime/pkg/source"
)

var restartList map[string]int32

type ReconcilePod struct {
	client client.Client // it reads objects from the cache and writes to teh apiserver
}

func (r *ReconcilePod) Reconcile(request reconcile.Request) (reconcile.Result, error) {
	pod := &v1.Pod{} // Fetch the pod object
	err := r.client.Get(context.TODO(), request.NamespacedName, pod)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			// Owned objects are automatically garbage collected. For additional cleanup logic use finalizers.
			// Return and don't requeue
			log.Error("Pod Not Found. Could have been deleted")
			return reconcile.Result{}, nil
		}
		// Error reading the object - requeue the request.
		log.Error("Error fetching pod. Going to requeue")
		return reconcile.Result{Requeue: true}, err
	}

	// Write the business logic here
	for i := range pod.Status.ContainerStatuses {
		container := pod.Status.ContainerStatuses[i].Name
		restartCount := pod.Status.ContainerStatuses[i].RestartCount
		identifier := pod.Name + pod.Status.ContainerStatuses[i].Name
		if _, ok := restartList[identifier]; !ok {
			restartList[identifier] = restartCount
		} else if restartList[identifier] < restartCount {
			log.Info("Reconciling container: " + container)
			log.Info(container, restartCount)
			restartList[identifier] = restartCount
		}
	}
	return reconcile.Result{}, nil
}

func main() {
	// Setup the Logger
	log := zapr.NewLogger(zap.NewExample()).WithName("pod-what-crashes")

	restartList = make(map[string]int32)

	// Create a Manager, passing the configuration for KUBECONFIG
	// To watch all namespaces leave the namespace option empty: ""
	log.Info("Setting up the Manager")
	mgr, err := manager.New(config.GetConfigOrDie(), manager.Options{Namespace: ""})
	if err != nil {
		log.Error(err, "Unable to setup manager. Please check if KUBECONFIG is available")
		os.Exit(1)
	}

	ctrl, err := controller.New("pod-what-crashes", mgr, controller.Options{
		Reconciler: &ReconcilePod{client: mgr.GetClient()},
	})
	if err != nil {
		log.Error(err, "Failed to setup controller")
		os.Exit(1)
	}

	if err := ctrl.Watch(&source.Kind{Type: &v1.Pod{}}, &handler.EnqueueRequestForObject{}); err != nil {
		log.Error(err, "Failed to watch pods")
		os.Exit(1)
	}

	log.Info("Starting up the Manager")
	if err := mgr.Start(signals.SetupSignalHandler()); err != nil {
		log.Error(err, "Failed to start manager")
		os.Exit(1)
	}
}
```

Notice the verbosity of the output:

```bash
$ go run main.go
{"level":"info","logger":"pod-what-crashes","msg":"Setting up the Manager"}
{"level":"info","logger":"pod-what-crashes","msg":"Starting up the Manager"}
INFO[0096] Reconciling container: example                source="main.go:52"
INFO[0096] example1                                      source="main.go:53"
INFO[0141] Reconciling container: example                source="main.go:52"
INFO[0141] example2                                      source="main.go:53"
INFO[0196] Reconciling container: example                source="main.go:52"
INFO[0196] example3                                      source="main.go:53"
ERRO[0243] Pod Not Found. Could have been deleted        source="main.go:36"
# Press CTRL+C to quit
```

while at the same time:

```bash
$ oc create -f test.yaml; oc get pods controller-demo -w
pod/controller-demo created
NAME              READY   STATUS              RESTARTS   AGE
controller-demo   0/1     ContainerCreating   0          0s
controller-demo   0/1     ContainerCreating   0          8s
controller-demo   0/1     ContainerCreating   0          11s
controller-demo   1/1     Running             0          11s
controller-demo   0/1     Completed           0          40s
controller-demo   1/1     Running             1          43s	# Restarted. Output log.Info()
controller-demo   0/1     Completed           1          74s
controller-demo   0/1     CrashLoopBackOff    1          86s
controller-demo   1/1     Running             2          89s	# Restarted. Output log.Info()
controller-demo   0/1     Completed           2          119s
controller-demo   0/1     CrashLoopBackOff    2          2m10s
controller-demo   1/1     Running             3          2m24s	# Restarted. Output log.Info()

$ oc delete -f test.yaml 
pod "controller-demo" deleted									# Deleted. Output log.Error()
```

## Build the container

This controller is running locally, outside of the cluster.
Let's build a container image, push it to the k8s node and load it via `podman`.

```bash
mkdir -p build/bin; cd build
touch Dockerfile
cd bin
touch entrypoint; touch user_setup
```

#### build/Dockerfile

We will use the default base container image that [Operator SDK](https://github.com/operator-framework/operator-sdk) is using.

```docker
FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

ENV OPERATOR=/usr/local/bin/pod-what-crashes \
    USER_UID=1001 \
    USER_NAME=pod-what-crashes

# install operator binary
COPY pod-what-crashes ${OPERATOR}

COPY bin /usr/local/bin
RUN  /usr/local/bin/user_setup

ENTRYPOINT ["/usr/local/bin/entrypoint"]

USER ${USER_UID}
```

Sets up 3 `ENV` variables:

* `ENV OPERATOR` would be the path to your Operator binary (usually `/usr/local/bin/${OPERATORS_NAME}`)
* `ENV USER_UID` to be a number like `1001` that corrersponds to a normal user account.
* `USER_NAME` it passes the name of the operator as being a user (e.g. `$OPERATORS_NAME`).

It copies the Operator's binary to `/usr/local/bin` and the two generated bash scripts (`user_setup` and `entrypoint`).
It runs  the `user_setup` that creates the user as part of the `root` group along with its home directory and correct permissions
It uses an external file for the entrypoint, that is `/usr/local/bin/entrypoint`
Changes from the root user to the `USER_UID` user that was created before via the `user_setup` script.

So when we will build our operator, `podman inspect` to the image will look like this:

```json
        "Config": {
            "User": "1001",
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                "container=oci",
                "OPERATOR=/usr/local/bin/pod-what-crashes",
                "USER_UID=1001",
                "USER_NAME=pod-what-crashes"
            ],
            "Entrypoint": [
                "/usr/local/bin/entrypoint"
            ],
```

#### build/bin/entrypoint

Pretty straighforward:

```bash
#!/bin/sh -e

exec ${OPERATOR} $@
```

* The `sh -e` - exits the script if any command fails (non-zero return value)
* The `exec ${OPERATOR} $@` - will append any parameters to the entrypoint (which is the Operator binary).

#### build/bin/user_setup

```bash
#!/bin/sh
set -x

# ensure $HOME exists and is accessible by group 0 (we don't know what the runtime UID will be)
echo "${USER_NAME}:x:${USER_UID}:0:${USER_NAME} user:${HOME}:/sbin/nologin" >> /etc/passwd
mkdir -p ${HOME}
chown ${USER_UID}:0 ${HOME}
chmod ug+rwx ${HOME}

# no need for this script to remain in the image after running
rm $0
```

Make use of the `ENV` variables from the Dockerfile.
Make sure `${USER_NAME}` user is part of the `root` group in order to empower him to execute restricted commands (system privileges) that an ordinary user account cannot access.
Makes the user to be the owner of the `/root` directory (as it's new `$HOME`) and also gives him `rwx` persmissions on it.

### build the container

The command to build:

```bash
export OPERATOR="pod-what-crashes"
GOOS=linux go build -o ./build/${OPERATOR}
export IMAGE="${OPERATOR}:testing"
docker build -f ./build/Dockerfile -t ${IMAGE} ./build
```

The build-log should look similar to this:

```docker
Sending build context to Docker daemon  82.01MB
Step 1/7 : FROM registry.access.redhat.com/ubi8/ubi-minimal:latest
 ---> db39bd4846dc
Step 2/7 : ENV OPERATOR=/usr/local/bin/pod-what-crashes     USER_UID=1001     USER_NAME=pod-what-crashes
 ---> Running in faa7f2d53e16
Removing intermediate container faa7f2d53e16
 ---> d3bf1178e766
Step 3/7 : COPY pod-what-crashes ${OPERATOR}
 ---> 2e4e69c9b2aa
Step 4/7 : COPY bin /usr/local/bin
 ---> 46ef33b271cb
Step 5/7 : RUN  /usr/local/bin/user_setup
 ---> Running in f95375365d95
+ echo 'pod-what-crashes:x:1001:0:pod-what-crashes user:/root:/sbin/nologin'
+ mkdir -p /root
+ chown 1001:0 /root
+ chmod ug+rwx /root
+ rm /usr/local/bin/user_setup
Removing intermediate container f95375365d95
 ---> 1d8f3160fb8b
Step 6/7 : ENTRYPOINT ["/usr/local/bin/entrypoint"]
 ---> Running in 71a0bd3f11fa
Removing intermediate container 71a0bd3f11fa
 ---> b46c0c0d73b5
Step 7/7 : USER ${USER_UID}
 ---> Running in 1683f187f7ce
Removing intermediate container 1683f187f7ce
 ---> 327968c09d20
Successfully built 327968c09d20
Successfully tagged pod-what-crashes:testing
```

Make sure it is loaded correctly to the docker image repository:

```docker
$ docker images
REPOSITORY                                    TAG                 IMAGE ID            CREATED              SIZE
pod-what-crashes                              testing             327968c09d20        About a minute ago   148MB
```

Push it to the CRC VM:

Make sure you can SSH into the VM created by _CRC_.
Go to your `~/.zshenv` and add:

```zsh
export CRCIP=$(crc ip)
alias sshcrc="ssh -o ConnectionAttempts=3 -o ConnectTimeout=10 -o ControlMaster=no -o ControlPath=none -o LogLevel=quiet -o PasswordAuthentication=no -o ServerAliveInterval=60 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@${CRCIP} -o IdentitiesOnly=yes -i ${HOME}/.crc/machines/crc/id_rsa -p 22"
```

Source it: `source ~/.zshenv`.
To make sure there is no problem connecting to the VM, type `crcssh`.
Proceed with copying over the image:

```bash
$ docker save pod-what-crashes:testing > image-name.tar
$ scp image-name.tar core@`crc ip`:
$ sshcrc
[core@crc-w3434-master-0]$ sudo podman load -i image-name.tar
```

Make sure it is loaded:

```bash
$ sudo podman images | grep testing
localhost/pod-what-crashes                       testing        327968c09d20   6 minutes ago   149 MB
```

In case you are curious to see how the environment looks like:

```bash
$ sudo podman run -it --rm --entrypoint /bin/bash localhost/pod-what-crashes:testing

[pod-what-crashes@f46dbd39028e /]$ whoami
pod-what-crashes

[pod-what-crashes@f46dbd39028e /]$ id
uid=1001(pod-what-crashes) gid=0(root) groups=0(root)

[pod-what-crashes@f46dbd39028e /]$ groups
root

[pod-what-crashes@f46dbd39028e /]$ cat /etc/passwd | grep `whoami`
pod-what-crashes:x:1001:0:pod-what-crashes user:/root:/sbin/nologin

[pod-what-crashes@f46dbd39028e /]$ ls -lh /usr/local/bin
total 40M
-rwxr-xr-x. 1 root root  34 Feb 24 17:12 entrypoint
-rwxr-xr-x. 1 root root 40M Feb 25 01:51 pod-what-crashes

[pod-what-crashes@f46dbd39028e /]$ ls -ld $HOME
drwxrwx---. 1 pod-what-crashes root 6 Jan 29 19:42 /root
```

Then exit from the conainer by typing `exit` and also exit from the VM, by typing again `exit`.

## Deploy to k8s

We will create:

* a namespace
* a serviceaccount
* a clusterrole
* a clusterrolebinding
* a deployment

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-controller
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-what-crashes
  namespace: my-controller
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-what-crashes-role
  namespace: my-controller
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["*"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pod-what-crashes-access
  namespace: my-controller
subjects:
- kind: ServiceAccount
  name: pod-what-crashes
  namespace: my-controller
roleRef:
  kind: ClusterRole
  name: pod-what-crashes-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pod-what-crashes
  namespace: my-controller
  labels:
    k8s-app: pod-what-crashes
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: pod-what-crashes
  template:
    metadata:
      labels:
        k8s-app: pod-what-crashes
    spec:
      serviceAccountName: pod-what-crashes
      containers:
      - name: pod-what-crashes
        image: localhost/pod-what-crashes:testing
        imagePullPolicy: Never
        resources:
          limits:
            cpu: 200m
            memory: 300Mi
          requests:
            cpu: 150m
            memory: 250Mi
```

Run:

```bash
$ kubectl create -f deployment.yaml 

namespace/my-controller created
serviceaccount/pod-what-crashes created
clusterrole.rbac.authorization.k8s.io/pod-what-crashes-role created
clusterrolebinding.rbac.authorization.k8s.io/pod-what-crashes-access created
deployment.apps/pod-what-crashes created
```

Check the controller is running on the cluster:

```k
$ kubectl -n my-controller get pods
NAME                               READY   STATUS    RESTARTS   AGE
pod-what-crashes-b9855667b-pnj28   1/1     Running   0          24s
```

You can see the logs like this:

```k
$ kubectl -n my-controller logs -l k8s-app=pod-what-crashes -f
{"level":"info","logger":"pod-what-crashes","msg":"Setting up the Manager"}
{"level":"info","logger":"pod-what-crashes","msg":"Starting up the Manager"}
```

Notice that we are using a `clusterRole` and a `clusterRoleBinding` instead of a `Role` or a `RoleBinding`.
Otherwise, our controller would not be able to list resources for all the Pods in the cluster in every namespace.
We would most probably have ended up with this error message:

```k
kubectl logs pod-what-crashes-5f9bc86dbd-l6849

E0224 18:08:27.976036       1 reflector.go:153] pkg/mod/k8s.io/client-go@v0.17.2/tools/cache/reflector.go:105: Failed to list *v1.Pod: pods is forbidden: User "system:serviceaccount:my-controller:pod-what-crashes" cannot list resource "pods" in API group "" at the cluster scope
```

If we wanted to look for stuff happening only in its own namespace, then we could have modified the manager:

```go
namespace := "my-controller"
mgr, err := manager.New(cfg, manager.Options{Namespace: namespace})
```

In case you want to remove the image from the VM:

```bash
sudo podman rmi localhost/pod-what-crashes:testing
Untagged: localhost/pod-what-crashes:testing
Deleted: 0f10cf2c88e9f6943385543e6e324223ec1f470b19367945d708737c1dbfc18c
```

I will continue this tutorial by adding a CRD and CR.
