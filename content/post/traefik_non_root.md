+++
categories = ["tutorial"]
date = "2019-01-16T15:39:35+02:00"
tags = ["tutorial", "ingress", "traefik", "minikube", "opensuse", "non-root"]
title = "How to run Traefik ingress controller as non-root"

+++

## What is ingress?

Ingress are (in a sense) reverse-proxies. But to understand, you need to know first what a proxy is -- and only then
will be able to understand the _reverse_ of it.

### What is a proxy?

For those of you who do not know what a proxy is, the word `proxy` describes someone/something acting on behalf of
someone/something else. In terms on networking, when we are talking about a `proxy server` we are talking about one
server that is acting on behalf of another server. The most typical kind of proxy is the `web proxy` or `forward proxy`.
In this case, the proxy retrieves data from another web site on behalf of the original requestee.

For an example, I will list three computers connected to the internet.

> * **A** = your computer using a `web browser` (e.g. Firefox or Chrome) on the internet
> * **B** = the proxy web server, e.g. `182.253.188.180:8080` (google for _free proxy list_)
> * **C** = the web site you want to visit, www.example.com

Normally, one would connect directly from `A --> C`

However, in some scenarios, it is better to have `B --> C` on behalf of `A`, which chains as follows: `A --> B --> C`.

#### Why would one need a proxy?

Using someone else to do the job for you is needed when you cannot do the job yourself. For example `A` is _unable_ to
access `C` directly because:

> - He lives in North Korea and their Goverment has prohibited access to certain websites (assuming `C` is one of them)
> - The sysadmin of the company has blocked access to [facebook](facebook.com) during business hours because their employees are wasting too much time there.
> - Junior school has blocked access to [pornhub](pornhub.com)

Or another reason to use someone in the middle to do the job for you, is because you might want to hide yourself
(especially when this is a strange/illegal job). So let's say that you are:

> - trying to attack `C` and you want to stay (kinda) anonymous.
> - spamming `C` and the admin has blocked you `A`.

### What is a reverse proxy?

Let us see again what we have here:

> * **A** = your computer, or "client" computer on the internet
> * **B** = the reverse proxy web site, proxy.example.com
> * **C** = the web site you want to visit, www.example.net

Normally, one would connect directly from `A --> C`.

However, in some scenarios, it is better for the administrator of `C` to restrict or disallow direct access and force
visitors to go through `B` first. So, as before, we have data being retrieved by `A --> C` on behalf of `B`, which
chains as follows: `X --> Y --> Z.`

What is **different** this time compared to a `forward proxy`, is that this time the `user A` **does not know** he is
accessing `C`, because the user `A` only sees he is communicating with `B`. The server `C` is invisible to clients and
only the reverse proxy `B` is visible externally. A reverse proxy requires no (proxy) configuration on the client side.

The client `A` thinks he is only communicating with `B` (`X --> Y`), but the reality is that `B` forwarding all
communication (`A --> B --> C` again).

#### Why would one need a reverse proxy?

