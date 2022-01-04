+++
categories = ["gitops"]
date = "2022-01-04T11:39:35+02:00"
tags = ["tutorial", "gitops", "kubernetes", "git"]
title = "What GitOps is"

+++

# What GitOps is

GitOps is a set of best practices to update or rollback your application, nowadays mostly in a cloud (e.g. k8s) environment. As the name implies, the whole process is controlled by Git, and the code includes both the application source and the infrastructure configuration. The goal, *as usual*, is to deploy fast and reliably.

In 2021, the [first OpenGitOps Standard v1](https://github.com/open-gitops/documents/blob/v1.0.0/PRINCIPLES.md) was created, to make sure we all GitOps enthusiasts speak the same language. For more information go to [opengitops.dev](https://opengitops.dev/).

#### Hm, what about DevOps?

DevOps is a mindset. GitOps is a set of best practices for deployments. They can both co-exist together.

## So what those "best" practices say?

1. The entire system (infra & apps or services) is described in a declarative way. Imagine like taking a cab, you tell the taxi driver where you would like to go (declarative way), instead of giving him instructions in GoogleMaps fashion (e.g. turn here - turn there).

*pseudocode example*

```shell=
if (SERVER is online) {
    if (SERVER == Ubuntu)    {use apt-get}
    if (SERVER == Fedora)    {use dnf}
    if (SERVER == SUSE)      {use zypper}
}
```

2. The desired state is versioned in Git, giving you the confidence that it cannot easily *just* change, and *if that happens*, then there will be a log entry about it, with a complete history.
3. Merged PRs are applied to the system automatically or semi-automatically (meaning to inform the admin a new desirable state has been detected, so they can decide when to apply it).
4. If there is a drift, reconciliation should detect this and try to fix it. If it cannot be fixed after a couple of minutes later, then an alert should be fired.

> Given Kubernetes is the new platform to deploy apps in scale, let's see two deployment scenarios: one with GitOps and one without.


## How to deploy in k8s without GitOps

1. Someone commits the source code for the app in Github, the CI system runs the tests and builds the container and pushes it into a container registry.
2. The CI (or another system) that has access to the k8s cluster, creates a deployment of the app using a bash script full of `kubectl`, `helm`, or any other command to interact with the cluster.
3. The application should now be deployed on the k8s cluster. Hopefully there were no problems.

__Problems with this workflow__

* The cluster status is changing using `kubectl` commands provided via a script or other programs talking directly with the API.
* The CI system has some kind of authorized access to the k8s cluster, and usually, this CI system is hosted somewhere externally, unless you have the tech & budget to build everything internally.


## How to deploy in k8s with GitOps

1. First step is the same: someone commits the source code for the app in Github, the CI system runs the tests and builds the container and pushes it into a container registry.
2. Someone (or another system) goes into another repository, the one that holds the the k8s manifests for the app and makes the necessary changes (e.g. update the container image tag the newly built one).
3. A k8s GitOps controller running into the cluster monitors this repo and detects this change. So it applies the new changes to the cluster according to the git repo.


Solutions used:
1. State is changed based on manifests, not commands or interacting on the fly with the API.
2. No external system needs access to the k8s cluster. The change is happening from within the cluster itself.

## GitOps use-case examples

1. Most common scenario for GitOps is for continuous deployment. If you use k8s and you handle your apps and services in a declarative manner, this is the most straightforward way of deploying them.
2. Easy roll-back of anything you deploy in your cluster no matter if you develop it or not. e.g. some databases or some monitoring tools. You can also deploy them in a similar fashion.
3. Detects configuration drift, meaning someone is doing stuff while they shouldn't.
4. Multi cluster scenario. When you have more than one cluster the usual question is what is running where and who changed what, when, why and so on. Having a git history and each cluster config in git, gives you all the answer you need without cluster debugging -- just `git diff`

## However, some might still don't adopt GitOps because ...

* Git is not your cup of tea (duh!)
* If you want to debug something on the cluster, it might be that the GitOps controller restores your changes back to the desired state. So you might want to disable it while doing this.
* GitOps is solving only one problem: deployment. For everything else (testing, building, monitoring, etc), you need to figure it out on your own.



