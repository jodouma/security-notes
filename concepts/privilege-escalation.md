# Privilege escalation — the escalation trees

The heart of the repo. For each layer: the common escalation paths, **how to audit for them on
systems you own**, and how to close them. Framing is defensive — you're finding these before
someone else does. Commands assume a lab or an authorized engagement.

Rule of thumb: escalation almost always comes from **something writable that gets executed by
something more privileged**, or **a credential left where a lower-privilege actor can read it.**

---

## 1. Linux host: user → root

### Common paths
- **Sudo misconfig.** `sudo -l` shows what you can run as root. Any entry with `NOPASSWD`,
  a wildcard, or a binary with a shell escape (see GTFOBins) is a path. Classic: `sudo vim`,
  `sudo less`, `sudo find ... -exec`, `sudo tar --checkpoint-action`.
- **SUID/SGID binaries.** A SUID-root binary that can be coerced into running arbitrary code
  hands you root. Custom/unusual SUID binaries are the red flag.
- **Writable cron / systemd units / PATH.** A root cron job that runs a script in a
  world-writable dir, or a service whose binary/working dir you can write, or a `PATH` that
  puts a writable dir before `/usr/bin`.
- **Capabilities.** A binary with `cap_setuid`, `cap_dac_override`, etc. set via
  `setcap` is effectively SUID for that capability.
- **Kernel exploits.** Outdated kernel with a known local-privesc CVE (Dirty Pipe / Dirty COW
  class). Last resort in real engagements; patching is the whole defense.
- **Credentials on disk.** Passwords in history files, `.env`, config, `/var/backups`, world-
  readable private keys, cloud metadata tokens.

