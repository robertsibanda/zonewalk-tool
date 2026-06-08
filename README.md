# ZONEWALK — DNS & Mail Diagnostics Tool

L3 DNS and mail diagnostics for 1-grid hosting, with support for external providers.

Developed by **[Robert Sibanda](https://dev-robert.co.za)**
- Portfolio: https://dev-robert.co.za
- Portal: https://dev-robert.co.za/portal

## Features

- **DNS Checks** — A, MX, NS, SOA, TXT, PTR, CNAME, AAAA
- **Mail Auth** — SPF, DKIM, DMARC audit with policy analysis
- **Global Propagation** — Check A record across 10 resolvers worldwide
- **Port Scanning** — 17 common ports (FTP, SSH, SMTP, HTTP, MySQL, etc.)
- **Subdomain Enumeration** — 35+ common subdomains
- **IP Reputation** — Spamhaus, SpamCop, SORBS, Barracuda, UCEProtect, PSBL
- **Email Header Analysis** — Parse headers, spoofing detection, hop-by-hop trace
- **Issue Diagnostics** — Targeted checks for mail-send, mail-recv, web-down, dns-fail
- **Technician Guide** — Step-by-step fix instructions per issue
- **Auto-Update Check** — Checks for new version once daily

## Quick Install

```bash
# From cloned repo
git clone https://github.com/robertsibanda/zonewalk-tool.git
cd zonewalk-tool
sudo bash install.sh

# Or directly (requires curl + sudo)
curl -sSL https://raw.githubusercontent.com/robertsibanda/zonewalk-tool/main/install.sh | sudo bash
```

The installer will:
1. Install dependencies (`dig`, `whois`, `curl`, `nc`, `openssl`)
2. Copy `zonewalk` to `/usr/local/bin/`
3. Configure opencode to use zonewalk as a tool (if opencode is installed)
4. Set up daily update checks via cron

## Usage

```bash
zonewalk domain.co.za
zonewalk domain.co.za --issue mail-send
zonewalk domain.co.za --issue mail-recv
zonewalk domain.co.za --deep
zonewalk domain.co.za --ports
zonewalk domain.co.za --ip-reputation
zonewalk domain.co.za --ptr
zonewalk domain.co.za --headers headers.txt
zonewalk domain.co.za --guide
```

### Options

| Option | Description |
|--------|-------------|
| `--issue mail-send` | Outbound mail failure (SPF/DKIM/DMARC/PTR audit) |
| `--issue mail-recv` | Inbound mail failure (MX/ports) |
| `--issue web-down` | Website not loading |
| `--issue dns-fail` | DNS resolution failure |
| `--issue propagation` | Propagation analysis only |
| `--issue wrong-domain` | Wrong domain registration |
| `--issue spam-received` | Inbound spam analysis (paste headers) |
| `--deep` | Subdomain enumeration |
| `--ports` | Common port scan |
| `--ip-reputation` | Blocklist check |
| `--ptr` | PTR consistency audit |
| `--headers <file>` | Parse email headers |
| `--skip-propagation` | Skip propagation section |
| `--guide` | Print fix guide only |

### Examples

```bash
# Standard diagnostic
zonewalk example.co.za

# Outbound mail troubleshooting
zonewalk example.co.za --issue mail-send

# Full scan + subdomain enumeration
zonewalk example.co.za --deep --ports

# Diagnose a received spam email
zonewalk example.co.za --issue spam-received
# Then paste the email headers and press Ctrl+D

# Parse headers from file
zonewalk example.co.za --headers spam-headers.txt

# Get fix steps for detected issues
zonewalk example.co.za --guide
```

## Requirements

- `dig` (bind-utils / dnsutils)
- `whois`
- `curl`
- `nc` (netcat)
- `openssl`

Installed automatically by the installer on Debian/Ubuntu, RHEL/CentOS, Fedora, Arch, and openSUSE.

## Repository Structure

```
zonewalk-tool/
├── zonewalk.sh    # Main diagnostics script
├── install.sh     # Installer script
├── version.txt    # Current version
└── README.md      # This file
```

## License

Internal 1-grid tool — use with permission.
