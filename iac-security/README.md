# IaC security & scanning

Security shifts left when it lives in your Terraform/Kubernetes/CI, not in a quarterly audit.
This is where a DevOps/SRE has the biggest leverage: encode the fix once, enforce it forever.

## Scan IaC in CI (pick 1–2, gate the pipeline)
```bash
checkov -d .                 # Terraform, K8s, CloudFormation, ARM, Helm — huge ruleset
trivy config .               # includes former tfsec; misconfig + secret + license
kics scan -p .               # multi-IaC (Checkmarx)
terrascan scan -d .          # OPA-based IaC scanner
```
Wire one into a pre-commit hook **and** a required CI check. Fail the build on HIGH/CRITICAL;
allow documented exceptions via inline suppressions so exceptions are visible in code review.

## Example: pre-commit config
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.1   # <!-- TODO verify latest tag -->
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_checkov
      - id: terraform_trivy
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4   # <!-- TODO verify latest tag -->
    hooks:
      - id: gitleaks
```

## Example: CI gate (GitHub Actions sketch)
```yaml
name: iac-security
on: [pull_request]
jobs:
  scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write     # least privilege for the job
    steps:
      - uses: actions/checkout@v4
      - name: Checkov
        uses: bridgecrewio/checkov-action@master   # <!-- TODO pin to a SHA -->
        with:
          directory: .
          soft_fail: false        # fail the PR on findings
      - name: Trivy config
        uses: aquasecurity/trivy-action@master     # <!-- TODO pin to a SHA -->
        with:
          scan-type: config
          severity: HIGH,CRITICAL
```
> Pin actions to a commit SHA, not a moving tag, and grant the job the minimum `permissions:` —
> both are supply-chain hardening (layer 6).

## The high-value Terraform findings these catch
- Security group / firewall open to `0.0.0.0/0` on management ports.
- Public S3/GCS buckets, unencrypted storage/volumes, no bucket versioning.
- IAM policies with `*` actions/resources; over-broad assume-role trust.
- Unencrypted RDS/databases, public database endpoints.
- Missing logging (CloudTrail, VPC flow logs, GKE audit).
- Secrets hardcoded in `.tf` / `.tfvars` (that's what gitleaks is for).

## Policy-as-code (the enforcement layer)
For rules a scanner can't express, use OPA/Rego with **conftest** against `terraform show -json`
plans, or Sentinel (TF Cloud/Enterprise). Example intent: "no resource may be created in a
non-approved region", "every bucket must have encryption + a specific tag". This runs on the
**plan**, so it blocks the change before apply.

## Runtime companion
IaC scanning proves the desired state is safe; **drift detection** (AWS Config, `driftctl`,
`terraform plan` in CI on a schedule) proves reality still matches it. Alert on drift — a
manual console change is how a scanned-clean estate becomes exposed.

See the [Terraform study repo](../../terraform) `security/` section for deeper IaC hardening,
and [resources.md](../resources.md) for the tools' repos.