### Audit it (run on a box you own)
```bash
sudo -l                                   # what can I run as root?
find / -perm -4000 -type f 2>/dev/null    # SUID binaries
find / -perm -2000 -type f 2>/dev/null    # SGID binaries
getcap -r / 2>/dev/null                   # file capabilities
find / -writable -type d 2>/dev/null | grep -E 'cron|systemd|/etc' # writable sensitive dirs
crontab -l; ls -la /etc/cron*             # cron jobs
grep -RiE 'password|secret|token' /etc /home 2>/dev/null | head  # plaintext creds
```
Cross-reference any custom SUID binary or sudo-allowed binary against **GTFOBins**
(https://gtfobins.github.io) — if it's listed, it's exploitable.

Automate it with **linPEAS** (`peass-ng`) or **LinEnum** in a lab. In prod, use a config
scanner (Lynis, CIS-CAT, OpenSCAP) instead of an offensive enum tool.

### Close it
- `NOPASSWD` only for narrowly scoped, non-shell-escapable commands; audit `sudoers` in CI.
- Remove or `nosuid`-mount unnecessary SUID binaries; `nosuid,nodev,noexec` on `/tmp`,
  `/var/tmp`, `/dev/shm`.
- No world-writable dirs in root's PATH or cron scripts; own them `root:root 0755`.
- Patch kernels on a cadence; enable unattended-security-updates.
- Secrets in a manager (Vault, SSM, cloud secrets), never on disk; `chmod 600` all keys.

---

## 2. Container → host (escape)

### Common paths
- **`--privileged`** container: near-total access to host devices; trivially escapes.
- **Mounted `docker.sock`** (`/var/run/docker.sock`): you can `docker run` a new privileged
  container mounting `/` = host root.
- **`hostPath` / host mounts** of sensitive paths (`/`, `/etc`, `/var/run`, `/proc`).
- **Dangerous capabilities**: `CAP_SYS_ADMIN`, `CAP_SYS_PTRACE`, `CAP_DAC_READ_SEARCH`.
- **`hostPID` / `hostNetwork` / `hostIPC`**: see and signal host processes, read host network.
- **cgroup `release_agent`** escape when `CAP_SYS_ADMIN` + writable cgroup.
- **Writable host mounts of the kubelet dir or CRI socket.**

### Audit it (inside a container you own)
```bash
cat /proc/1/cgroup                        # am I in a container? which runtime?
capsh --print                             # what capabilities do I have?
mount | grep -E 'docker.sock|/host|hostpath'
ls -la /var/run/docker.sock 2>/dev/null   # is the docker socket mounted?
env | grep -i kube                        # service account / kube env leaking?
```
Tools: **deepce** and **amicontained** (Jessie Frazelle) tell you escape potential in one shot,
in a lab.

### Close it
- Never run `--privileged` in prod; drop all caps and add back only what's needed
  (`securityContext.capabilities.drop: ["ALL"]`).
- Never mount `docker.sock` or the CRI socket into a workload. If you need docker-in-docker,
  isolate it.
- `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`,
  a seccomp profile (`RuntimeDefault`), and AppArmor/SELinux.
- Enforce with **Pod Security Admission** (`restricted`) or Kyverno/Gatekeeper policies so a
  bad manifest is rejected at admission, not discovered at runtime.
- Runtime detection with **Falco** (alerts on shell-in-container, mount of sensitive paths,
  unexpected exec).

---

## 3. Kubernetes: pod/SA → cluster-admin

### Common paths
- **Over-privileged RBAC.** A ServiceAccount bound to `cluster-admin`, or verbs like
  `create pods`, `create/patch clusterrolebindings`, `escalate`/`bind`, `impersonate`, or
  `get secrets` cluster-wide. `create pods` alone is often game over: schedule a pod that
  mounts a privileged SA token or a host path.
- **`pods/exec`, `pods/attach`, `pods/portforward`** into a pod that has a better SA.
- **Reading Secrets** → other services' credentials, cloud keys.
- **`nodes/proxy`** or kubelet access → run on nodes.
- **Mounting the default SA token** (auto-mounted) in a pod that gets popped.
- **Exposed kubelet (10250) or unauth'd API server**.

### Audit it (cluster you own)
```bash
kubectl auth can-i --list                         # what can THIS identity do?
kubectl auth can-i create pods -A
kubectl get clusterrolebindings -o wide | grep -i cluster-admin
kubectl get rolebindings,clusterrolebindings -A -o json \
  | jq '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'
# find SAs with dangerous verbs:
kubectl get clusterroles -o json | jq -r '.items[] |
  select(.rules[]?.verbs[]? | test("create|impersonate|escalate|bind|\\*")) | .metadata.name'
```
Tools: **KubiScan** (CyberArk) enumerates risky RBAC and escalation paths; **kubescape**,
**kube-bench** (CIS), **kube-hunter** (in a lab), **Peirates** for attack-path validation.

### Close it
- Least-privilege RBAC: no `*` verbs/resources, no cluster-wide `secrets` read, scoped
  Roles > ClusterRoles. Review bindings in CI (OPA/conftest on RBAC manifests).
- `automountServiceAccountToken: false` unless the pod truly needs the API.
- Separate namespaces + NetworkPolicies to contain lateral movement.
- Bind cloud IAM to specific SAs via workload identity, not node-wide.
- Lock down kubelet (`--anonymous-auth=false`, authz webhook), API server not public.
- Audit logging on, alert on `create clusterrolebinding`, `exec`, secret reads.

---

## 4. Cloud IAM escalation

Same idea, cloud-flavored: a low-priv identity that can **grant itself more** or **act as**
something bigger.

### AWS common paths
- `iam:PassRole` + a compute create (`lambda:CreateFunction`+`Invoke`, `ec2:RunInstances`,
  `glue`, `cloudformation`) → run code as a privileged role.
- `iam:CreatePolicyVersion` / `SetDefaultPolicyVersion` → rewrite your own policy.
- `iam:AttachUserPolicy` / `PutUserPolicy` → attach `AdministratorAccess`.
- `iam:CreateAccessKey` for another user; `sts:AssumeRole` with a permissive trust policy.
- `iam:UpdateAssumeRolePolicy`, `iam:CreateLoginProfile`, `iam:PassRole`→EC2 instance profile.

Audit: **Cloudsplaining**, **pmapper** (principal-mapper: literally computes escalation
paths), **PMapper**/`aws iam simulate-principal-policy`, ScoutSuite, Prowler. **Pacu** to
validate paths in a lab.

### GCP common paths
- `iam.serviceAccounts.actAs` / `getAccessToken` → impersonate a privileged SA.
- `iam.serviceAccountKeys.create` → mint a key for a better SA.
- `setIamPolicy` on a project/resource → grant yourself owner.
- Deploying to Cloud Functions/Run/Compute with a privileged runtime SA.

Audit: **gcp_scanner** (Google), ScoutSuite, Prowler (GCP), and `gcloud ... get-iam-policy`.

### Close it (both clouds)
- No `iam:*` / `resourcemanager.*.setIamPolicy` in day-to-day roles; separate a break-glass
  admin path with MFA and alerting.
- Deny `PassRole`/`actAs` except to specific, scoped roles/SAs via conditions.
- Prefer short-lived federated creds (OIDC from CI, workload identity) over static keys.
- Continuously scan with pmapper / Cloudsplaining / gcp_scanner in CI and alert on IAM policy
  changes (CloudTrail / Cloud Audit Logs).

---

## 5. CI/CD & supply chain

Often the fastest path to prod because pipelines hold the keys.

### Common paths
- **Poisoned dependency** (typosquat, compromised maintainer, dependency confusion).
- **Pipeline with prod credentials** triggered by untrusted PRs (fork PRs running with
  secrets, `pull_request_target` misuse in GitHub Actions).
- **Writable IaC / pipeline config** merged without review → arbitrary steps run with the
  runner's identity.
- **Registry with weak auth** → push a backdoored image over a trusted tag.
- **Long-lived cloud keys in CI env vars.**

### Close it
- Pin dependencies by hash; use a lockfile; enable dependency review + SCA (Dependabot,
  Snyk, `osv-scanner`, Trivy). Guard against dependency confusion (scoped registries).
- No secrets available to fork PRs; least-privilege runner identity; OIDC to cloud instead of
  static keys; required reviews + branch protection on pipeline config.
- Sign images (**cosign/sigstore**), verify signatures at admission, generate SBOMs (**syft**)
  and scan (**grype/trivy**), adopt SLSA provenance.
- Ephemeral runners; no persistent state between jobs.

---

## The meta-lesson

Escalation is a graph problem: nodes are identities/hosts, edges are "can become / can reach."
Attackers enumerate the graph and find a path to the crown jewels. Your job is to **compute the
same graph before they do** (pmapper, KubiScan, BloodHound for AD) and cut the edges you didn't
mean to leave. Do it in CI so the graph stays cut.

See the [Linux privesc audit cheatsheet](../cheatsheets/linux-privesc-audit.md) and
[container/k8s audit cheatsheet](../cheatsheets/container-k8s-audit.md) for the copy-paste
versions.
