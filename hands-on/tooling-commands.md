# Tooling & example commands (authorized only)

Per-tool reference with example invocations. Defensive/authorized framing. Pair with the
cheatsheets for dense flag lists.

## Discovery & recon
```bash
# subfinder — passive subdomain enum
subfinder -d target.com -all -silent -o subs.txt

# amass — deep enum (passive to stay quiet)
amass enum -passive -d target.com -o amass.txt

# dnsx — resolve + record types
dnsx -l subs.txt -a -aaaa -cname -resp -silent

# httpx — probe live web servers
httpx -l subs.txt -sc -title -tech-detect -location -silent

# naabu — fast port discovery
naabu -host target.com -top-ports 1000 -silent

# masscan — internet-scale sweep (own ranges only)
sudo masscan -iL ranges.txt -p80,443,22 --rate 1000 -oL masscan.txt
```

## Scanning
```bash
# nmap — the workhorse (full flags in cheatsheets/nmap.md)
nmap -sVC -Pn -T4 -p- -oA host_full target        # all ports, versions, default scripts
nmap -sU --top-ports 50 target                     # UDP top 50
nmap --script vuln target                          # NSE vuln category (noisy, lab)

# nuclei — templated CVE/misconfig checks
nuclei -u https://target -severity high,critical
nuclei -l http_live.txt -t http/exposures/ -o exposures.txt

# testssl.sh / sslscan — TLS posture
testssl.sh --quiet --color 0 https://target
sslscan target:443
```

## Web enumeration
```bash
# ffuf — content & vhost discovery
ffuf -u https://target/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt -mc 200,301,302,403
ffuf -u https://target/ -H "Host: FUZZ.target.com" -w subs.txt -fs 0   # vhost fuzzing

# feroxbuster — recursive content discovery
feroxbuster -u https://target -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt

# gobuster — dir/dns/vhost modes
gobuster dir -u https://target -w /usr/share/wordlists/dirb/common.txt
```

## Secrets & supply chain (run on your own repos/images)
```bash
gitleaks detect --source . --report-path gitleaks.json      # secrets in git history
trufflehog git file://. --only-verified                      # verified live secrets
trivy image myorg/app:latest                                 # image CVEs
grype myorg/app:latest                                       # image CVEs (alt)
syft myorg/app:latest -o spdx-json > sbom.json               # SBOM
osv-scanner --lockfile package-lock.json                     # dependency CVEs
semgrep --config auto .                                       # SAST
```

## IaC & cloud config (your own accounts)
```bash
checkov -d .                     # terraform/k8s/cloudformation misconfig
tfsec .                          # terraform (now merged into trivy: `trivy config .`)
kics scan -p .                   # multi-IaC scanner
prowler aws                      # AWS CIS + hundreds of checks
scout gcp                        # ScoutSuite for GCP (also aws/azure)
pmapper --profile me graph create; pmapper query 'preset privesc *'   # AWS IAM escalation graph
```

## Kubernetes audit (your own clusters)
```bash
kube-bench run --targets master,node        # CIS benchmark
kubescape scan                              # posture + NSA/CIS frameworks
trivy k8s --report summary cluster          # cluster-wide vuln + misconfig
kubiscan --all                              # RBAC escalation paths (CyberArk)
kubectl auth can-i --list                   # what can this identity do
polaris audit --format pretty               # workload best-practices
```

## Host audit (your own hosts)
```bash
lynis audit system                          # host hardening audit
sudo openscap oscap xccdf eval ...          # CIS/DISA STIG benchmark (OpenSCAP)
# In a lab only — offensive enum:
./linpeas.sh | tee linpeas.txt              # peass-ng
pspy64                                       # watch cron/processes without root
```

## Password/auth testing (authorized, lab)
```bash
# Only against systems you're authorized to test, with an approved wordlist.
hydra -L users.txt -P pass.txt ssh://target       # network login brute (authorized only)
john --wordlist=rockyou.txt hashes.txt            # offline hash cracking (your own hashes)
hashcat -m 1800 hashes.txt rockyou.txt            # GPU cracking (your own hashes)
```

## A note on responsible use
The offensive tools above (hydra, sqlmap, metasploit, the `--script vuln` scans, linpeas) are
for **authorized testing and your own lab**. In production, prefer the audit-oriented
equivalents (lynis, openscap, prowler, kube-bench) which are read-only and safe to run
continuously. Wire the safe ones into CI; keep the loud ones in the lab.

See [nmap](../cheatsheets/nmap.md), [recon](../cheatsheets/recon.md),
[linux privesc audit](../cheatsheets/linux-privesc-audit.md), and
[container/k8s audit](../cheatsheets/container-k8s-audit.md) cheatsheets for more.
