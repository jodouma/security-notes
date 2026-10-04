# Cybersecurity for DevOps/SRE — Study & Reference

A working reference for a senior DevOps/SRE who owns the infrastructure and needs to secure
it, audit it, and pass an authorized assessment of it. Written for someone who already knows
Linux, containers, Kubernetes, and cloud — the goal here is the **security lens on top of
what you already run**.

> ⚠️ **Authorization & ethics.** Every technique here is for infrastructure **you own or are
> explicitly authorized in writing to test**. Recon, enumeration, and exploitation tooling is
> illegal against systems you don't have permission for. The framing throughout is
> defender-first: for each attack path, the real payload is *how you detect and close it*.
> When in doubt, don't run it.

## How to study this repo

1. **Build the map** — read `concepts/layers-and-attack-surface.md` so every later command
   has a "which layer am I on" home.
2. **Learn the escalation trees** — `concepts/privilege-escalation.md`. This is the part most
   DevOps folks are weakest on and interviewers probe hardest.
3. **Know where vulns live** — `concepts/vulnerability-by-layer.md` maps each layer to the
   public repos and scanners that find its bugs.
4. **Get hands dirty (authorized lab)** — `hands-on/kali-recon-playbook.md` walks a full
   recon workflow end to end; `hands-on/tooling-commands.md` is the command reference.
5. **Flip to defense** — `hands-on/blue-team-playbooks.md` and `CHECKLIST.md`.
6. **Keep the cheatsheets open** while you work.

Build a legal lab first: TryHackMe, HackTheBox, a local Vagrant/VirtualBox network, or
[vulhub](https://github.com/vulhub/vulhub) containers. Never practice on prod or third parties.

## Table of contents

Concepts
- [Layers & attack surface](concepts/layers-and-attack-surface.md)
- [Privilege escalation — the escalation trees](concepts/privilege-escalation.md)
- [Vulnerability by layer](concepts/vulnerability-by-layer.md)

Hands-on (authorized labs only)
- [Kali recon playbook — step by step](hands-on/kali-recon-playbook.md)
- [Tooling & example commands](hands-on/tooling-commands.md)
- [Blue-team playbooks](hands-on/blue-team-playbooks.md)
- [HTB Fireflow — Langflow to Kubernetes host root](hands-on/htb-fireflow/README.md)

IaC security
- [IaC security & scanning](iac-security/README.md)

Cheatsheets
- [nmap](cheatsheets/nmap.md)
- [recon](cheatsheets/recon.md)
- [Linux privesc audit](cheatsheets/linux-privesc-audit.md)
- [Container & Kubernetes audit](cheatsheets/container-k8s-audit.md)

Reference
- [Best public repos & resources](resources.md)
- [Security readiness checklist](CHECKLIST.md)

## The one-paragraph mental model

Security work is layered enumeration: at every layer you (1) enumerate what exists,
(2) find where trust is misplaced, (3) escalate across a trust boundary, and — the part that
pays your salary — (4) instrument detection and remove the misplaced trust. A DevOps/SRE has
an unfair advantage here because you already understand the systems; you just have to learn to
look at them adversarially and then wire the fix into IaC and CI so it stays fixed.
