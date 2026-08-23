# Kali recon playbook — step by step (authorized only)

A repeatable recon workflow you run from Kali against **scope you're authorized to test**.
Structured the way a real engagement runs: scope → passive → active → enumerate → organize.
Every step notes the defender's view so you learn both sides.

> ⚠️ Get written authorization and a defined scope first. Active scanning without permission is
> a crime in most jurisdictions. Use a lab (HackTheBox, TryHackMe, vulhub, a local network you
> own) to practice.

## 0. Set up Kali

```bash
# Keep Kali current; most tools ship in the repo, some you pull from GitHub.
sudo apt update && sudo apt full-upgrade -y

# The projectdiscovery suite is the modern recon backbone — install via their installer or go:
# subfinder, dnsx, httpx, naabu, nuclei, katana
# (in Kali: `sudo apt install -y subfinder httpx-toolkit nuclei` or grab latest from GitHub releases)

# Make a per-engagement workspace and NEVER commit its contents (see .gitignore)
mkdir -p ~/engagements/acme/{scope,recon,scans,loot,notes}
cd ~/engagements/acme
echo "in-scope hosts/CIDRs only" > scope/scope.txt
```

## 1. Define and constrain scope

Put only authorized targets in `scope/scope.txt`. Everything downstream reads from it. Add an
out-of-scope list too and check every target against it before you fire anything active.

```bash
# Example: expand a CIDR to hosts you can iterate over
nmap -sL -n 10.10.10.0/24 | awk '/Nmap scan report/{print $NF}' > scope/hosts.txt
```

## 2. Passive recon (no packets to the target)

Learn as much as possible without touching the target's infrastructure. Nothing here should
alert them.

```bash
# Subdomains from public sources (passive)
subfinder -d acme.com -all -silent | tee recon/subs.txt

# Passive DNS / historical data, cert transparency
# crt.sh via curl (cert transparency logs reveal subdomains)
curl -s "https://crt.sh/?q=%25.acme.com&output=json" | jq -r '.[].name_value' \
  | sort -u >> recon/subs.txt
sort -u -o recon/subs.txt recon/subs.txt

# WHOIS / ASN / netblocks (know what you're allowed to touch)
whois acme.com
# amass for deeper passive enumeration (has active modes too — keep it passive here)
amass enum -passive -d acme.com -o recon/amass_passive.txt
```
Other passive sources: Shodan/Censys (search their existing scans, not yours), Google dorking,
GitHub secret leaks (`trufflehog`/`gitleaks` against the org's public repos), the Wayback Machine.

**Defender view:** cert transparency and public data are unavoidable — assume every subdomain
you publish is known. This is why "security by obscurity" fails; inventory your own external
surface the same way (run `subfinder` on yourself monthly).

## 3. Resolve & find what's alive

```bash
# Resolve subdomains to IPs (fast, from projectdiscovery)
dnsx -l recon/subs.txt -a -resp -silent | tee recon/resolved.txt

# Which hosts actually serve HTTP(S)? Grab titles, status, tech.
httpx -l recon/subs.txt -sc -title -tech-detect -web-server -silent \
  | tee recon/http_live.txt
```

## 4. Active port scanning

Now you're sending packets — must be in-scope and authorized. Two-phase is fastest: sweep wide,
then deep-scan only the open ports.

```bash
# Phase A — fast port discovery across the range
naabu -list scope/hosts.txt -top-ports 1000 -silent -o scans/open_ports.txt
# (or masscan for very large ranges: sudo masscan -iL scope/hosts.txt -p1-65535 --rate 1000)

# Phase B — service/version + default scripts on just the open ports
# Feed naabu output to nmap for the deep scan (see cheatsheets/nmap.md for the full flag rundown)
nmap -sVC -Pn -T4 -iL scans/open_ports.txt -oA scans/nmap_deep
```
Key nmap flags: `-sV` version detection, `-sC` default NSE scripts, `-Pn` skip host discovery
(assume up), `-oA` output all formats (you want the `.xml` for later parsing / reporting).
Full reference in [cheatsheets/nmap.md](../cheatsheets/nmap.md).

**Defender view:** a `-T4` full scan is loud — your IDS/flow logs should light up. If they
don't, that's a detection gap. Practice reading the scan from the blue side too
(see `blue-team-playbooks.md`).

## 5. Service enumeration

Dig into each open service. A few common ones:

```bash
# Web — content discovery + tech + known-vuln templates
ffuf -u https://target/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raytheon.txt -mc all -fc 404
# (SecLists is the wordlist bible: /usr/share/seclists on Kali, or danielmiessler/SecLists)
nuclei -l recon/http_live.txt -severity medium,high,critical -o scans/nuclei.txt

# SMB
enum4linux-ng -A target
smbclient -L //target/ -N          # null session?

# TLS posture
testssl.sh https://target | tee scans/testssl.txt
```

## 6. Organize findings

Keep everything structured so a report writes itself and nothing is lost.

```
recon/     subs.txt, resolved.txt, http_live.txt
scans/     nmap_deep.{nmap,gnmap,xml}, nuclei.txt, testssl.txt
notes/     per-host markdown: what's open, versions, hypotheses, evidence
loot/      (gitignored) anything sensitive
```
Consider **Faraday** or a simple `notes/<host>.md` per target. Tag each finding with layer
(from `concepts/vulnerability-by-layer.md`) and severity.

## 7. From recon to action

Recon's output is a prioritized list of trust boundaries to test. Rank by (exposure ×
impact): an unauthenticated admin panel on the internet beats a patched service on an internal
host. For each candidate, form a hypothesis, validate carefully in scope, and — the deliverable
that matters — write the **fix**: the config/IaC/RBAC change that removes it, plus the detection
that would have caught it.

## The workflow in one screen

```
scope.txt
   │ passive (subfinder, crt.sh, amass -passive, whois, shodan)
   ▼
subs.txt ──dnsx──► resolved.txt ──httpx──► http_live.txt
   │ active (naabu/masscan → nmap -sVC)
   ▼
open_ports → nmap_deep.xml
   │ enumerate (ffuf, nuclei, enum4linux, testssl)
   ▼
per-host notes → prioritized findings → FIXES + detections
```

Next: [tooling & example commands](tooling-commands.md) for the per-tool detail.
