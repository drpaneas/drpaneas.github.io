Let's talk with a bit of theory
###############################

Deep (down) inside the Linux Kernel, there's a framework called **netfilter**.
Every IP packet that flows through the machine is subjected to critical
examination by Netfiler. It basically observes:

- Source IP Address of the packet
- Destination IP Address of the packet
- The overlying protocol (UDP or TCP)
- Source Port
- Destination Port
- From which Network Interface the packet came in
- To which Network Interface the packet is going out
- Other stuff (e.g. TCP flags, TCP Headers)

Based on the examination, there's a set of rules we define, so *Netfilter*
decides either to accept a packet, meaning to allow it to pass or to drop it.
This filtering occurs as the number of places the packet flows inside the
machine. For example:

Let's say we have a packet coming in. The first that happens is a routing
decision: Is the packet destined for the local machine, or not? If it does, then
it passes through the **INPUT** chain, where we keep a list of filtering rules.
Assuming that the package complies with the list of rules, it survives our
filtering and passes onto a **local process**, presumably listening on a TCP/UDP
port.

If the packet is destined for another machine, it will pass through the
**FORWARD chain**, and then into another list of filtering rules and last gets
transmitted back to the network. If the packet originates on the local machine,
it will pass through the **OUTPUT chain**, before being send out to the network.

A chain, is basically a list of rules. Each rule is consisted of a pattern and
an associated action. This looks like a stack of rules, that order matters. So,
the first rule that gets matched, determines the fate of the packet, meaning
that an associated action will be applied on it. An associated action normaly is
either accept or drop the packet. However, if the packet doesn't match any rule
and makes its way down to the end of the chain, then there's a policy that it's
also applied on that chain, so a default action will be taken. All of these
rules are down inside the kernel, but in **userspace** there's a command-line
tool, called **iptables** that's responsible for managing these rules in the
kernel. And essentially, what we are going to do in this tutorial is to create
a very simply shell script containing iptables' commands that will allow our
machine to operate as a simple firewall.

Setup
=====

The setup we are using for this demo, is a **Server machine** which runs SSH
Server, Web Server and a couple of other things. From the other hand, I have a
client machine that will allow me to observe the server machine from outside.
Also, just to make our life a little less confusing, we are going to use pink
color for the terminal in the server machine, and green color for the client
one.

Look at the current ruleset
---------------------------

Let's start by going to the server machine and looking and the current ruleset.

.. code:: bash

    # iptables -L

    Chain INPUT (policy ACCEPT)
    target     prot opt source               destination

    Chain FORWARD (policy ACCEPT)
    target     prot opt source               destination

    Chain OUTPUT (policy ACCEPT)
    target     prot opt source               destination

What we see here is that no matter of the chains, there are no rules at the
moment being specified. Also, in each of the chains, the default policy is to
ACCEPT the packet. So, currently everything is allowed to flow in, without any
kind of filtering taking place.

So, let's go now to our client machine and try to do an SSH login.

.. code:: bash

    ssh root@server

As you can see, we were able to connect via SSH into the machine as a proof that
nothing prevented us from doing it so. Apart from SSH, there's also another tool
we case use, called nmap. Nmap is a port-scanner and can tell us which port is
open and which port is closed on the server. So, let's do a port scann of the
server:

.. code:: bash

    nmap -PN server

    Starting Nmap 6.47 ( http://nmap.org ) at 2016-11-28 23:40 CET
    Nmap scan report for localhost (127.0.0.1)
    Host is up (0.000017s latency).
    Not shown: 996 closed ports
    PORT    STATE SERVICE
    22/tcp  open  ssh
    25/tcp  open  smtp
    80/tcp  open  http
    111/tcp open  rpcbind
    631/tcp open  ipp

