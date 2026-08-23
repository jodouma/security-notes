# nmap cheatsheet

Authorized targets only. `nmap` is the port/service scanner you'll reach for constantly.

## Host discovery
```bash
nmap -sn 10.10.10.0/24            # ping sweep, no port scan (find live hosts)
nmap -Pn target                   # skip discovery, assume host is up (past firewalls)
nmap -sL 10.10.10.0/24            # list targets without scanning (expand CIDR)
nmap -n target                    # no DNS resolution (faster)
```

## Port selection
```bash
nmap target                       # top 1000 TCP ports (default)
nmap -p- target                   # ALL 65535 TCP ports
nmap -p22,80,443 target           # specific ports
nmap -F target                    # fast: top 100 ports
nmap --top-ports 20 target        # top N most common
nmap -sU --top-ports 50 target    # UDP scan (slow; DNS, SNMP, NTP, etc.)
```

## Scan techniques
```bash
nmap -sS target                   # SYN "stealth" scan (default as root, half-open)
nmap -sT target                   # full TCP connect (non-root)
nmap -sV target                   # service/version detection
nmap -sC target                   # default NSE scripts (safe-ish, informative)
nmap -sVC target                  # -sV + -sC together (very common combo)
nmap -O target                    # OS fingerprinting (needs root)
nmap -A target                    # aggressive: -sV -sC -O + traceroute
```

## Timing & performance
```bash
nmap -T4 target                   # faster (T0 paranoid … T5 insane). T4 = good default on LAN.
nmap --min-rate 1000 target       # push packet rate
nmap --max-retries 1 target       # fewer retries = faster, less thorough
```

## NSE scripts
```bash
nmap --script vuln target                     # vuln category (noisy — lab)
nmap --script "default,safe" target
nmap --script http-title,http-headers -p80,443 target
nmap --script smb-enum-shares,smb-os-discovery -p445 target
nmap --script ssl-enum-ciphers -p443 target   # TLS cipher audit
ls /usr/share/nmap/scripts/ | grep http       # browse available scripts
```

## Output (always save it)
```bash
nmap -sVC -oA myscan target       # -oA = all formats: .nmap (human), .gnmap (grep), .xml (parse)
nmap -sVC -oN scan.txt target     # normal
nmap -sVC -oX scan.xml target     # XML (feed to reporting tools, searchsploit, etc.)
nmap -v target                    # verbose; -vv more; -d debug
```

## Common recipes
```bash
# Full deep scan of one host, saved
nmap -sVC -Pn -p- -T4 -oA host_full target

# Two-phase: fast discovery then deep scan only open ports
ports=$(nmap -p- --min-rate 1000 -T4 target | grep ^[0-9] | cut -d/ -f1 | paste -sd, -)
nmap -sVC -p"$ports" -oA host_deep target

# Scan a list, skip discovery
nmap -sVC -Pn -iL hosts.txt -oA sweep
```

## Reading the output
- `open` — service reachable and responding.
- `filtered` — a firewall dropped the probe (no response). Often more interesting than closed.
- `closed` — reachable host, port not listening.
- `open|filtered` — couldn't tell (common on UDP).

**Defender note:** a `-p- -T4` scan is loud and slow-and-low `-T1` scans exist to evade IDS.
Your flow logs + IDS should catch both — if they don't, that's your detection gap.
