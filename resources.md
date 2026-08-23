# Best public repos & resources

Curated, with a one-line "why it's worth your time." Grouped by how you'll use them. Verify a
link before relying on it — repos move and archive.

## The canonical references
- **swisskyrepo/PayloadsAllTheThings** — the offensive reference: payloads & techniques for
  every web/injection/privesc class. The one bookmark if you keep only one.
- **OWASP/CheatSheetSeries** — the *defensive* counterpart: how to do auth, crypto, headers,
  input validation correctly. Pair it with the above.
- **danielmiessler/SecLists** — every wordlist you'll ever need (dirs, users, passwords, fuzz).
- **GTFOBins** (gtfobins.github.io) + **LOLBAS** (Windows) — which trusted binaries can be
  abused for privesc; your SUID/sudo cross-reference.
- **MITRE ATT&CK** (attack.mitre.org) — the taxonomy to map detections and coverage against.

## Find vulnerabilities by layer
- **projectdiscovery/nuclei** + **nuclei-templates** — templated scanning for known CVEs and
  misconfigs across web/network/cloud. The modern go-to for "scan my stuff for known issues."
- **trickest/cve** — CVEs mapped to public PoCs; good for "is there an exploit for X."
- **aquasecurity/trivy** — one scanner for images, filesystems, IaC, and K8s. Best single
  starting tool for supply chain.
- **gitleaks/gitleaks** & **trufflesecurity/trufflehog** — secrets in git history / images.
- **projectdiscovery** suite (subfinder, httpx, naabu, dnsx, katana) — the recon backbone.

## Cloud
- **prowler-cloud/prowler** — AWS/GCP/Azure CIS + hundreds of checks; run it on your accounts.
- **nccgroup/ScoutSuite** — multi-cloud security posture auditing.
- **nccgroup/PMapper** (principal-mapper) — computes AWS IAM privilege-escalation paths.
- **salesforce/cloudsplaining** — AWS IAM least-privilege gap analysis.
- **google/gcp_scanner** — GCP credential/scope enumeration.
- **RhinoSecurityLabs/pacu** — AWS exploitation framework (lab/authorized) to validate paths.

## Kubernetes & containers
- **aquasecurity/kube-bench** — CIS Kubernetes benchmark checks.
- **kubescape/kubescape** — posture scanning against NSA/CIS frameworks.
- **cyberark/KubiScan** — finds risky RBAC and escalation paths.
- **aquasecurity/kube-hunter** — active cluster hunting (lab/authorized).
- **falcosecurity/falco** — runtime threat detection for containers/K8s.
- **controlplaneio/simulator** & **madhuakula/kubernetes-goat** — deliberately vulnerable K8s to
  practice on legally.

## Host & Linux privesc
- **peass-ng/PEASS-ng** (linPEAS/winPEAS) — the enumeration standard for privesc auditing.
- **carlospolop/hacktricks** (book.hacktricks.xyz) — encyclopedic methodology for every layer.
- **CISOfy/lynis** — host hardening audit (safe for prod).
- **OpenSCAP** / CIS-CAT — benchmark your hosts against CIS/STIG.

## Learn by doing (legal labs)
- **TryHackMe** and **Hack The Box** — guided + free-form, browser or VPN.
- **vulhub/vulhub** — one `docker compose up` per CVE; the fastest way to study a specific bug.
- **OWASP Juice Shop** / **DVWA** — deliberately vulnerable apps for the web layer.
- **PortSwigger Web Security Academy** — free, best-in-class web hacking labs + theory.

## Detection / blue team
- **SigmaHQ/sigma** — portable detection rules; convert to your SIEM.
- **Neo23x0/auditd** & auditd rule sets — Linux audit logging baselines.
- **The DFIR Report** (thedfirreport.com) — real intrusion write-ups; study the kill chains.

## Staying current
- Distro/cloud security bulletins, **CISA KEV** catalog (known-exploited CVEs — patch these
  first), the projectdiscovery/OWASP release feeds, and r/netsec.

> Legend for the study repos the CLI builds: each domain repo's own `resources.md` narrows this
> to that domain. This file is the security-specific master list.
