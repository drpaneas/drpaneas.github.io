+++
categories = ["kubernetes"]
date = "2026-06-04T12:18:00+02:00"
tags = ["kubernetes", "golang", "proxy", "security", "operators"]
title = "How We Built a Credential-Injecting MITM Proxy for an AI Gateway Operator"

+++

*Or: How to keep provider secrets out of the gateway process*

---

This post is based on the architecture behind [codeready-toolchain/claw-operator](https://github.com/codeready-toolchain/claw-operator).

The interesting part is not just that the operator deploys an AI gateway. It is how it handles credentials. Instead of handing provider secrets directly to the gateway process, the design puts a credential-injecting MITM proxy between the gateway and the outside world. The gateway works with placeholder auth, and the proxy injects the real secrets on egress.

If you are building Kubernetes operators, internal gateways, or any service that talks to many external APIs with different authentication models, this pattern is worth understanding. It gives you credential isolation, egress control, and protocol flexibility in one place, without teaching the gateway itself how every provider authenticates.

## The problem: AI credentials scattered everywhere

The claw-operator deploys OpenClaw, an AI gateway that talks to multiple LLM providers (Google, Anthropic, OpenAI, xAI, OpenRouter), messaging channels (Telegram, Discord, Slack, WhatsApp), Kubernetes clusters, and MCP servers. Each of those needs credentials. API keys, bearer tokens, GCP service account JSON files, OAuth2 client secrets, kubeconfig tokens.

The obvious approach is to hand those credentials to the gateway application and let it manage them. That is also the wrong approach.

The gateway is a large Node.js application with plugins, user-editable config, and a web UI. Giving it raw API keys means those keys live in the application's process memory, show up in debug logs, and are one misconfigured plugin away from leaking. Worse, the gateway has no business knowing *how* to authenticate with each provider. It just needs to send HTTP requests and get responses.

The architecture we landed on puts a MITM proxy between the gateway and the internet. The gateway sees plaintext HTTP and placeholder credentials. The proxy sees the destination, injects the real credential for that route, and forwards the request over TLS to the upstream. The gateway never receives the actual provider secrets.

```
+---------------------+          +-------------------+         +------------------+
|                     |  HTTP    |                   |  HTTPS  |                  |
|   OpenClaw Gateway  | -------> |   MITM Proxy      | ------> |  api.openai.com  |
|                     |          |                   |         |                  |
| (placeholder creds) |          |  (injects Bearer) |         |  (sees real key) |
+---------------------+          +-------------------+         +------------------+
```

## What MITM means here (and what it does not)

MITM - man in the middle - has a bad reputation for good reason. In the wild, it means someone intercepting traffic they should not see. Here, the proxy is a deliberate architectural component. It runs as a separate in-cluster workload behind a Service, and the gateway is configured to send outbound traffic to it via `HTTP_PROXY` and `HTTPS_PROXY`. The gateway is also configured to trust the proxy's CA certificate for intercepted TLS traffic.

The proxy uses [goproxy](https://github.com/elazarl/goproxy), a Go library for building HTTP/HTTPS proxies. When the gateway opens an HTTPS connection, it sends a `CONNECT` request to the proxy. The proxy has two choices:

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

Most domains need MITM - that is the whole point. The proxy needs to see the HTTP request to inject an `Authorization` header or rewrite a URL path. But some protocols break under TLS interception. WhatsApp uses a custom Noise protocol handshake that fails if anything tampers with the TLS layer. For those domains, the proxy falls back to a direct CONNECT tunnel: it allows the connection but does not touch it.

Each route in the proxy config declares whether it needs MITM. If the injector is `none` and there are no path restrictions or default headers, that route can use a direct tunnel. Everything else needs interception. At CONNECT time the proxy makes the decision per host, not per final request path: if any matching route for that host needs MITM, the proxy intercepts the connection.

```go
func (r *Route) NeedsMITM() bool {
    if r.Injector != "none" {
        return true
    }
    return len(r.AllowedPaths) > 0 || len(r.DefaultHeaders) > 0
}
```

This is a meaningful distinction. It means the proxy can allowlist WhatsApp's domains for connectivity without breaking its protocol, while still doing full credential injection on every API call to Anthropic or OpenAI.

The proxy also has a second mode besides classic forward-proxy CONNECT handling. For known providers, the operator can generate path-prefixed gateway routes like `/anthropic` or `/openai`, each with an upstream target. In that mode the gateway sends plain HTTP requests directly to the proxy, the proxy strips placeholder auth, injects the real credential, rewrites the request to the configured upstream, and forwards it.

## The CA certificate: trust by design

For MITM to work, the gateway must trust the proxy's TLS certificates. The operator generates a self-signed P-256 ECDSA CA certificate on first deployment and stores it in a Kubernetes Secret. This CA is used by goproxy to sign leaf certificates on the fly for each upstream domain.

The gateway pod mounts this CA certificate and adds it to its trust store. From the gateway's perspective, `api.openai.com` presents a valid certificate signed by a trusted CA. It has no idea the proxy is in the middle.

On the upstream side, the proxy verifies the real server's TLS certificate against the system root CA pool (plus any custom CAs from kubeconfig entries). It explicitly does *not* use `InsecureSkipVerify`. This matters: if the proxy blindly trusted upstream certificates, an attacker could intercept the proxy-to-upstream connection and steal the credentials the proxy just injected.

```
Gateway  <--[proxy CA]--> Proxy <--[real CA]--> Upstream
  trusts proxy CA           verifies real certs
```

## Seven injectors, one interface

The proxy supports seven credential types, each implemented as a separate injector behind a common interface:

```go
type Injector interface {
    Inject(req *http.Request) error
}
```

Every injector does one thing: modify an `*http.Request` to add credentials. The proxy calls `StripAuthHeaders` before injection, removing `Authorization`, `X-Api-Key`, `X-Goog-Api-Key`, `Proxy-Authorization`, and all `Impersonate-*` headers, so the gateway cannot accidentally pass through credentials of its own.

Here is what each injector does:

**`api_key`** - Reads a secret from an environment variable, sets a custom header. Google uses `x-goog-api-key`, Anthropic uses `x-api-key`, Discord uses `Authorization` with a `Bot ` prefix. The header name and value prefix are configurable per route.

**`bearer`** - Reads a token from an environment variable, sets `Authorization: Bearer <token>`. Used by OpenAI, xAI, OpenRouter, and Slack.

**`gcp`** - Reads a GCP service account JSON file, obtains an OAuth2 access token using `google.CredentialsFromJSONWithType`, caches it with automatic refresh, and sets `Authorization: Bearer <token>`. Also handles token vending: when Google's SDK tries to fetch its own OAuth2 token from `oauth2.googleapis.com/token`, the proxy intercepts the request and returns a dummy token. The real token injection happens on the actual API request.

**`path_token`** - Rewrites the URL path to embed the token. Telegram's Bot API uses URLs like `/bot<token>/sendMessage`. The gateway sends requests with a placeholder token, and the injector swaps in the real one.

**`oauth2`** - Performs a `client_credentials` grant to obtain an access token, caches it via a reusable `TokenSource`, and sets `Authorization: Bearer <token>`. Used for services that require OAuth2 client credentials rather than static API keys.

**`kubernetes`** - Parses a kubeconfig file and builds a hostname:port-to-token lookup map. When a request goes to a Kubernetes API server, the injector looks up the token by the destination host and port, then sets `Authorization: Bearer <token>`. Handles both IPv4 and IPv6 addresses.

**`none`** - Does nothing (or sets default headers if configured). Used for allowlist-only domains like WhatsApp companions, npm registry, or GitHub.

The factory function is a switch statement:

```go
func NewInjector(route *Route) (Injector, error) {
    switch route.Injector {
    case "api_key":    return NewAPIKeyInjector(route)
    case "bearer":     return NewBearerInjector(route)
    case "gcp":        return NewGCPInjector(route)
    case "none":       return NewNoneInjector(route)
    case "path_token": return NewPathTokenInjector(route)
    case "oauth2":     return NewOAuth2Injector(route)
    case "kubernetes": return NewKubernetesInjector(route)
    default:           return nil, fmt.Errorf("unknown injector type: %s", route.Injector)
    }
}
```

Adding a new credential type means writing a struct with an `Inject` method and adding one case to this switch. The proxy server code does not change.

## The domain allowlist: egress firewall for free

The proxy does not just inject credentials. It also blocks everything not in its route table. If the gateway tries to reach a domain with no matching route, the proxy returns HTTP 403 with a small JSON error body.

```go
proxy.OnRequest().HandleConnectFunc(
    func(host string, ctx *goproxy.ProxyCtx) (*goproxy.ConnectAction, string) {
        route := cfg.MatchRoute(host, "")
        if route == nil {
            logger.Warn("blocked CONNECT to unknown domain", "host", host)
            return rejectConnect, host
        }
        // ...
    },
)
```

This means the proxy doubles as an application-layer egress firewall. The gateway can only reach domains that the operator has explicitly configured: provider APIs, channel domains, MCP server endpoints, and a small set of builtins such as the ClawHub plugin registry, npm, GitHub, OpenRouter's pricing endpoint, and a path-restricted slice of `raw.githubusercontent.com`.

Routes can also restrict allowed paths. For example, Slack support can use an exact allowed path for the app-token route while keeping other Slack traffic on separate routes, and path matching canonicalizes dot-segments and duplicate slashes to prevent traversal bypasses.

The route matching has three tiers of precedence: `host:port` exact match beats bare-host exact match beats suffix match (domains starting with `.`). This matters for Kubernetes credentials, where the proxy needs to match `api.cluster.local:6443` exactly, and for GCP credentials, where `.googleapis.com` can cover Google API subdomains.

## How the operator wires it all together

The proxy is intentionally dumb. It reads a JSON config file and a set of environment variables. It does not know about Kubernetes, CRDs, or the Claw spec. All the orchestration logic lives in the operator's reconciler.

The reconcile flow is three-phase because the OpenShift Route host is populated asynchronously and then has to be injected back into the gateway config:

**1. Phase 1: resolve credentials and apply proxy-managed resources.** The operator reads the `Claw` CR's `spec.credentials` list, applies provider defaults, validates referenced Secrets, and generates proxy-side resources. If the user specifies `provider: google`, the operator infers `type: apiKey`, `domain: generativelanguage.googleapis.com`, and `header: x-goog-api-key` from a centralized `knownProviders` registry. Explicit values always win. For kubernetes credentials, it parses the entire kubeconfig, validating that all users use token auth, that server URLs are parseable, that CA data is inlined, and that no server has conflicting tokens from different users.

One of the controller-managed outputs is the proxy route table:

```json
{
  "routes": [
    {
      "domain": "api.anthropic.com",
      "injector": "api_key",
      "header": "x-api-key",
      "envVar": "CRED_ANTHROPIC",
      "pathPrefix": "/anthropic",
      "upstream": "https://api.anthropic.com"
    },
    {
      "domain": "api.openai.com",
      "injector": "bearer",
      "envVar": "CRED_OPENAI",
      "pathPrefix": "/openai",
      "upstream": "https://api.openai.com/v1"
    },
    {
      "domain": "clawhub.ai",
      "injector": "none"
    }
  ]
}
```

Routes are deterministically sorted - exact domains before suffix domains, alphabetical within each group, path-restricted routes before catch-all routes. This prevents unnecessary ConfigMap churn across reconcile loops.

The reconciler also modifies the proxy Deployment's pod template to inject credentials:

- API keys, bearer tokens, path tokens, and OAuth2 secrets become environment variables sourced from Kubernetes Secrets (`valueFrom.secretKeyRef`)
- GCP service account files and kubeconfigs become volume mounts from Secrets, projected into `/etc/proxy/credentials/<name>/`

The proxy config JSON is SHA-256 hashed and stamped as a pod annotation (`claw.sandbox.redhat.com/proxy-config-hash`). Each referenced Secret's `ResourceVersion` is also stamped. When config or secrets change, the annotations change, and Kubernetes triggers a rolling update. This is the standard annotation-driven rollout pattern: the proxy gets restarted with the new config without the operator having to manage rollout logic itself.

**2. Phase 2: apply the Route and wait for the host.** The controller applies the OpenShift Route, reads back `.status.ingress[0].host`, and requeues until that host is populated. On vanilla Kubernetes, where the Route CRD is absent, it falls back to `http://localhost:18789`.

**3. Phase 3: inject the final gateway config and apply remaining resources.** Once the Route host is known, the operator injects it into the generated gateway config along with provider metadata, model catalog data, network policy ports, and config hashes, then applies the remaining manifests. That ordering is not just implementation detail - it is what lets the gateway come up with the right externally visible host and CORS configuration on first successful reconciliation.

## The GCP token vending trick

The GCP injector has an interesting wrinkle. For Vertex SDK paths, the operator mounts a stub ADC (Application Default Credentials) file into the gateway so Google's auth library can bootstrap. Google's client SDK then tries to obtain its own OAuth2 token before making API calls. It sends a `POST` to `oauth2.googleapis.com/token`. But the proxy is already handling token acquisition - the `GCPInjector` calls `google.CredentialsFromJSONWithType` and injects the token on the real API request.

If the SDK's token request reaches the real Google endpoint, it will fail because the gateway's ADC (Application Default Credentials) file contains placeholder data. So the proxy intercepts the token vending request and returns a dummy response:

```json
{"access_token": "claw-proxy-vended-token", "token_type": "Bearer", "expires_in": 3600}
```

The SDK is satisfied. It sets `Authorization: Bearer claw-proxy-vended-token` on the next request. The proxy then strips that header and replaces it with a real token. The SDK never knows the difference.

This interception happens at two levels, both in the forward proxy path (CONNECT MITM) and in the gateway path (direct HTTP), because the SDK might use either depending on how `baseUrl` is configured.

## NetworkPolicy: defense in depth

The proxy is not the only layer of enforcement. The operator creates three `NetworkPolicy` resources per instance: one ingress policy for the gateway, one gateway egress policy, and one proxy egress policy.

```
+-------------------------+     +-------------------+     +------------------+
| Gateway Pod             |     | Proxy Pod         |     | Internet         |
|                         |     |                   |     |                  |
|  Egress: proxy + DNS    |     |  Egress: 443 + DNS|     |                  |
|  (nothing else)         |     |  (nothing else)   |     |                  |
+------------+------------+     +---------+---------+     +------------------+
             |                            |
             +--- only to proxy --------->+--- only to port 443 ------------>
```

The gateway can only reach the proxy and DNS. The proxy can only reach port 443 and DNS by default. That is real defense in depth, but it is important to be precise about what each layer enforces: the NetworkPolicies constrain peers and ports, while the proxy's route table enforces the hostname and path allowlist.

When Kubernetes credentials use non-standard ports (like `6443` for the API server), the operator dynamically adds those ports to the proxy's egress NetworkPolicy. MCP server URLs that point to in-cluster services get their own egress rules, routed either through the proxy or directly from the gateway depending on the `inClusterBypass` setting.

## What this buys you

The MITM proxy pattern gives the operator four properties that would be awkward to get any other way:

**Credential isolation.** The gateway does not receive the real provider secrets. It works with placeholder values in generated config, while the real credential material is mounted into or injected into the proxy workload. On egress, the proxy strips gateway-supplied auth headers and replaces them with the real credentials for the matched route.

**Uniform credential injection.** Every provider, channel, and Kubernetes cluster uses the same pattern: the operator writes a route config, mounts the secret, and the proxy handles injection. Adding a new provider type means writing one injector struct. The gateway code does not change.

**Egress control.** The proxy is a positive-security allowlist. The gateway can only reach domains the operator has configured. This is not a "nice to have" - in a multi-tenant environment where each user has their own Claw instance, you want to limit blast radius.

**Protocol flexibility.** The two CONNECT modes (MITM vs. direct tunnel) mean the proxy works with both standard HTTPS APIs and exotic protocols like WhatsApp's Noise handshake. You do not have to choose between credential injection and protocol compatibility - the proxy handles both, per domain.

The tradeoff is complexity. The operator generates a CA, manages a dedicated proxy workload, builds a dynamic route table, stamps config hashes for rollouts, and wires credentials through env vars and volume mounts. That is a lot of moving parts. But the alternative, teaching the gateway about seven credential types across dozens of providers and channels, is worse. Here, the complexity lives in the operator, where it can be tested systematically, rather than in the gateway, where it would be buried inside application logic.

## Threat model matters

A design like this is easy to oversell, so it is worth being explicit about what security claim it is making, and what claim it is not.

One useful contrast comes from a previously reported cross-sandbox authorization bypass in NVIDIA OpenShell. There, sandbox-scoped gRPC RPCs accepted a caller-supplied `sandbox_id` while the CLI and all sandbox pods shared the same mTLS client certificate. In that architecture, one sandbox could read another sandbox's provider environment, read its policy, create an SSH session, and execute commands in it. The original report and reproducer are public: [report](https://pastebin.com/raw/83V4HT53), [reproducer](https://pastebin.com/raw/F8tVWy4v). NVIDIA's security team agreed that the behavior was technically real, but said it was not a vulnerability in OpenShell's current single-tenant deployment model because all sandboxes already belonged to the same user. They also pointed to follow-up hardening work in [issue #40](https://github.com/NVIDIA/OpenShell/issues/40) and [issue #451](https://github.com/NVIDIA/OpenShell/issues/451).

That contrast is useful here. The design in this operator is safer than a shared-gateway, shared-credential-boundary model for the specific problem of secret isolation because it makes different tradeoffs:

- The unit of deployment and isolation is the `Claw` instance, not a sub-identity inside one shared gateway.
- Real provider secrets normally stay off the gateway process and live on the proxy side, with placeholder values in generated config.
- The proxy is both the credential injector and the layer-7 allowlist, while Kubernetes `NetworkPolicy` constrains the network path around it.

In practice, that means this design is strongest when the operational model is one tenant, user, or team per `Claw` instance and usually one namespace per tenant boundary. In that setup, it is safer than a shared-gateway design because it pushes the trust boundary outward and lets Kubernetes and OpenShift primitives do more of the isolation work.

But that comes with two important caveats.

First, this operator has a privileged control plane. The controller needs broad RBAC to reconcile Deployments, Secrets, NetworkPolicies, Roles, RoleBindings, and even `pods/exec` for device pairing flows. So while compromise of a single `Claw` workload is relatively contained, compromise of the operator itself would have a much larger blast radius.

Second, the gateway authentication model is instance-level, not fine-grained per-user authorization. In token mode there is one random gateway token per instance. In password mode there is one shared password secret per instance. If multiple humans share one `Claw` instance, they are still sharing one gateway and one credential context. This architecture gives you a cleaner per-instance security boundary than a shared-gateway design, but it is not the same thing as fine-grained user-to-user isolation inside a single shared instance.

That is the pragmatic comparison. This operator is safer by default for tenant isolation because it chooses a coarser and more defensible boundary. It does not win by solving shared-instance multi-user authorization better. It mostly avoids that problem by isolating instances instead.

## Takeaways for your own projects

If you are building a Kubernetes operator that manages an application with external API credentials, consider whether an operator-managed credential proxy makes sense. It does not have to be a sidecar. The pattern works well when:

- The application talks to many external services with different auth mechanisms
- You want to enforce egress restrictions at the network level
- The application should not be trusted with raw credentials
- You need to support protocols that do not tolerate TLS interception alongside ones that require it

The injector interface pattern is worth stealing even outside the proxy context. Any time you have N credential types with different injection mechanics, hiding them behind a common interface with a factory function keeps the calling code clean.

The config hash stamping pattern (SHA-256 of config content as a pod annotation) is a well-known Kubernetes trick, but it is worth emphasizing because it solves the "config changed but the pod did not restart" problem without requiring the operator to manage rolling updates itself. Let Kubernetes do what it is good at.
