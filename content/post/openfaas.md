+++
categories = ["tutorial"]
date = "2017-11-08T22:08:35+02:00"
tags = ["openfaas", "serverless", "tutorial", "kubernetes", "docker", "containers", "cluster"]
title = "How to start with OpenFaaS"

+++

## Introduction

Before we get into what is serverless or openfaas, I would like to talk about the
concept behind this. So, before going into the details, I want to give you the big
picture of this new way of developing applications and how the users are supposed
to use them.

### Containers are now more efficient than ever

So let’s go back in time, when computers were enormous things and filled complete
rooms. They were very long lived and hard to change. Today, we have got smaller
computers, and especially with the *IoT* we have lot’s of tiny hardware which
they still fill rooms. Even these tiny things were still *“too large”* and
*“big enough”* to manage, so we created the virtual machines, so to slice up these
computers without taking space. We still use these virtual machines and we still are
managing them like normal computers (unless you are Netflix). But these virtual servers
were still slow enough until we realise they exist: I mean they still need about a minute
or so to boot up and shutdown again. So, we still manage them as if they were normal
computers. But then we have got some really really small VMs, and this are containers.
These containers are much much much faster and much much much more efficient. In a matter
of fact, they are so fast and efficient that you can wrap every process inside a container.
See for example [RacherOS](https://rancher.com/rancher-os/), where everything runs inside
a docker container. System processes like `udev` and `ntp` are running inside docker. So,
really fast and efficient small things. Lately, we’ve got cluster-kind-of-schedulers
(so called orchestrators) for our containers.

That is essential simplified and changed the infrastructure into one **big process-list**.
It’s a list of processes that are running inside containers. And the infrastructure then
started to look like something like a **very big computer**. In the same way you can run `ps`
in your laptop, you can now run `ps` on your infrastructure and just see everything that
is running. When you see a process running in your laptop, you don’t care in which stick
of RAM it runs. In the same way, you don’t care where your process is running in Kubernetes.
If you start to care less about things, then you start not to observe the existence of
those things.The interesting thing about this that from the developers point of view, is
that the whole infrastructure became a whole lot more simpler.

So this is the first the first thing that changed. The VMs (containers) became so efficient
that people are wrapping all the dependencies needed inside them.

### A cloud for containers

What is new is *how computing is supplied* for people who are writing applications and that’s
the cloud. As I’ve told you earlier, we indeed are slicing up our computers, but they are
still hosted inside a physical computer. In the past that was constrained by the number of
computers you had in room and from the space of this room, but that’s not the case anymore.
We have this sort of infinite supply of computing which comes sort of out of nowhere. For
example, from the POV of the user, *Amazon EC2* looks like a limitless supply of machines.
Nobody worries about the servers (*e.g.* where they were), because it didn’t really matter.
What about running containers in the cloud? In other words, what about running processes in
the cloud? So, in some sense now we combine containers and cloud that computer looks like an
enormous computer that we run code on. We don’t really have constraints any more. This is
because we have containerization that allows us to wrap up our application inside with all
its dependencies and then have it boot up really quickly anywhere, regardless of where it is.
So that kind of generally is sort of a trend that is happening, so why am I talking about this ...

Actually, Google does this kind of stuff, and they do those stuff for years. So, what changes
today is that this technology has started to become available for everyone and lot’s of
companies are jumping in.

## What is serverless

Serveless doesn’t mean there are no servers. There are servers, they *do* exist. They are
just someone's else servers who is responsible for managing and scaling them up
for you. You just send the code, the code runs and you forget about it.

What do you mean *forget about it?* Well, there’s an element of a system managing them for
you. You see, when I told you earlier *there are somebody’s else servers*, I never told
you that this somebody is a real person. When you deploy a function in openFaaS,
Kubernetes takes care of managing these functions: if they are have problems, k8s will
fix them for you. If the usage increases, k8s will auto-scale them for you. If there’s a
new version, k8s will update them for you. So, we have system doing the hard work for us.
In this way, there’s no need to have different people maintaining different services. We
just need to have one  guy, who is the k8s administrator.

Kubernetes acts like Man-In-The-Middle between the user and the actual service. The service
is not online and it’s not listening on any port. It will be activated on demand, and die
after it completes its purpose. Because it can boot and shutdown within milliseconds, the
actual user doesn’t understand or feel this delay, so he feels like he is accessing an
online service. While this service is dead by default. It’s not running, it’s not listening
on any socket. That’s why we call it serverless, because although we are talking abouts
services and serves, in reality none of them is actually running - they run, only when
there’s a request for them. And this can’t be more efficient that that. Another funny name
for Serveless would be: Not-Yet-a-Service-as-a-Service.

### Benefits of Serveless

Serveless is kind of a way that allows you run code on this internet-size-computer.
It’s about treating the internet as one big computer where you can run code on and not having
to worry about where it’s been run. The reason that is happening right now is because we had
these two things that have been around for a long time: the internet and distributed systems.
But the timing now is perfect that these two things are becoming good enough to cooperate.
So, serveress is happening because of the intersection of container and cloud and it’s allowing
to do all sorts of stuff.

* You don’t have to manage or provision any servers
* The application is automatically scaling
* You pay for what you use (event-based)

## Function as a Service

openFaaS is an easy way to put your functions in Kubernetes by packaging functions as docker
or OCI containers. The idea is that your write your application as series of functions which
are triggered based on various things.

We are actually talking about a new architectural pattern of  building systems. The dinosaurs
in the room, they should remember a time where people were building monoliths. Heavyweight
applications, doing far too many things, slow to deploy, with trouble to test them, release
every 6 months etc. Then we broke those down into microservices, delegating the responsibilities,
so each component be responsible for less stuff to do. The focus is to be composable and we
deploy them usually with docker containers. Today, we are looking at Functions, as the next
step of that architectural evolution. Functions do one thing and do it well -- kind of similar
with the Unix philosophy of things. You can think of a function as small discreet and reusable
piece of code that you can deploy once and then forget about.

Functions in Serverless are not a long-running daemon.. I'd get bored that way. I work with
webhooks - so stick me in a serverless framework like OpenFaaS and forget about me. Just apply
oil from time to time.

Functions or microservices, are not going to replace completely your monoliths, but they can
work alongside with them. How? Building integrations. Helping the event flow between ecosystem.

### An alternative for AWS Lamda

One popular example of FaaS is Amazon Lambda. The idea with Amazon Lambda is that you can upload
your function to Amazon and then you can trigger that piece of code based on a bunch of things
that happen in Amazon. So you don’t have to worry about deploying a service, about scaling this
thing -- it just sorts of runs on cloud. The developer writes his function in a programming
language that Amazon supports, he installs all the dependencies on the local file system, bundle
this in a zip compressed file and upload it to the AWS cloud. At that point, Amazon will manage
all the infrastructure for you, the billing and the lifecycle of the application, and you don’t
have to think about your service anymore.

So, what if I don’t want to use Amazon?

The developer of openFaas was learning about AWS Lambda and he wanted to create his own function.
But, he had to spend some money, bill his credit card for 12 months and also deal with zip files
and stuff. All of these just didn’t felt right, so as docker captain he knew that it has to be a
better way of doing this. This project exists since May 2017 and since then it became the top
trending project overall on github. They were getting about 700 stars per month and lot of
production users getting in touch. Now they have Kubernetes support, Docker Swarm and also
asynchronous processing if needed (useful for machine learning).

This project, is really a community project. It’s a very healthy project, over a thousand of
commits and over 45 contributors and a ton of forks.

If you:

* I want to be able to use whatever language I want.
* I want to run it on whatever platform I need.
* I want to be limited in billing or five-minute windows.

Then use openFaaS.

## How it works

This is a cloud-native stack. Completely written in GoLang, completely open source with MIT
license.

The API Gateway: is where you define all of your functions. Each of them has a public route
and the users can access them.

The Watchdog is embedded in every container and this is the magic thing that allows the
container to become serveless. It does all the work for you.

The Prometheus underpins the whole stack and collects statistics. With these statistics we
can build customizable dashboard and and when a certain functions gets a lot of traffic,
then it automatically autoscales using the Docker Swarm or Kubernetes API.

## How to setup openFaaS in SUSE Containers as a Service Platform

### Contact your k8s cluster

I have setup this cluster using [CaaSP v2.0](https://www.suse.com/communities/blog/suse-caas-platform-2-now-generally-available/)
which is important to use a version equal or higher than `1.7`. Kubernetes upstream is already at version 1.8, while the CaaSP ships 1.7,
we are still fine going with that. Just make sure you have the kubeconfig at:  `cp ~/Downloads/kubeconfig ~/.kube/config`
or `export KUBECONFIG=~/Downloads/kubeconfig`

### Install kubectl

In this article, I am using openSUSE Tumbleweed as my client machine. So, in order to
install `kubectl` I have to do the following:

```bash
sudo zypper in kubernetes-node
```

Make sure you can contact your cluster:

```bash
$ kubectl cluster-info

Kubernetes master is running at https://d100.qam.suse.de:6443
Dex is running at https://d100.qam.suse.de:6443/api/v1/namespaces/kube-system/services/dex/proxy
KubeDNS is running at https://d100.qam.suse.de:6443/api/v1/namespaces/kube-system/services/kube-dns/proxy
Tiller is running at https://d100.qam.suse.de:6443/api/v1/namespaces/kube-system/services/tiller/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

The cluster doesn't have any deployments at the moment:

```bash
$ kubectl get deployments

No resources found.
```

### Install Helm

If you have bootstrapped your CaaSP v2.0 cluster with `tiller` then it makes
sense to use Helm. Helm is a tool that streamlines installing and managing
Kubernetes applications. Think of it like `apt/yum/homebrew/zypper` for Kubernetes.

Helm has two parts: a client (helm) and a server (tiller)
Tiller runs inside of your Kubernetes cluster, and manages releases (installations) of your charts.
Helm runs on your laptop, CI/CD, or wherever you want it to run.
Charts are Helm packages that contain at least two things:

1. A description of the package (Chart.yaml)
2. One or more templates, which contain Kubernetes manifest files

Charts can be stored on disk, or fetched from remote chart repositories (like Debian or RedHat packages)

Install Helm client: (currently it's officially supported only in TW)

```bash
sudo zypper in helm
```

More info: [Helm Documentation](https://software.opensuse.org/package/helm)


Clone the repo:

```bash
git clone https://github.com/openfaas/faas-netes
cd faas-netes
```

How to Install it:

```bash
$ helm upgrade --install --debug --reset-values --set async=false openfaas openfaas/
```

or without RBAC:

```bash
helm upgrade --install --debug --reset-values --set async=false --set rbac=false openfaas openfaas/
```

How to delete it (in case you don't want it anymore):

```bash
helm delete --purge openfaas
release "openfaas" deleted
```

Make sure it works:

See the deployments, there must be 4:

```bash
$ kubectl get deploy

NAME           DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
alertmanager   1         1         1            1           1m
faas-netesd    1         1         1            1           1m
gateway        1         1         1            1           1m
prometheus     1         1         1            1           1m
```

See the services:

```bash
$ kubectl get svc

NAME                    CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
alertmanager            172.24.251.90    <none>        9093/TCP         1h
alertmanager-external   172.24.200.36    <nodes>       9093:31113/TCP   1h
faas-netesd             172.24.225.192   <none>        8080/TCP         1h
faas-netesd-external    172.24.132.11    <nodes>       8080:31111/TCP   1h
gateway                 172.24.186.132   <none>        8080/TCP         1h
gateway-external        172.24.193.30    <nodes>       8080:31112/TCP   1h
kubernetes              172.24.0.1       <none>        443/TCP          2h
mememachine             172.24.159.94    <none>        8080/TCP         1h
prometheus              172.24.69.16     <none>        9090/TCP         1h
prometheus-external     172.24.212.7     <nodes>       9090:31119/TCP   1h
```

## Create a function from the UI

Go to the OpenFaaS Portal by accessing on of your pods:

```bash
# kubectl describe pod gateway-640487255-0l6kv | grep Node:
Node:		452cc28514da4ab3a8c7089a2291be9e.infra.caasp.local/10.161.229.39

# nslookup 10.161.229.39
39.229.161.10.in-addr.arpa	name = d295.qam.suse.de.
```

Perfect, so I know that I can access `d295.qam.suse.de`. Well, pretty much
I can access any node from my cluster, and in order to prove that to you
I am going to access `d100.qam.suse.de` instead:

Go to: https://d100.qam.suse.de:31112/ui/

```bash
Click at: Create New Function

Image: functions/alpine  <--- the docker image: https://hub.docker.com/r/functions/alpine/
Service name: stronghash <--- the name of the function to call
fProcess: sha512sum      <--- the binary
Network: func_functions  <--- always the same
```

Test it from the command line:

```bash
curl -X POST https://d100.qam.suse.de:31112/function/stronghash -d 'opensuse'
```

It should return the hash:

```bash
410656168586fbe6717f934180e79184b441932ff2ac449af5b89237bb28b754e0491ab9bcd5651f354190fc592b8566caf37edfe6b4ea39ebe3f1210d8535c4  -
```

## Install the command line tool

Run this:

```bash
curl -sSL https://cli.openfaas.com | sudo sh
```

This will download the binary and then it will also move it to `/usr/local/bin`

Make sure it works:

```bash
drpaneas@localhost:~/github/faas-netes> faas-cli list --gateway https://d100.qam.suse.de:31112
Function                        Invocations     Replicas
mememachine
```

Let me show you how you can call the function from the command-line:

```bash
faas-cli invoke stronghash --gateway https://d100.qam.suse.de:31112/
echo "hello world" | faas-cli invoke stronghash --gateway https://d100.qam.suse.de:31112/
curl -X POST https://d100.qam.suse.de:31112/function/stronghash -d 'panos'
```

## Try other people's functions:

GitHub Repo with functions: [FaaS and Furious](https://github.com/faas-and-furious)


Import a function:

```bash
faas-cli deploy -f https://raw.githubusercontent.com/faas-and-furious/openfaas-mememachine/master/mememachine.yml -e read_timeout=60 -e write_timeout=60  --gateway https://d100.qam.suse.de:31112
```

Expected outout would be:

```bash
Parsed: https://raw.githubusercontent.com/faas-and-furious/openfaas-mememachine/master/mememachine.yml
Deploying: mememachine.
No existing service to remove
Deployed.
URL: https://192.168.178.122:31112/function/mememachine

202 Accepted
```

Test it:

```bash
echo '{"image": "https://vignette4.wikia.nocookie.net/factpile/images/6/66/Lotr-boromir-1280jpg-
b6a4d5_1280w.jpg","top": "ONE DOES NOT SIMPLY JUST","bottom": "DEPLOY TO PRODUCTION"}' | faas-cli invoke mememachine --gateway https://192.168.178.122:31112/ > meme.jpg
```

However, if you don't want to force the users to use `faas-cli invoke` they can use `curl` also:

```bash
curl --request POST --data-binary '{"image": "https://vignette4.wikia.nocookie.net/factpile/images/6/66/Lotr-boromir-1280jpg-b6a4d5_1280w.jpg","top": "ONE DOES NOT SIMPLY JUST","bottom": "DEPLOY TO PRODUCTION"}' https://d100.qam.suse.de:31112/function/mememachine > meme.jpg
```

## Create your own functions

```bash
faas-cli new --lang python3 hello-python
```

Edit the `yml` file and use your `DockerHub` name:

e.g. `image: drpaneas/hello-python`

You can read the code in the `handler.py` and include any Python3 module in `requirements` file.
After that, let's build: `faas-cli build -f hello-python.yml`.

Then we push the image to DockerHub: `docker push drpaneas/hello-python`
and last thing is to deploy it: `faas-cli deploy -f hello-python.yml --gateway https://d100.qam.suse.de:31112/`

To test if it works:

```bash
curl -X POST https://d100.qam.suse.de:31112/function/hello-python -d 'Lunch and Learn'
```

## Dig deeper

One way to start playing with OpenFaaS is to study other's people functions and code.
So in this example, I am going through the *youtubedl* funtion:

Pull the Docker image: `docker pull crosbymichael/youtubedl`

The dockerfile of this image can be found at: [https://hub.docker.com/r/crosbymichael/youtubedl/~/dockerfile/](Dockerfile)

```dockerfile
FROM crosbymichael/python RUN pip install --upgrade youtube_dl && mkdir /download
WORKDIR /download
ENTRYPOINT ["youtube-dl"]
CMD ["--help"]
```

So it just uses another layer: `crosbymichael/python` and it installs the `youtube-dl` via `pip`.
It also creates a `/download` directory and `cd` into it. Last but not least, when somebody
is going to `docker run` this container it will automatically trigger the binary `youtube-dl`.
If no arguments are given, then the `--help` will be called. In order to pass the downloaded
video into the host machine, we need to mount a volume (the parent directory) to the `/download`.

This is an example of usage:

```bash
localhost:~ # mkdir test

localhost:~ # cd test/

localhost:~/test # docker run -v $(pwd):/download crosbymichael/youtubedl "https://www.youtube.com/watch?v=Nw42q1ofrV0"

        [youtube] Confirming age
        [youtube] Nw42q1ofrV0: Downloading webpage
        [youtube] Nw42q1ofrV0: Downloading video info webpage
        [youtube] Nw42q1ofrV0: Extracting video information
        WARNING: [youtube] Nw42q1ofrV0: Skipping DASH manifest: u'dashmpd'
        [download] Destination: Service Discovery for Docker via DNS-Nw42q1ofrV0.mp4
        [download] 100% of 83.34MiB in 00:1528MiB/s ETA 00:005n ETA

localhost:~/test # ls

        Service Discovery for Docker via DNS-Nw42q1ofrV0.mp4
```

So it worked !

Before we move on, I would like to pause for a minute and check the base image: `crosbymichael/python`

The dockerfile can be found at: [https://hub.docker.com/r/crosbymichael/python/~/dockerfile/](Dockerfile)

```dockerfile
FROM debian:jessie

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    libxml2-dev \
    python \
    build-essential \
    make \
    gcc \
    python-dev \
    locales \
    python-pip

RUN dpkg-reconfigure locales && \
    locale-gen C.UTF-8 && \
    /usr/sbin/update-locale LANG=C.UTF-8

ENV LC_ALL C.UTF-8
```

So, as you can see this just a `debian` `jessie` container with some pre-installed packages and some basic
locale configuration. Nothing really special, but good to know.

In order to convert this youtube-dl container into a function, we create the following Dockerfile:

```dockerfile
FROM crosbymichael/youtubedl
ENTRYPOINT []

ADD https://github.com/openfaas/faas/releases/download/0.6.7a/fwatchdog /usr/bin
RUN chmod +x /usr/bin/fwatchdog
COPY entry.sh   .
RUN chmod +x entry.sh
ENV fprocess="./entry.sh"

CMD ["fwatchdog"]
```

We are using the `crosbymichael/youtubedl` simply because it already contains the `youtube-dl` binary.
Then we pass whatever parameters the user is going to pass: e.g. `/dev/stdin`
What is standard is the fwatchdog thingy:

```bash
        ADD https://github.com/alexellis/faas/releases/download/0.5.8-alpha/fwatchdog /usr/bin
        RUN chmod +x /usr/bin/fwatchdog
```

Then we need to run the actual binary youtube-dl. This time we are going to differ a little bit and run it through a script:
The entry.sh is the following:

```bash
#!/bin/sh

while read line
do
  echo "$line"
done < "${1:-/dev/stdin}"

youtube-dl $line --no-warnings --quiet -o -
```

The script uses the `read` command which is used to read from the `standard input`. Usually it is used for user input.
e.g.

```bash
        echo "What is your name?"
        read name
```

It is reading line by line and the `return code` of the `read` command is `zero`, unless an end-of-file
character is encountered, Used in a `while loop` it actually reads a file line by line assigning the
value to a called `line`.


The `${1:-/dev/stdin}` is an application of bash parameter expansion that says:
`return` the value of `$1`, unless `$1` is `undefined` (no argument was passed) or its `value` is the empty string (""or '' was passed).
Notice: The variation `${1-/dev/stdin}` would only return `/dev/stdin` if `$1` is `undefined` (if it contains any value, even the *empty string*, it would be returned).

Also To output to stdout use ``-o -``. Which means that the output of `youtube-dl` will be on ... terminal.
So, an example would be:

```bash
youtube-dl https://www.youtube.com/watch?v=Nw42q1ofrV0 --no-warnings --quiet -o - > video.mp4
```

Last but not least, we build the image:

```bash
sudo docker build -t drpaneas/faas-youtubedl .
[sudo] password for root:

Sending build context to Docker daemon 79.36 kB
Step 1 : FROM crosbymichael/youtubedl
 ---> fe8cd02e824c
Step 2 : ENTRYPOINT
 ---> Using cache
 ---> 60dd05daf068
Step 3 : ADD https://github.com/openfaas/faas/releases/download/0.6.7a/fwatchdog /usr/bin
Downloading [==================================================>] 4.111 MB/4.111 MB
 ---> 501c6b53a744
Removing intermediate container 5f3791264b52
Step 4 : RUN chmod +x /usr/bin/fwatchdog
 ---> Running in debc6877965e
 ---> d612ca111d3e
Removing intermediate container debc6877965e
Step 5 : COPY entry.sh .
 ---> c43786aa59ce
Removing intermediate container c23f07b009cc
Step 6 : RUN chmod +x entry.sh
 ---> Running in 2d7dcfa1e849
 ---> 49f17f1f383f
Removing intermediate container 2d7dcfa1e849
Step 7 : ENV fprocess "./entry.sh"
 ---> Running in dc8636221f1c
 ---> 5bdcd93093e8
Removing intermediate container dc8636221f1c
Step 8 : CMD fwatchdog
 ---> Running in f844ace7ad7e
 ---> 7ced4553f05c
Removing intermediate container f844ace7ad7e
Successfully built 7ced4553f05c
```

Next, it's time to `push` that image to dockerhub. Let's try it:
First authenticate yourself:

```
sudo docker login -u <drpaneas> -p $PASSWORD
Password:
Login Succeeded
```

Then push:

```bash
sudo docker push drpaneas/faas-youtubedl

The push refers to a repository [docker.io/drpaneas/faas-youtubedl]
58e5092cc396: Pushed
af14a52c65fd: Pushed
e2c247661ac2: Pushed
a2ce316698cd: Pushed
5f70bf18a086: Layer already exists
280da4fe2a80: Layer already exists
151ecc7d9364: Layer already exists
8df1ad35a1bf: Pushed
1646024fc401: Layer already exists
latest: digest: sha256:efa600d5123d4a91d15eec53ea7cc00e7e102ed8c45cb7b9f00095590210c1b4 size: 3234
```

Now use 'faas-cli' to deploy it:

```bash
faas-cli deploy \
 --gateway https://192.168.178.122:31112 \
 --image drpaneas/faas-youtubedl \
 --name youtubedl \
 --fprocess="sh ./entry.sh"

No existing service to remove
Deployed.
URL: https://192.168.178.122:31112/function/youtubedl

202 Accepted
```

Test it:`curl https://192.168.178.122:31112/function/youtubedl -d "https://www.youtube.com/watch?v=nG2rNBFzkGE" > cat_jump.mov`

## From an idea to a function

Idea: We want to pass an image and resize it by 50%

ImageMagick permits image data to be read and written from the standard streams
`STDIN` (standard in) and `STDOUT` (standard out), respectively, using a pseudo-filename of `-`

example: `cat input.jpg | convert - -resize "50%" output.jpg`

Other pipes can be accessed via their *file descriptors* (as of version 6.4.9-3).
The file descriptors `0`, `1`, and `2` are reserved for the standard streams `STDIN`, `STDOUT`,
and `STDERR`, respectively, but a pipe associated with a file descriptor number `N>2` can be accessed
using the pseudonym `fd:N`. (The pseudonyms `fd:0` and `fd:1` can be used for `STDIN` and `STDOUT`).

example: `cat input.jpg | convert - -resize "50%" fd:1 > output.jpg`

As a result, the `fprocess` will be:

`fprocess="convert - -resize 50% fd:1"`

We just need an image with 'imagemagick' pkg installed. Then I will add the 'watchdog'.

```bash
mkdir imagemagick && cd imagemagick
vi Dockerfile

        FROM opensuse:latest

        ADD https://github.com/openfaas/faas/releases/download/0.6.7a/fwatchdog /usr/bin
        RUN chmod +x /usr/bin/fwatchdog \
        && zypper -n in -y -l ImageMagick

        ENV fprocess="convert - -resize 50% fd:1"

        HEALTHCHECK --interval=5s CMD [ -e /tmp/.lock ] || exit 1
        CMD ["fwatchdog"]
```

Build it: `sudo docker build -t drpaneas/resize .`
Push: `sudo docker push drpaneas/resize`
Convert: `faas-cli deploy --gateway https://192.168.178.122:31112 --image drpaneas/resize --name resize --fprocess="convert - -resize 50% fd:1"`

Call it: `curl https://192.168.178.122:31112/function/resize --data-binary @meme.jpg > smaller.png`
Call it alternative:  `cat whale.jpg | faas-cli invoke shrink-image > whale-small.jpg`

## Build a generic image

Every single function I’ve encountered upon in the repositories, it’s consisted of its
own Docker image, usually hosted in DockerHub. So, is this a problem? Well, no ... and yes ...
I guess it doesn’t feel right to create so much overlap. Especially when you are a lazy
guy - like me - then you start to look for base patterns which you could possibly re-iterate.
Then, not exactly out of the sudden, I end up with the *fellowship of the tabs*.

But before changing things, you must first understand them.

You see, I am not a developer. Truth is I speak a little bit of C++ and Python, but I am not
close to anything like a native speaker. And this is a good thing. Maybe. So, how a non-developer
guy write his own functions? Easy: He doesn’t, because he doesn’t have to. You see, in our age,
there’s always Someone Out There (TM), who has possibly think of what you’re thinking. Fortunately,
this Someone or else, has already implemented it.

OpenFaaS works also with binaries. So, I thought ... let’s create a functions based on
these utilities or combinations of those. Well, someone could ask: why you should do such a thing
when you already have this functionality in your PC?

So, pick up a distro:

```bash
FROM alpine:latest

Next, include the watchdog:

ADD https://github.com/openfaas/faas/releases/download/0.6.5/fwatchdog /usr/bin
RUN chmod +x /usr/bin/fwatchdog

Optionally, include a healthcheck:

HEALTHCHECK --interval=5s CMD [ -e /tmp/.lock ] || exit 1

And run watchdog:
CMD ["fwatchdog"]
```

That’s it. That’s my basic image.

Now, for every utility I need, can just call this one and add my function, or to be precise: my fprocess:

```bash
FROM functions/alpine:latest
ENV fprocess "/bin/cat"
```

Build them all: `faas-cli build -f samples.yml --parallel 4`
[https://github.com/openfaas/faas/tree/master/sample-functions](Sample Functions)

