# Layers & attack surface

A DevOps/SRE already thinks in layers for reliability. Security uses the same stack — the
question just changes from "where does this break under load" to "where is trust misplaced."
Keep this map in your head; every command in `hands-on/` lives on one of these layers.

## The eight layers you defend

| # | Layer | You own | Primary trust boundary | What an attacker wants here |
|---|-------|---------|------------------------|-----------------------------|
| 1 | **Network / perimeter** | firewalls, SGs, LBs, VPN | public ↔ private | a reachable service; a way in |
| 2 | **Host / OS** | the Linux box, kernel, users | user ↔ root | local privesc to root |
| 3 | **Container** | image + runtime | container ↔ host | escape to the node |
| 4 | **Orchestrator (K8s)** | RBAC, admission, etcd | pod ↔ cluster-admin | token/SA escalation, node access |
| 5 | **Cloud IAM** | roles, policies, SAs | identity ↔ resource | assume a more privileged role |
| 6 | **CI/CD & supply chain** | pipelines, registries, deps | code ↔ prod | poison a build, steal a secret |
| 7 | **Application** | the code you ship | user ↔ app internals | injection, authz bypass, SSRF |
| 8 | **Identity / human** | SSO, MFA, secrets | person ↔ credential | phishing, leaked keys, session theft |

The through-line: **an attack is a sequence of trust-boundary crossings.** Recon on the left,
initial access somewhere in the middle, then a chain of escalations rightward and upward until
they own something that matters. Your defensive job is to make each crossing (a) hard and
(b) loud.

## The attacker loop (and where you break it)

```
  Recon ──► Initial access ──► Foothold ──► Privilege escalation ──► Lateral movement
    │             │                │                 │                      │
    │             │                │                 │                      ▼
    │             │                │                 │              Persistence / exfil
    ▼             ▼                ▼                 ▼                      ▼
 attack        patch /          EDR /           least priv,          egress control,
 surface       WAF /            runtime          hardening,           segmentation,
 reduction     input valid.     detection        audit               DLP, alerting
```

Every stage has a matching defensive control. When you review your own environment, walk the
loop left to right and ask "what stops this stage, and would I see it happen?"

## Attack surface = the sum of reachable trust boundaries

Reduce surface before you harden what's left. In priority order for infra teams:

1. **Kill reachability.** The safest service is the one that isn't exposed. Private subnets,
   security groups scoped to source, no `0.0.0.0/0` on management ports, VPN/bastion or
   zero-trust proxy for admin planes. Most breaches start with something that shouldn't have
   been on the internet (an exposed etcd, a public S3 bucket, a Redis with no auth, a
   Kubernetes API server open to the world).
2. **Remove standing privilege.** Long-lived keys, wildcard IAM, `cluster-admin` bindings,
   shared root — each is a pre-positioned escalation. Prefer short-lived, scoped, auditable
   credentials (OIDC federation, STS, workload identity).
3. **Shrink the blast radius.** Segmentation (network policies, separate accounts/projects),
   so crossing one boundary doesn't hand over everything.
4. **Then harden and instrument** what remains: patch, config baselines, and detection.

## The one habit to build

For any system you run, be able to answer three questions instantly:
- **What is reachable, from where?** (surface)
- **If this box/pod/role is popped, what can it reach or become?** (blast radius / escalation)
- **Would I see it, and how fast?** (detection)

If you can't answer all three for your critical systems, that's your backlog.

Next: [privilege escalation trees](privilege-escalation.md) — the "what can it become" question,
layer by layer.
