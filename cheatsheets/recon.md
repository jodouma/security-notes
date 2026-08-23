# Recon cheatsheet

Passive + active discovery commands. Authorized scope only. See the full workflow in
`../hands-on/kali-recon-playbook.md`.

## Passive (no packets to target)
```bash
# Subdomains
subfinder -d target.com -all -silent
amass enum -passive -d target.com

# Cert transparency (reveals subdomains)
curl -s "https://crt.sh/?q=%25.target.com&output=json" | jq -r '.[].name_value' | sort -u

# WHOIS / ASN
whois target.com
whois -h whois.radb.net -- '-i origin AS12345'    # netblocks for an ASN

# Google dorking (in browser): site:target.com, filetype:pdf, inurl:admin, intitle:index.of
# Public secret leaks in the org's repos:
trufflehog github --org=target-org --only-verified
```

## DNS
```bash
dig +short target.com A
dig target.com ANY
dig +short -x 1.2.3.4                 # reverse
dnsx -l subs.txt -a -resp -silent     # bulk resolve
dnsenum target.com                     # zone transfer attempt + enum
host -t mx target.com                  # mail records
```

## Active web discovery
```bash
httpx -l subs.txt -sc -title -tech-detect -silent      # which are live, tech stack
katana -u https://target.com -d 3 -silent               # crawl for endpoints
ffuf -u https://target/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt -mc 200,301,403
whatweb https://target.com                              # fingerprint tech
wafw00f https://target.com                              # detect WAF
```

## Wordlists
- **SecLists** (`danielmiessler/SecLists`) — installed at `/usr/share/seclists` on Kali.
  Discovery/Web-Content, Usernames, Passwords, Fuzzing, Subdomains.
- `rockyou.txt` at `/usr/share/wordlists/rockyou.txt` (gunzip first).

## Search existing scan data (no packets)
- **Shodan**: `shodan search 'org:"Target Inc"'`, `shodan host 1.2.3.4`
- **Censys**: web UI or CLI. Both index the internet so you learn exposure without scanning.

## OSINT people/orgs (recon-ng, theHarvester)
```bash
theHarvester -d target.com -b all           # emails, hosts, names from public sources
recon-ng                                     # modular OSINT framework
```

**Defender takeaway:** run `subfinder`/`httpx`/Shodan against **your own** org monthly. Whatever
you can find, an attacker already has. External attack-surface management is just recon pointed
at yourself.
