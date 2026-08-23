# Container & Kubernetes audit cheatsheet

Auditing containers/clusters **you own**. Find the escape/escalation path, then close it.

## Am I in a container? What can it do?
```bash
cat /proc/1/cgroup                        # docker/containerd/kubepods = containerized
capsh --print                             # my capabilities (SYS_ADMIN/SYS_PTRACE = danger)
mount | grep -E 'docker.sock|hostpath|/host'
ls -la /var/run/docker.sock 2>/dev/null   # mounted docker socket = trivial escape
env | grep -i kube                        # leaking SA token / kube env?
cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null | cut -c1-20
```
Lab tools: `amicontained` (Jessie Frazelle), `deepce` — one-shot escape assessment.

## Container image hygiene (your images)
```bash
trivy image myorg/app:latest              # CVEs in OS + libs
grype myorg/app:latest                    # alt CVE scanner
dockle myorg/app:latest                   # image lint / CIS best practices
syft myorg/app:latest -o table            # SBOM
docker history --no-trunc myorg/app:latest # inspect layers (secrets baked in?)
gitleaks detect --source .                # secrets before they get baked in
```

## Kubernetes RBAC & posture (your cluster)
```bash
kubectl auth can-i --list                                   # what THIS identity can do
kubectl auth can-i create pods -A
kubectl auth can-i '*' '*'                                   # am I basically admin?

# Who has cluster-admin?
kubectl get clusterrolebindings -o json | jq -r '.items[]
  | select(.roleRef.name=="cluster-admin")
  | .subjects[]?  | "\(.kind)/\(.name)"' | sort -u

# ClusterRoles with dangerous verbs
kubectl get clusterroles -o json | jq -r '.items[]
  | select(.rules[]?.verbs[]? | test("^(create|escalate|bind|impersonate|\\*)$"))
  | .metadata.name' | sort -u

# SAs that auto-mount tokens (reduce these)
kubectl get pods -A -o json | jq -r '.items[]
  | select(.spec.automountServiceAccountToken != false)
  | "\(.metadata.namespace)/\(.metadata.name)"' | head
```

## Benchmark / posture scanners
```bash
kube-bench run --targets master,node      # CIS Kubernetes benchmark
kubescape scan --format pretty            # NSA/CIS frameworks, posture score
trivy k8s --report summary cluster        # cluster-wide vuln + misconfig
kubiscan --all                            # RBAC risky perms + escalation (CyberArk)
polaris audit                             # workload best-practices
kubeaudit all                             # security misconfig in workloads
kube-hunter --remote <ip>                 # active hunt (LAB / authorized only)
```

## Fix map
| Finding | Fix |
|---------|-----|
| `--privileged` / SYS_ADMIN | drop ALL caps, add back minimum; enforce via PSA `restricted` |
| docker.sock / CRI socket mounted | never mount into workloads |
| hostPath / hostPID / hostNetwork | remove; use proper volumes/services |
| runs as root, writable rootfs | `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation:false` |
| SA bound to cluster-admin | scope to a namespaced Role with least verbs |
| `create pods` / `exec` broadly granted | restrict; these are escalation primitives |
| token auto-mounted unnecessarily | `automountServiceAccountToken: false` |
| no NetworkPolicy | default-deny + explicit allows per namespace |
| image CVEs / baked secrets | rebuild on patched base, scan in CI, secrets via mounts |

Enforce the fixes at **admission** (Pod Security Admission `restricted`, Kyverno, or Gatekeeper)
so a bad manifest is rejected in CI/at deploy, not found at runtime. Add **Falco** for the
runtime signals you can't prevent.
