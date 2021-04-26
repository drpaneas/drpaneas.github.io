+++
categories = ["tutorial"]
date = "2018-09-27T17:34:35+02:00"
tags = ["tutorial", "go", "golang", "vscode", "helloworld"]
title = "My personal Go environment setup"

+++

## How many go version do you have installed?

The default upstream location for the binary is: `/usr/local/go`.
But in SUSE it is: `/usr/bin/go`. This is a symlink created
via `update-alternatives`.

```bash
# update-alternatives --list go
/usr/lib64/go/1.10/bin/go
/usr/lib64/go/1.8/bin/go
/usr/lib64/go/1.9/bin/go
```

I want to keep only the *1.10* so I will remove the others:

```bash
# zypper rm $(rpm -qf /usr/lib64/go/1.8/bin/go) $(rpm -qf /usr/lib64/go/1.9/bin/go)
```

To verify, try `update-alternatives` once more. There should be only *one* version:

```bash
# update-alternatives --list go
/usr/lib64/go/1.10/bin/go
```

The full should look like this:

```bash
# update-alternatives --display go
go - auto mode
  link best version is /usr/lib64/go/1.10/bin/go
  link currently points to /usr/lib64/go/1.10/bin/go
  link go is /usr/bin/go
  slave go.gdb is /etc/gdbinit.d/go.gdb
  slave go.sh is /etc/profile.d/go.sh
  slave gofmt is /usr/bin/gofmt
/usr/lib64/go/1.10/bin/go - priority 30
  slave go.gdb: /usr/lib64/go/1.10/bin/gdbinit.d/go.gdb
  slave go.sh: /usr/lib64/go/1.10/bin/profile.d/go.sh
  slave gofmt: /usr/lib64/go/1.10/bin/gofmt
```

This automatically created the following env vars:

```bash
# env | grep GO
GOPATH=/usr/share/go/1.10/contrib
GOROOT=/usr/lib64/go/1.10
GOBIN=/usr/bin
GOOS=linux
GOARCH=amd6
```

## Setup the Go variables

Change *.bashrc* to know what is going on:

```bash
# Go stuff
# Where is the go binary
export GOROOT=/usr/lib64/go/1.10
export PATH=$PATH:$GOROOT/bin

# Libraries with executables
export GOPATH=/home/tux/golib
export PATH=$PATH:$GOPATH/bin
```

Now `source` the *.bashrc* to take changes into effect.

```bash
source .bashrc
```

This might create a problem if you update to a new-er version of go.
As a result you better lock that package.

So next time you update your system, *go* will not be updated.

```bash
# zypper addlock go
Specified lock has been successfully added.
```

To verify this, try to *dup* and see that *go* pkg stays locked:

```bash
# zypper dup
Warning: You are about to do a distribution upgrade with all enabled repositories. Make sure these repositories are compatible before you continue. See 'man zypper' for more information about this command.
Loading repository data...
Reading installed packages...
Computing distribution upgrade...

The following item is locked and will not be changed by any action:
 Installed:
  go

Nothing to do.
```


## Set a compound GOPATH for 3rd party libs and personal ones

Let us add a library for auto-completion:

```go
$ go get github.com/nsf/gocode
```

Now check at the *GOPATH* folder:

```bash
$ ls -l ~/golib/
total 0
drwxr-xr-x 1 tux users 12 Sep 11 16:23 bin
drwxr-xr-x 1 tux users 20 Sep 11 16:16 src

$ ls -l golib/bin/
total 11044
-rwxr-xr-x 1 tux users 11305958 Sep 11 16:23 gocode

$ ls -l golib/src/github.com/nsf/
total 0
drwxr-xr-x 1 tux users 798 Sep 11 16:23 gocode
```

Apart from the 3rd party libraries, you might want
to create your own when you are developing an app.
For this, you can create a second place that
points to GOPATH. Open your *.bashrc* and add:

```bash
export GOPATH=$GOPATH:/home/tux/code
```

Then source it and check again:

```bash
$ source .bashrc 
$ env | grep GOPATH
GOPATH=/home/tux/golib:/home/tux/code
```

So if I remove now the *gocode* binary...

```bash
$ cd golib; rm -rf *
$ ls -lah
total 0
drwxr-xr-x 1 tux users    0 Sep 11 16:35 ./
drwxr-xr-x 1 tux users 2418 Sep 11 16:32 ../
```

Now download it again:

```go
$ go get github.com/nsf/gocode
```

Now, let's see the two locations of *GOPATH*:

```bash
# First
$ ls -l golib/
total 0
drwxr-xr-x 1 tux users 12 Sep 11 16:36 bin
drwxr-xr-x 1 tux users 20 Sep 11 16:36 src

# Second
$ ls -l code/
total 
```

