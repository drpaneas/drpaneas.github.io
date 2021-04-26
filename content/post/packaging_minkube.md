+++
categories = ["tutorial"]
date = "2018-09-28T16:29:35+02:00"
tags = ["tutorial", "minikube", "packaging", "cron", "opensuse"]
title = "Contribute to minikube in a nutshell"

+++

It's very easy to contribute to minikube (and other similar packages) when the only thing
that is needed is just a version bump in the *spec* file. You first need to install these:

```bash
# zypper in osc spec-cleaner
```

Configure your *~/.oscrc* file:

```bash
[general]
no_verify = 1
extra-pkgs = vim less mc

[https://api.opensuse.org]
user=pgeorgiadis           # CHANGE
email=pgeorgiadis@suse.com # CHANGE
pass=123456789             # CHANGE
trusted_prj=SUSE:SLE-12:GA openSUSE:13.2 openSUSE:Leap:42.3 openSUSE:Factory Base:System Virtualization:containers SUSE:SLE-12-SP3:GA SUSE:SLE-12:SLE-Module-Containers SUSE:Templates:Images:SLE-12-SP3:Base SUSE:SLE-12-SP3:Update openSUSE:Leap:42.3:Update
aliases=obs
build_repository = openSUSE_Tumbleweed
```

## Contributing in a nutshell

This is pkg that somebody else has prepared already. We are going just to bump the version:

```bash
# Create a dir to work inside
mkdir packaging

# Branch and checkout the package
osc bco minikube

# Change directory into it
cd home\:pgeorgiadis\:branches\:Virtualization\:containers/minikube/

# Change the version number to the current one
vi minikube.spec
# example:
# -Version:        0.28.2
# +Version:        0.29.0

# Download the new sources
oscsd

# Clean the spec file
spec-cleaner -i minikube.spec

# Add the new tarball
osc add v0.29.0.tar.gz

# Remove the old tarball 
osc rm v0.28.2.tar.gz

# Write the changelog
osc vc

# Commit the changes
osc ci

# Send the changes
osc sr

# Monitor the building with your browser
Firefox https://build.opensuse.org/package/show/home:pgeorgiadis:branches:Virtualization:containers/minikube
```

### Get notified via mail

Now what would be cool is to get a notification when a new version is available:

```bash
cat /root/minikube_version.sh

#!/bin/bash

OLD="v0.29.0"
curl --silent https://github.com/kubernetes/minikube/releases/latest | grep "$OLD"
RC="$?"
if [ $RC -ne 0 ]; then
    NEW=$(curl --silent https://github.com/kubernetes/minikube/releases/latest | awk -F "tag/" '{print $2}' | awk -F '"' '{ print $1 }')
    CHANGELOG="https://github.com/kubernetes/minikube/blob/master/CHANGELOG.md"
    echo "New Version $NEW"
    echo "Read the changelog at $CHANGELOG" |  mail -s "Minikube $NEW version released" pgeorgiadis@suse.de
fi
```

Run it every day at 14:00:

```bash
crontab -e

# add this:
0 14 * * * /root/minikube_version.sh
```


Have fun, Panos