This is the case when you are not the user (`A) -- the visitor -- but the administrator of the website (`C`). Sometimes
you might want to force all the traffic to pass through `B` first because:

> * There are so many visitors and a single webserver cannot keep up with the _load_. So, instead of having only one single webserver, you have many webservers scuttered all over the world that only `B` knows how to access them. So, users are visiting `B` and then this server using an algorithm finds the webserver that is the closest to them and redirects them to use this one. This is part of how the `CDN` concept works.

> * You want to run your services internall and you do not want to expose them to the world. So only `B` has access to your internal network and routes the traffic accordingly.

## How all this is related to Kubernetes?

The only way to expose Pods to the outside world is through services. When we deploy those pods they are __not__
available to the outside world. Typically, in order to be able to access the pods, you have to be part of the cluster.
So to enable the communication of between the pods and the outside world, we need to configure services (notice that
services are required for discovery).

Some services are always meant to be used internally. For example a database. You don not want to expose your database
to the outside world. So this would be available only internally and withing the cluster, across the pods. According
to k8s terminology, these type of services are called `ClusterIP`.

There are some other pods that need to be accessible from the outside. Which means you need to have external endpoints
or `DNS names` or `CNAMES` so you can actually have internet access on these pods. To do that you have to configure the
external service in order to have access to the outside world. These services are typically called `NodePort`. They are
reachable through the `<NODE-IP> : <NodePort-endpoint>`. This is going to be available on every node. So if you know
the IP Address of a Node, you can hit any Node and give the access any external nodeport service.

Using the concept of **labels** and **selectors** we can associate the services with the appropriate back-end pods. So
when a service end-point is hit, it will route the traffic in any of the _123456_-ports deployed in any node.

In case you are deploying your nodes on a Public Cloud (eg. Google Computing, EC2 or Azure) you can also configure a
cloud loadbalancer. This is using the cloud specific APIs to provision a load balancert and wires the NodePort to the
LoadBalancer. So, it will 'automate' the step of exposing Pods on a NodePort and then creating a LoadBalancer and
manually pointing the LoadBalancer to all the NodePorts. So using the 'LoadBalancer' type, k8s will use the underlying
cloud provider to automatically wire up the port forwarding to appropriate Nodeports running accross the cluster.

If you exposing Pods on the Internet, you are basically exposing NodePorts, and NodePorts can be forwarded to a
LoadBalancer.

### Typical Problems

* External URLS:

> When you are deploying a public facing application on a k8s cluster, is creating a new loadbalancer for every service. So that means if you have multiple services you want all of them to share a Load Balancer and that is very difficult.

* Load Balancers:

> If you are using the type LoadBalancer in your services definition you will end-up creating a new LoadBalancer for every service. So it is not a very optimal way. Another way is deploying k8s in your data-center on bare-metal and you might already have a physical loadbalancer like 'F5'. And how would you point that in your existing deployment in your k8s cluster?

* SSL-terminated endpoints:

> How do you configure SSL termination?

* Name-based virtual hosting

> How do you create a very clean mechanism of routing your traffic to appropriate service end-points without creating a lot of back-end clutter configuration?

### Solution: Ingress Controller

To solve this problem, the community started building a thing called as an `Ingress`. An Ingress is nothing but a
collection of rules that will allow inbound connections to reach the cluster services. Ingress as it itself is not a
Load Balancer. Ingress as itself is a physical represantiona of an 'edge' device. It is logical controller that will
be mapped into one of your Load Balancer (either cloud or physical) and it will create a set of rules. These rules
will route the traffic -- at runtime -- to an appropriate end-point. And obviously you cannot use an ingress to route
traffic to a ClusterIP, because ClusterIP is never reachable to the outside world. So if you have a set of Pods that
are exposed to the outside world through NodePort and you want a very clean mechanism to expose them, and create a set
of rules, then you actually create an Ingress.

An Ingress is a level above service. And it is configured to expose services through 'External URLs'. This is the
preferred way and the best practice, to wire-up a CNAME to your service endpoint. So if you want to configure an
external URL using the nodeport in its raw form it is not a good idea. You should actually go for an ingress and made
this as an intermediary between your domain name and your endpoint. So it decouples your physical deployment from your
logical domain name. So when you are actually changing any definition you can just tweak your load balancer or ingress
and the CNAME remains the same. That gives you a nice and clean mechanism to decouple your domain-names from your
NodePorts. Of course a collection of LoadBalancers can be integrated in k8s through ingress you can bring multiple
varieties of LoadBalancer like F5, HA Proxy, nginx ... and you can very easily integrate that with k8s. And because you
have a layer above the services you can also off-load SSL termination. So you can handle SSL at the ingress while
keeping your NodePorts out of the picture. You can basically add your LetsEncrypt certificate at the Ingress level and
this will handle the TLS termination, so you don not have to touch the NodePort. You can also do
`Name-based virtual hosting` so basically you will have the same IP address but you will have multiple hostnames,
for example:

> `food.bar.com` --> different service endpoint and `abc.bar.com` --> to another service endpoint.

So you can create a complicated routing logic but on the Ingress level. This gives you plenty of room to play with
the configuration. And once again: **Ingress cannot function if your do not have services**. It is a decoupling layer
between Internet and your NodePorts.


