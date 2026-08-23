# Security readiness checklist

Two uses: (1) a hardening checklist for infra you run, and (2) an interview/knowledge
self-check. Tick honestly — the gaps are your study/backlog list.

## Attack surface (layer 1 & 5)
- [ ] No management ports (22/3389/6443/2379/etc.) open to `0.0.0.0/0`.
- [ ] No public storage buckets / databases unless deliberately, documented.
- [ ] External attack-surface scan of my own ranges runs on a schedule (subfinder/httpx/nuclei).
- [ ] TLS config scores well (`testssl.sh`): TLS 1.2+, no weak ciphers, valid chain.
- [ ] Admin planes behind VPN/bastion/zero-trust proxy, not the open internet.

## Identity & IAM (layer 5 & 8)
- [ ] No wildcard (`*`) IAM policies in day-to-day roles.
- [ ] `PassRole`/`actAs` restricted to specific scoped roles/SAs.
- [ ] Short-lived federated creds (OIDC/STS/workload identity) instead of static keys.
- [ ] MFA enforced; break-glass admin path is separate, alerted, and audited.
- [ ] IAM escalation graph computed (pmapper / KubiScan) and reviewed.
- [ ] MFA + secret scanning + push protection on all repos.

## Hosts (layer 2)
- [ ] Patch cadence + unattended security updates.
- [ ] Host benchmark (lynis / OpenSCAP / CIS) passing, exceptions documented.
- [ ] No secrets on disk; secrets manager in use; keys `chmod 600`.
- [ ] `sudoers` reviewed; no shell-escapable `NOPASSWD`.
- [ ] `/tmp` `/var/tmp` `/dev/shm` mounted `nosuid,nodev,noexec`.

## Containers & Kubernetes (layer 3 & 4)
- [ ] No `--privileged`; caps dropped to minimum; `allowPrivilegeEscalation: false`.
- [ ] `runAsNonRoot`, `readOnlyRootFilesystem`, seccomp `RuntimeDefault`.
- [ ] Pod Security Admission `restricted` (or Kyverno/Gatekeeper) enforced at admission.
- [ ] RBAC least-privilege; no stray `cluster-admin`; `automountServiceAccountToken: false` where unused.
- [ ] Default-deny NetworkPolicies + explicit allows.
- [ ] Images scanned in CI (trivy/grype); base images patched; no baked secrets.
- [ ] kube-bench / kubescape run regularly; API server + kubelet locked down.
- [ ] Falco (or equivalent) runtime detection deployed.

## Supply chain & CI/CD (layer 6)
- [ ] Dependencies pinned + scanned (osv-scanner/Dependabot/trivy).
- [ ] Secrets scanning in CI (gitleaks) + push protection.
- [ ] IaC scanned + gated (checkov/trivy) in CI and pre-commit.
- [ ] CI actions pinned to SHAs; jobs use least-privilege permissions; OIDC to cloud.
- [ ] Fork PRs cannot access secrets; branch protection + required reviews on pipeline config.
- [ ] Images signed (cosign) and signatures verified at admission; SBOMs generated.

## Application (layer 7)
- [ ] SAST (semgrep/CodeQL) in CI; DAST (ZAP) against staging.
- [ ] OWASP Top 10 controls in place (authz checks, input validation, security headers).
- [ ] Dependencies for the app scanned; deserialization/SSRF hotspots reviewed.

## Detection & response (all layers)
- [ ] Logs centralized: CloudTrail/Audit Logs, VPC flow logs, K8s audit, host auditd.
- [ ] Alerts on high-signal events (IAM policy change, public exposure, exec-in-container).
- [ ] Automated remediation for the obvious ones (revert public bucket, quarantine pod).
- [ ] Incident runbook exists; purple-team drill run in the last quarter.
- [ ] Detections mapped to MITRE ATT&CK; coverage gaps tracked.

## Knowledge self-check (interview prep)
- [ ] I can walk the 8 layers and name the trust boundary + top control at each.
- [ ] I can explain 3 privesc paths each for Linux, containers, K8s, and cloud IAM — and the fix.
- [ ] I can run a full authorized recon workflow from scope to prioritized findings.
- [ ] I can read a tcpdump and an nmap output and say what's wrong.
- [ ] For any technique, I can state the log line that proves it and the alert that catches it.
