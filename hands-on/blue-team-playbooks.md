# Blue-team playbooks

The other half of every offensive technique: detect it and respond. As a DevOps/SRE you'll
usually be defending, so this is where you add the most value. Each playbook maps to an attack
stage from `concepts/layers-and-attack-surface.md`.

## Detect: port scan / recon against your estate
- **Signals:** spike in connection attempts across many ports/hosts, many RSTs, flow-log
  fan-out from a single source, WAF/LB 4xx bursts.
- **Where:** VPC/NSG flow logs, IDS (Suricata/Zeek), LB access logs, cloud GuardDuty/SCC.
- **Response:** confirm scope, rate-limit/block source at the edge, verify nothing exposed was
  reachable, snapshot logs. Recon itself isn't a breach — treat it as a signal to re-check
  surface.

## Detect: new/anomalous exposure
- **Signals:** a security group changed to `0.0.0.0/0`, a bucket made public, a new public IP,
  an API server exposed.
- **Where:** AWS Config / Cloud Audit Logs / SCC, IaC drift detection, external ASM scans of
  your own ranges.
- **Response:** auto-revert via policy (SCP / Org Policy / Config remediation), alert the owner,
  root-cause the change (who/what/why), close via guardrail.

## Detect: container/host compromise
- **Signals:** shell spawned in a container, exec into a pod, unexpected outbound connection,
  a process reading `/etc/shadow` or cloud metadata, new SUID file, cron modified.
- **Where:** **Falco** (runtime), auditd, EDR, K8s audit log.
- **Response:** isolate the pod/node (cordon+drain, network-quarantine), preserve forensics
  (snapshot disk/memory, don't just `kill`), rotate any credential the workload could reach,
  redeploy from a known-good image.

## Detect: IAM escalation / credential abuse
- **Signals:** `AttachUserPolicy`/`PutUserPolicy`, new access key, `AssumeRole` from an unusual
  source, `setIamPolicy`, impossible-travel console login, use of a long-dormant key.
- **Where:** CloudTrail / Cloud Audit Logs, GuardDuty/SCC, IAM Access Analyzer.
- **Response:** disable the key/role, revoke sessions, review what it touched, rotate blast-
  radius creds, tighten the policy that allowed the escalation.

## Detect: CI/CD compromise
- **Signals:** pipeline run from an unexpected actor/branch, unexpected registry push, a
  dependency change to an unknown package, secret accessed by a fork PR.
- **Where:** CI audit logs, registry logs, git audit, sigstore verification failures.
- **Response:** freeze deploys, rotate all pipeline secrets, verify last-known-good artifact
  signatures, rebuild from clean state, add the missing guardrail (required review, OIDC,
  signature enforcement).

## The detection maturity ladder
1. **Logs exist and are centralized** (you can answer "what happened" after the fact).
2. **Alerts on high-signal events** (IAM policy change, exec-in-container, public exposure).
3. **Automated response** for the obvious ones (auto-revert public bucket, quarantine pod).
4. **Regular purple-team drills**: run a technique from this repo in a lab that mirrors prod,
   confirm the alert fires, fix the gap. Repeat.

## Build your own detections from this repo
For every technique in `privilege-escalation.md`, write the answer to: *"If someone did this in
prod right now, which log line proves it and which alert would page me?"* If there's no answer,
that's a detection to build. That single exercise, done across all the escalation paths, is a
world-class internal security backlog.

## Frameworks to anchor on
- **MITRE ATT&CK** — map your detections to techniques so you can see coverage gaps.
- **Sigma rules** — portable detection rules (SigmaHQ) you can convert to your SIEM.
- **CIS Benchmarks** — the baseline config each layer should meet.