So the 3rd party lib, stored only at the *golib*
folder. The second one, does not have it. This is
fine, because the second one will be used
only by our own libs -- not 3rd party ones.


## Setup your Workspace

To have a workspace for Go, you need to have an expected
structure. This workspace is the location where *GOPATH*
is going to look for this specific tree structure.

```bash
$ cd code; ls
```

We have nothing so far. Let's create the necessarry folders:

* **src**: where you keep your source-code
* **bin**: where you build your binaries (`/home/tux/golib/bin`)
* **pkg**: where you keep your packages

So, let's create those:

```bash
$ mkdir -p code/{bin,pkg,src}

$ ls -l code/
total 0
drwxr-xr-x 1 tux users 0 Sep 11 16:53 bin
drwxr-xr-x 1 tux users 0 Sep 11 16:53 pkg
drwxr-xr-x 1 tux users 0 Sep 11 16:53 src
```

## Setup Microsoft VS

To setup:

```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/zypp/repos.d/vscode.repo'
sudo zypper ref
sudo zypper install code
```

Learn more about it: `https://code.visualstudio.com/docs/getstarted/introvideos`

More information related to setup: `https://code.visualstudio.com/docs/setup/linux`

At first I've got the following error:

```
The "go-outline" command is not available. Use "go get-v github.com/ramya-rao-a/go-outoline" to install
Click "install all".
```

What VS code did, was to install **10 tools** at */home/tux/golib:/home/tux/code/bin*. This
is what whappens behind the scenes:

```go
$ go get -u -v github.com/nsf/gocode
$ go get -u -v golang.org/x/tools/cmd/godoc
$ go get -u -v github.com/ramya-rao-a/go-outline
$ go get -u -v github.com/acroca/go-symbols
$ go get -u -v golang.org/x/tools/cmd/guru
$ go get -u -v golang.org/x/tools/cmd/gorename
$ go get -u -v github.com/rogpeppe/godef
$ go get -u -v github.com/uudashr/gopkgs/cmd/gopkgs
$ go get -u -v github.com/derekparker/delve/cmd/dlv
$ go get -u -v github.com/sqs/goreturns
$ go get -u -v github.com/golang/lint/golint
```

## What can I import?

The **official** go packages (*e.g. fmt*) are located under *src* folder
of your *GOROOT*:

```
$ cd $GOROOT/src; ls
archive  bytes     container  database  errors  fmt   html   internal  math  os      reflect  sort     sync     text     unsafe
bufio    cmd       context    debug     expvar  go    image  io        mime  path    regexp   strconv  syscall  time     vendor
builtin  compress  crypto     encoding  flag    hash  index  log       net   plugin  runtime  strings  testing  unicode
```

The **3rd party ones** are located at:

```
$ ls -l ~/golib/src/
total 0
drwxr-xr-x 1 tux users 130 Sep 11 17:32 github.com
drwxr-xr-x 1 tux users   2 Sep 11 17:27 golang.org
```

My **personal** packages under development can be found at:

```
$ ls -l ~/code/src/
total 0
drwxr-xr-x 1 tux users 16 Sep 11 17:18 github.com
```

## Hello world in Go and VS

Go to the workspace and create the following folder structure:

```bash
$ cd ~/code
$ mkdir -p github.com/drpaneas/firstapp
```

At the VS code, create the following **Main.go**:

```go
package main

import "fmt"

func main() {
	fmt.Println("Hello Go!")
}
```

### Go run (compile) in VS Code

Open terminal inside VSCode type: `ctrl+backtick` and compile
it: `go run src/github.com/drpaneas/firstapp/Main.go`

### Go build in VS Code

Go build is different from compilation. It expects to find specific stuff
at specific directories. It takes takes the **actual package path**. It tries to find
the package into the following:

```
        /usr/lib64/go/1.10/src/whater_you_put (from $GOROOT)
        /home/tux/golib/src/whatever_you_put (from $GOPATH)
        /home/tux/code/src/whatever_you_put
```

That means, the correct build command would be:


```go
$ go build github.com/drpaneas/firstapp/
```

Notice that while building I am **not using** `src` in the path
and I also don't put `Main.go` at the end. You can run this
command not matter in whatever directory you are into.
This compiles a package into an executable, so you can pass it
to others and run it like `./firstapp`.

### Go install in VS Code

The other tools, is `go install`. This is expected to be pointing
to a package that has an entry point and it's going to install
that into your *bin* folder. So, once again you have to use
the package address and not the folder path.

```go
$ go install github.com/drpaneas/firstapp
```

This creates a binary into my *bin* folder:

```bash
$ ls -l ~/code/bin/
total 1968
-rwxr-xr-x 1 tux users 2011612 Sep 12 11:13 firstapp
```

Happy coding :)
Panos
