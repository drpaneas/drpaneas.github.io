+++
categories = ["tutorial"]
date = "2022-07-12T15:39:35+02:00"
tags = ["tutorial", "git"]
title = "How test a PR locally"

+++

## Well, use a script

Let's say I want to test this [PR] locally, meaning I need to fetch the code locally to my laptop.
All I need is the URL and nothing more.

Clone the repository locally (if you haven't done it already), change into this directyory and then run the script:

```bash
$ testpr https://github.com/redhat-appstudio/managed-gitops/pull/177
```

Output:

```bash
remote: Enumerating objects: 202, done.
remote: Counting objects: 100% (202/202), done.
remote: Compressing objects: 100% (129/129), done.
remote: Total 202 (delta 68), reused 187 (delta 67), pack-reused 0
Receiving objects: 100% (202/202), 443.32 KiB | 1.42 MiB/s, done.
Resolving deltas: 100% (68/68), completed with 7 local objects.
From github.com:redhat-appstudio/managed-gitops
 * [new ref]         refs/pull/177/head -> test-pr-177
Switched to branch 'test-pr-177'
```

The `testpr` script is very simple (really simple) and looks like this:

```bash
#!/bin/bash

# https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/checking-out-pull-requests-locally

URL="$1"
REMOTE="origin" # <-- change this if you use different remote target
if test -z "$URL"; then
	echo "Use: testpr <GITHUB PR URL>"
    exit 1
fi

ID=$(echo "$URL" | sed -e 's/.*\/\([0-9]*\)$/\1/')

BRANCHNAME="test-pr-$ID"

if git fetch "$REMOTE" pull/"$ID"/head:"$BRANCHNAME"; then
	git checkout "$BRANCHNAME"
else
	echo "Something is wrong"
    exit 1
fi
```

Just put it somewhere in your `$PATH` env, so you can execute it from everywhere in your shell.
Feel free to modify it, especially if you use different `REMOTE`.
In my case, I use `origin` to refer to the upstream project.
Some other folk, do it the otherway around: the use `upstream` remote to refer to `upstream`.

[PR]: https://github.com/redhat-appstudio/managed-gitops/pull/177
