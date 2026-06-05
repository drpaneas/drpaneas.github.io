+++
categories = ["kubernetes"]
date = "2026-06-05T12:19:00+02:00"
tags = ["kubernetes", "openshift", "security", "proxy", "operators", "ai"]
title = "How We Put OpenClaw on Developer Sandbox"

+++

OpenClaw is now on [Developer Sandbox](https://sandbox.redhat.com/).

You click a card, provide an API key, and get a personal AI assistant running on OpenShift.

Under the hood, that assistant runs on [OpenClaw](https://github.com/openclaw/openclaw), and the core building blocks come from [claw-operator](https://github.com/codeready-toolchain/claw-operator).

That part is the boring story.

The harder story is the one I actually care about.

The first question I asked was not "does the demo work?" It was this:

> if I compromise the agent, can I steal the credential?

If the answer is yes, I do not particularly care how clean the architecture looks. The system is already in trouble. And given the fact this is Open-freakin-Claw, if it escapes the "control" boundaries, the cluster would look the same way "fatality" looks like in Mortal Kombat.

That is the question that shaped the rest of the design.

Getting a Node.js app to run in a cluster is not the interesting part. The interesting part is deciding what happens after the assistant gets compromised, or simply behaves in ways I do not like.

Put differently:

> how do you run an AI assistant on a shared cluster without letting it read secrets or send data to arbitrary places?

Let's put the security glasses to look into this.

## The Problem

For the assistant to be useful, it needs Kubernetes access. Obviously. It has to inspect resources, work against a developer workspace, and call model providers on the way out.

That immediately creates three uncomfortable problems, and none of them are theoretical.

First, if the assistant can read secrets in the same place where it runs, it can grab:

- LLM API keys
- gateway credentials
- proxy trust material
- other infrastructure secrets

Second, if it has open outbound internet access, prompt injection becomes an exfiltration path. At that point the problem is no longer "can the model be tricked?" because of course it can. The real question is whether the surrounding platform gives that failure anywhere useful to go.

Third, users bring their own credentials. Those credentials need to reach providers like OpenAI, Anthropic, Google, xAI, or OpenRouter, but the gateway process itself should not store them in plaintext.

So the challenge in a sentence was:

> keep the assistant useful, but keep its trust boundary narrow.

## What `claw-operator` Already Gets Right

The operator already had the most important pattern I wanted.

It does not put the real provider secret into the OpenClaw gateway process. Instead, it puts a proxy in front of the gateway:

- the gateway sends outbound requests through the proxy
- the proxy looks at the destination
- the proxy injects the real credential on the way out

The mental model is simple:

- the gateway knows what it wants to call
- the proxy knows how to authenticate

That matters because it keeps the main app from holding the real secret. I cared about that more than almost anything else in the design.

The operator also gives us strong default networking:

- the gateway talks to the proxy and DNS
- the proxy is the thing that can go outward
- the proxy acts as a layer-7 allowlist, so traffic only goes to configured domains

That is already a strong foundation, and honestly it is the main reason I was willing to build on this instead of starting from scratch.

## The Developer Sandbox Part: Two Namespaces

For Developer Sandbox, I wanted a harder boundary than "the gateway should behave."

So we split the world into two namespaces:

```text
alice-dev   -> your apps, services, and workspace
alice-claw  -> OpenClaw gateway, proxy, assistant infrastructure, secrets
```

That separation is not something the operator enforces by itself. It is part of the Sandbox deployment model built around the operator.

That distinction matters.

`claw-operator` gives us the mechanisms. The Sandbox deployment model decides how aggressively to use them.

Once we split the deployment this way, the security story gets much cleaner:

- OpenClaw can work against the developer workspace
- OpenClaw does not get access to the namespace that holds its own infrastructure secrets

That is a much more defensible posture than letting the assistant live next to all of its own secrets and pretending that good intentions count as a security boundary.

OpenShift is already good at enforcing namespace boundaries, so I wanted to use that directly instead of rebuilding a worse version of the same idea inside the application layer.

## Why This Works

When I think about an assistant like this, I keep coming back to two questions:

1. Can it read the secrets that power itself?
2. Can it send data wherever it wants?

The two-namespace deployment helps with the first question.

The proxy and network model help with the second.

That is the whole shape of the design.

## The Proxy Is the Only Way Out

The gateway does not get the real API key. It gets a placeholder.

Then, when the gateway makes an outbound call, the proxy strips the placeholder and injects the real key.

That means the real provider credential stays on the proxy side, not in the gateway process.

This is the part I cared about most. I did not want a clever gateway with perfect behavior. I wanted a gateway that simply never possessed the thing I was worried about losing.

The proxy is also the outbound control point.

The gateway is not supposed to talk directly to the internet. It is supposed to talk to the proxy.

So even if the assistant tries to make arbitrary outbound requests, it still goes through the proxy, and the proxy only forwards traffic to destinations that have been explicitly configured.

## How I Would Try To Break It

Once you move the trust boundary into the proxy, the next question is obvious: fine, what do I attack now?

This is where I would start, and I would be perfectly happy if it made the design uncomfortable.

* Policy matching: Can I trick the proxy into injecting credentials for a destination I control?
* Host validation: Can I abuse suffix matching, redirects, or weird host parsing rules to make the proxy do the wrong thing?
* SSRF and internal reachability: Can I push the agent into talking to internal services or metadata endpoints that were never meant to be in scope?
* Multi-tenant isolation: If there are multiple instances, can one tenant trigger credential use for another tenant's resources?
* Logging and auditability: If something goes wrong, do the logs help the operator understand it, or did we just build a very elegant blind spot?

Those are not abstract questions. They are the reason the OpenClaw proxy ended up with an explicit route model, credential injection on the proxy side, and additional network controls around it. If I cannot answer those questions cleanly, I do not trust the setup.

## What The Network Policies Do

There are really two layers here:

1. `NetworkPolicy` constrains which peers and ports are reachable.
2. The proxy route table constrains which hostnames and paths are actually allowed.

The Kubernetes layer gives us the network shape.

The proxy gives us the application-level egress policy.

Together, those two layers mean the assistant does not get direct internet access just because it is running code.

That does not make the system magically safe. What it does do is move enforcement into places that are easier to reason about than "please trust the agent to behave," which is not a serious security plan.

## Why I Think This Is Safer

I want to be careful here and not oversell it.

I do think this is a safer design by default, because we chose a coarser and more defensible boundary.

Instead of trying to solve every security problem inside one shared gateway, we pushed the trust boundary outward:

- separate assistant infrastructure from the developer workspace
- keep real provider secrets off the gateway
- force outbound traffic through a single control point

That is a practical security posture for a shared platform.

It is not perfect. It is just much easier to defend than a design that depends on every handler, every object lookup, and every authorization check being correct forever.

## A Useful Contrast

I previously reported a cross-sandbox authorization bypass in NVIDIA's OpenShell.

The public write-up is here: [report](https://pastebin.com/raw/83V4HT53), and the reproducer is here: [reproducer](https://pastebin.com/raw/F8tVWy4v).

The short version was that sandbox-scoped RPCs trusted a caller-supplied `sandbox_id` too much while the transport identity was shared more broadly than it should have been.

NVIDIA's response was that the behavior was technically real, but not a vulnerability under their then-current single-tenant threat model.

I think that contrast is useful because it shows the difference between two architectural instincts.

One instinct says:

> build a rich shared gateway, then make sure every operation checks ownership correctly

The other says:

> make the tenant boundary bigger and easier to enforce

For Developer Sandbox, I strongly prefer the second one.

That does not make authorization bugs impossible. It does mean the default posture relies more on platform boundaries and less on getting every object-level check right inside a shared control surface. I trust that trade far more than I trust a large shared gateway with a long list of subtle ownership checks.

## What This Does Not Mean

This does not mean the operator by itself gives you the exact Developer Sandbox security model.

It does not.

The operator gives you the core mechanisms:

- proxy-based secret isolation
- strong per-instance networking
- route generation
- credential handling
- per-instance auth

But it does not give you the two-namespace pattern we use in Sandbox.

That part is a deployment choice built around those mechanisms.

So there are really two layers here:

- the operator
- the secure Sandbox deployment model around it

And both matter.

## The Caveats

There are at least two important caveats.

First, the operator itself is still a privileged control-plane component. That is normal for operators, but it matters. If the operator controller is compromised, the blast radius is larger than if one assistant instance is compromised.

Second, the auth model inside one Claw instance is still instance-level. So this is not a fine-grained multi-user authorization system inside one shared assistant. We mostly avoid that problem by isolating instances and namespaces more aggressively.

Those caveats do not invalidate the design. They just define the edges of it, and I would rather say that plainly than pretend the system is cleaner than it is.

## TL;DR

We put a personal AI assistant on Developer Sandbox.

We made it useful by giving it access to the developer workspace.

We made it safer by:

- keeping its infrastructure in a separate namespace
- keeping real provider secrets on the proxy side
- forcing outbound traffic through that proxy
- using Kubernetes and OpenShift boundaries as part of the design, not as an afterthought

And we did that by combining:

- the operator's proxy and routing model
- the operator's secret-isolation model
- a Sandbox-specific dual-namespace deployment pattern

That combination is what gives us the security story.

If I had to reduce the whole thing to one sentence, it would be this:

> we treated OpenClaw as useful but not fully trusted, and then we designed the platform around that assumption.

And if you ask why not OpenShell, my take is simple: `claw-operator` is more secure by default for multi-tenant isolation because it relies on stronger architectural boundaries. One instance per namespace, hardened pods, strict `NetworkPolicy`, and secrets kept out of the main app process via a separate proxy is just a cleaner starting point. OpenShell is more flexible, but currently riskier, because it centralizes many sandbox-scoped operations behind a shared gateway, so its security depends on every handler consistently enforcing ownership. That is exactly where bugs have already appeared, and it is exactly the kind of design I do not want to bet a shared platform on.

The main caveat is still the same one: `claw-operator`'s controller itself has broad cluster privileges, so while tenant workloads are better isolated, compromise of the operator would have a larger cluster-wide blast radius.

Time will tell.
