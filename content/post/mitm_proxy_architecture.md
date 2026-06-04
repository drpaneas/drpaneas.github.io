+++
categories = ["kubernetes"]
date = "2026-06-04T12:18:00+02:00"
tags = ["kubernetes", "golang", "proxy", "security", "operators"]
title = "The First Thing I Did Was Try to Steal the Secret"

+++

*Or: Why I did not want OpenClaw agents to ever see provider credentials*

---

The first thing I did was try to steal the secret.

That sounds more dramatic than it was. I was not trying to be clever—I was trying to answer one question before wiring anything else.

When I say *agent* in this post, I mean the gateway runtime: the Node.js process that runs plugins, tools, and the LLM session. Same blast radius whether you call it the agent or the gateway.

I was building the credential story for [codeready-toolchain/claw-operator](https://github.com/codeready-toolchain/claw-operator), which deploys OpenClaw—an AI gateway that talks to LLM providers, messaging channels, Kubernetes clusters, MCP servers, and whatever else you bolt on. Each path wants its own credential shape: API keys, bearer tokens, GCP service account JSON, OAuth2 client secrets, kubeconfig tokens. Before I cared about injectors or CONNECT handling, the question was: **if I compromise that runtime, can I steal the credential?**

I did not treat that as a compliance checkbox. I assumed that process was hostile-ish—plugins, user-editable config, web UI, untrusted tool output, retrieved context, prompt injection. If an attacker gets code execution or memory read there, I wanted the answer to be *no*, not "well, we tried."

## AI agents are not normal applications

The obvious pattern for a service that calls external APIs is to mount secrets into the process and let the application manage them. That is fine for a small, boring microservice with a fixed call graph and no user-supplied logic running inside the binary.

An AI gateway is not that. OpenClaw is closer to a programmable egress hub: plugins, channels, MCP tools, config you did not write yourself. Credentials in process memory are not "configuration." They are loot. They show up in debug logs, crash dumps, and heap dumps. One bad plugin or one successful prompt injection away from exfiltration. The gateway also has no business knowing *how* each provider wants to be authenticated—it needs to send HTTP and get responses, not hold the crown jewels.

So I refused the default: hand every provider secret to the gateway and hope nothing interesting ever runs there.

## The rule I wanted to enforce

**The agent should be able to use credentials without ever seeing them.**

That is the trust boundary I cared about. Not "encrypt secrets at rest" theater. Not "we'll rotate keys eventually." The runtime that faces untrusted input must not possess the real provider material. Something else—something smaller, something I can reason about as egress policy—should hold secrets and inject them only on the way out.

What I landed on is a credential-injecting MITM proxy between the gateway and the internet. The gateway talks to the proxy with placeholder auth. The proxy matches the destination, injects the real credential for that route, and forwards over TLS upstream. The gateway never receives the actual secrets; it only ever sees stand-ins good enough to route traffic.

```
+---------------------+          +-------------------+         +------------------+
|                     |  HTTP    |                   |  HTTPS  |                  |
|   OpenClaw Gateway  | -------> |   MITM Proxy      | ------> |  api.openai.com  |
|                     |          |                   |         |                  |
| (placeholder creds) |          |  (injects Bearer) |         |  (sees real key) |
+---------------------+          +-------------------+         +------------------+
```

Once that boundary was set, the rest of the work was making the proxy trustworthy enough to sit in the middle—starting with what MITM actually means in this setup.

## What MITM means here (and what it does not)

MITM has a bad reputation for good reason. Here it is deliberate: a separate in-cluster workload the gateway reaches only through `HTTP_PROXY` / `HTTPS_PROXY`, trusting the proxy's CA for intercepted TLS. I am not hiding that interception from the gateway—I am using it so something *other than* the agent can see plaintext long enough to inject credentials and enforce policy.

[goproxy](https://github.com/elazarl/goproxy) handles the mechanics. On HTTPS the gateway sends `CONNECT`; the proxy picks one of two behaviors:

```
CONNECT api.anthropic.com:443

  Decision A: MITM
  +--------------------------------------------------+
  |  Proxy terminates TLS with its own CA cert,       |
  |  reads the HTTP request, injects credentials,     |
  |  re-encrypts and forwards to the real upstream.   |
  +--------------------------------------------------+

  Decision B: Direct tunnel
  +--------------------------------------------------+
  |  Proxy opens a raw TCP tunnel to the upstream.    |
  |  No TLS termination, no inspection, no injection. |
  |  A dumb pipe.                                     |
  +--------------------------------------------------+
```

Most routes need MITM—that is the point: read the HTTP request, inject `Authorization` or rewrite a path. WhatsApp-style Noise breaks under interception, so those domains get a direct CONNECT tunnel instead.

Per route, `NeedsMITM()` is false only when the injector is `none` and there are no path restrictions or default headers. At CONNECT time I decide per host: if *any* matching route for that host needs MITM, the connection is intercepted—even before a path exists.

```go
func (r *Route) NeedsMITM() bool {
    if r.Injector != "none" {
        return true
    }
    return len(r.AllowedPaths) > 0 || len(r.DefaultHeaders) > 0
}
```

That split matters for attacks too: anything that needs injection must land on a MITM-capable route; anything that breaks under interception gets a dumb tunnel—but then I cannot inject or path-filter inside the tunnel. I treat "direct CONNECT allowed" as a conscious loss of visibility, not a free pass.

There is also a path-prefixed mode (`/anthropic`, `/openai`, …): plain HTTP to the proxy, strip placeholder auth, inject, rewrite to upstream. Same trust boundary, different surface—policy has to match on host *and* path in both modes.

## How I would try to break it

Before I trusted this layout, I wrote down how I would attack it if I already had gateway-level code execution—the same assumption that drove "never give the agent real secrets." This is the checklist I actually used; not a generic STRIDE slide.

**Policy matching.** Can I reach an upstream the operator did not intend by winning the wrong route? CONNECT is decided on host before the HTTP path exists, so I look for hosts where one route needs MITM and another does not, or where path-restricted and catch-all routes disagree. I try `host:port` vs bare host, suffix vs exact, and whether sorted route precedence lets a broader rule shadow a narrower one on reconcile. I send the same hostname with different paths on the gateway-prefixed path and on CONNECT MITM and check both code paths.

**Host validation.** The allowlist keys off what the proxy believes the destination is—CONNECT authority, rewritten upstream host, `Host` on plain HTTP. I try mismatches: wrong port on a kube API route, IPv6 literals, trailing dots, userinfo in URLs, and anything that makes `MatchRoute` see a different string than the TCP peer. If host parsing is loose, I get a route I should not, or I miss injection and ship placeholder creds to a real API (loud failure, but still a bug).

**Redirects and wildcard abuse.** If the proxy follows redirects without re-checking policy, I chain out of an allowed domain. I abuse suffix routes (`.googleapis.com`, `.githubusercontent.com`) with subdomains or paths the operator did not picture. On path-restricted routes I try `..`, `//`, and encoded segments to slip past canonicalization—exactly the class of bug that turns "Slack app token only on this path" into "any Slack API." Redirects are still an open audit point for me: I keep testing them aggressively, because allowlists get weird once clients start walking you to a different host.

**SSRF and internal destinations.** The gateway is untrusted egress. I point it at metadata endpoints, loopback names, cluster DNS, or MCP URLs that resolve inside the mesh. I watch `inClusterBypass` and per-route upstream overrides: anything that lets the gateway skip the proxy or talk to a Service on port 80 is a second egress path I have to kill in NetworkPolicy, not just in JSON routes. Kubernetes injector routes are especially sensitive: a kubeconfig entry is a map from host:port to bearer token, so confusing internal API servers with external ones is credential cross-wiring.

**Multi-tenant isolation.** One compromised gateway must not become lateral movement. I ask whether two `Claw` instances can share Secrets, proxy configs, or operator RBAC mistakes; whether instance-level gateway tokens mean every human on that instance shares one blast radius; and whether the operator's broad RBAC is a bigger prize than any single pod. I do not pretend per-path Slack restrictions solve tenant boundaries—they solve *credential shape* inside one instance.

**Logging and auditability.** I want blocked CONNECTs and rejected paths to show up in logs I would actually read during an incident. I want config and secret changes to force a rollout I can correlate (stale proxy with old routes is a silent policy regression). If exfiltration only needs allowed domains, logs are the detective control; if exfiltration needs a policy bug, logs are how I prove which route fired.

That list is the bar. What follows maps it to five controls: a domain allowlist, path restrictions, credential stripping on egress, explicit CONNECT-mode decisions per host, and NetworkPolicy around the proxy.

## The CA certificate: trust by design

MITM only works if the gateway trusts the proxy's leaf certs. The operator generates a P-256 ECDSA CA once, stores it in a Secret, and the gateway mounts it—so `api.openai.com` looks legitimate while the proxy terminates TLS. That is intentional mis-trust: the agent process must not be able to pin the *real* provider cert and bypass injection.

Upstream is the opposite story. The proxy verifies real server certificates (system roots plus kubeconfig CAs). No `InsecureSkipVerify`. If I could MITM the proxy's outbound leg, I would harvest everything the injectors just added—so this is the other half of host validation, not gateway theater.

```
Gateway  <--[proxy CA]--> Proxy <--[real CA]--> Upstream
  trusts proxy CA           verifies real certs
```

## Seven injectors, one job

The proxy core does not know Anthropic from Slack. It matches a route, strips whatever auth the gateway tried to send, and calls an injector. That isolation is the point: credential mechanics live in small types that only mutate the outbound request, not in CONNECT handling or allowlist logic.

First step is always deletion—`Authorization`, `X-Api-Key`, `X-Goog-Api-Key`, `Proxy-Authorization`, every `Impersonate-*` header. If the compromised runtime still had a real key in memory and tried to exfiltrate through the proxy, that attempt dies before injection. Placeholders in generated gateway config are routing hints, not trust.

After the strip, the shape of the secret decides behavior: static keys and bearer tokens from env into named headers; path-embedded tokens (Telegram-style) with the same canonicalization paranoia as path-restricted routes; GCP and OAuth2 as short-lived tokens minted and cached on the proxy; kubeconfig parsed into a host:port→token map (the checklist's cross-wiring case—wrong server URL means the wrong bearer on the wrong API); `none` for allowlist-only egress, usually on direct CONNECT tunnels where MITM would break the wire protocol. New provider shape? New injector type, same strip-then-inject path—the server code stays boring on purpose.

## The domain allowlist: no route, no egress

The first gate is hostname. Unknown `CONNECT` targets get rejected and logged before TLS or injection—positive security against SSRF and "just curl this internal URL" fantasies. The gateway only reaches domains the operator put in the route table: LLM providers, channels, declared MCP peers, and a small builtin set (ClawHub, npm, GitHub, OpenRouter pricing, a *path-restricted* slice of `raw.githubusercontent.com`). No matching route means no socket, regardless of what the agent was told to fetch.

Suffix routes (`.googleapis.com`, `.githubusercontent.com`) buy convenience; path restrictions buy precision. Slack is the case I keep in mind: one route for the app-token path, others for the rest of the API, with canonicalized paths so `..` and `//` cannot smuggle a broader credential shape. CONNECT still picks MITM vs tunnel per host via `NeedsMITM()`; path checks bite on HTTP inside intercepted flows and on gateway-prefixed plain HTTP—two surfaces, same rules.

Precedence is part of the control, not an implementation detail: `host:port` exact, then bare host, then suffix. The reconciler emits the same sort order the proxy uses, so a rollout cannot silently reshuffle which rule wins—a direct answer to the "policy matching" line on the attack checklist.

## What the operator actually ships

The proxy stays deliberately dumb—sorted JSON routes, env and volume mounts—so when policy is wrong I have one artifact to diff, not seven credential code paths scattered through the gateway. The reconciler turns `Claw` `spec.credentials` into that table: domain, injector, path prefix, upstream override, allowed paths, CONNECT-mode implications via `NeedsMITM()`. Kubeconfigs get validated before they become routes (token auth only, parseable server URLs, no conflicting host:port tokens). Real Secrets land on the proxy Deployment only.

Rollout is where operator discipline meets runtime discipline. The controller hashes the route JSON into a pod annotation (`claw.sandbox.redhat.com/proxy-config-hash`) and stamps each referenced Secret's `ResourceVersion`. Change policy or rotate a Secret without a restart, and you are still running yesterday's allowlist—that is the silent regression from the attack checklist. Forcing a rolling restart on drift is blunt; I will take blunt over wrong.

The gateway manifest comes last, and it is still the untrusted side: after OpenShift (or plain Kubernetes) exposes a public hostname, the reconciler applies config with proxy URLs, placeholder auth, provider metadata, and the proxy CA—never the real provider material. NetworkPolicy port lists are derived from the same route table (non-443 kube APIs, in-cluster MCP peers), so L3 and L7 policy stay aligned without the gateway learning how to mint tokens.

## The GCP receipt that proved the boundary

Vertex paths mount a stub ADC file on the gateway so Google's SDK can boot. The SDK then does what SDKs do: `POST` to `oauth2.googleapis.com/token` with that stub. The proxy already mints real tokens from the service-account JSON on its side. Let that token request hit Google and it fails—the stub is a placeholder by design.

So the proxy lies politely on the vending path and returns:

```json
{"access_token": "claw-proxy-vended-token", "token_type": "Bearer", "expires_in": 3600}
```

The SDK accepts it, sets `Authorization: Bearer claw-proxy-vended-token` on the next call, and the proxy strips that dummy bearer and injects a real one. The gateway never held the JSON; it never got a usable OAuth response—only a token-shaped string it was trained to forward. Same trick on CONNECT MITM and on gateway-prefixed HTTP, because the SDK does not care which path you chose when you set `baseUrl`.

That was the moment I trusted the split: the interesting credential work happened on infrastructure I could patch without redeploying the Node runtime.

## NetworkPolicy: the backstop, not the story

The allowlist is the primary control: names and paths the agent may request. NetworkPolicy answers what a compromised process can do when policy JSON is wrong or incomplete—peers and ports, not hostnames. Per `Claw` instance: gateway egress to proxy and DNS only; proxy egress to 443 and DNS unless a route documents an exception (non-443 kube APIs, in-cluster MCP). A route to an internal Service is useless if the proxy policy never allows that peer; `inClusterBypass` is a deliberate second egress path I treat as skipping injection, not as a feature.

```
Gateway  --[proxy + DNS only]-->  Proxy  --[443 + DNS, exceptions explicit]-->  Internet / declared peers
```

I would not ship this without L7 rules—but I would not pretend L7 rules replace mesh fencing. The checklist's SSRF line needs both.

## What I did not build

This does not make OpenClaw "secure." It removes one especially stupid failure mode: handing raw provider credentials to a process that eats untrusted input all day and hoping plugins, prompts, and heap dumps stay boring. The win is narrower—move the trust boundary to infrastructure that can strip, inject, allowlist, and fence egress better than a Node gateway ever will.

Mapped back to the checklist, that is five receipts, not a product pitch: hostname allowlist at CONNECT; path restrictions inside MITM; strip-then-inject on every forwarded request; explicit MITM vs dumb tunnel per host; NetworkPolicy as backstop when JSON policy lies. More moving parts—CA, proxy Deployment, hashed rollouts—but I would rather operate that pile than teach the gateway seven credential types where user code runs.

The claim stays narrow. A compromised gateway should not read provider secrets and should not get arbitrary egress. It is not fine-grained authorization inside one shared instance, and it is not safety against a compromised operator.

NVIDIA OpenShell's reported cross-sandbox bypass is a useful contrast: sandbox-scoped RPCs trusted a caller-supplied `sandbox_id` while pods shared one mTLS identity, so one sandbox could read another's provider environment. [Report](https://pastebin.com/raw/83V4HT53), [reproducer](https://pastebin.com/raw/F8tVWy4v). NVIDIA treated it as expected in single-tenant deployment; hardening followed in [issue #40](https://github.com/NVIDIA/OpenShell/issues/40) and [issue #451](https://github.com/NVIDIA/OpenShell/issues/451). I am not solving that class of bug inside one shared runtime. Isolation unit is the `Claw` instance—typically a namespace—with secrets on the proxy and policy beside them. Strongest when one tenant maps to one instance; weakest when several humans share one gateway token and one credential context. Path-level Slack restrictions shape *which secret* fires; they do not create tenants.

Two limits I will say out loud:

The operator reconciler is a privileged control plane—Deployments, Secrets, NetworkPolicies, `pods/exec` for pairing. Compromising one gateway pod is bad; owning the controller is worse.

Gateway auth is per instance, not per human. I spin instances to isolate tenants; I do not pretend ACLs inside a single programmable gateway fix multi-user sharing.

If you steal one thing for your own operator work: decide whether the application that faces users and plugins should ever hold provider secrets. If the answer is no, something smaller needs to stand in the middle—and you will live with MITM tradeoffs, stub tokens, and hashed rollouts as the price of that "no." That was the whole point of trying to steal the secret first: make the failure mode loud early, not in production when a prompt injection already won.
