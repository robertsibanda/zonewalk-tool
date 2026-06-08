# 1-grid Agent Toolkit

DNS & mail diagnostics + ticket/conversation warehouse with multi-user opencode integration.

- **Zonewalk** — L3 DNS and mail diagnostics for 1-grid hosting
- **Warehouse** — MongoDB-backed ticket, conversation, and KB storage
- **Opencode** — Full agent config with warehouse tools for every conversation
- **Multi-user** — Per-user isolation of tickets and conversations

![Zonewalk Banner](https://dev-robert.co.za/portal)

## Features

### Zonewalk
- DNS Checks (A, MX, NS, SOA, TXT, PTR, CNAME, AAAA)
- Mail Auth (SPF, DKIM, DMARC audit)
- Global propagation check (10 resolvers)
- Port scanning, subdomain enumeration, IP reputation
- Email header analysis with spoofing detection
- Issue diagnostics & technician guide

### Warehouse
- Ticket tracking with full history
- Conversation storage with AI context
- KB articles for quick reference
- Server inventory
- Zonewalk result caching

### Opencode Integration
- `zonewalk` — Run DNS diagnostics
- `warehouse-search` — Search tickets, conversations, KB
- `warehouse-tickets` — List recent tickets
- `warehouse-save-ticket` — Save ticket to warehouse
- `warehouse-save-conv` — Save conversation exchange
- `warehouse-my-convs` — Your conversations
- `warehouse-my-tickets` — Your tickets

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/robertsibanda/zonewalk-tool/main/install.sh | sudo bash
```

Or from a cloned repo:
```bash
git clone https://github.com/robertsibanda/zonewalk-tool.git
cd zonewalk-tool
sudo bash install.sh
```

## Multi-User Setup

Each team member sets their identity:
```bash
export USER_ID=alice
warehouse-query register-user --id alice --name "Alice" --team "L1 Support"
```

Tickets and conversations are automatically tagged with `user_id` for isolation.

## Prerequisites

- **MongoDB** — Required for warehouse features
- **Opencode** — Installed automatically if missing
- **Python 3 + pymongo** — For warehouse CLI

## Repository Structure

```
zonewalk-tool/
├── zonewalk.sh              # DNS & mail diagnostics
├── install.sh               # Full installer
├── opencode-agent.jsonc     # Opencode agent config template
├── version.txt              # Current version
├── warehouse/               # Exported warehouse data
│   ├── tickets.json         # Ticket records
│   ├── agent_conversations.json
│   ├── kb_articles.json
│   ├── zonewalk_results.json
│   └── ...
└── scripts/
    └── warehouse-query.py   # Warehouse CLI tool
```

## Portfolio & Portal

- **Portfolio:** https://dev-robert.co.za
- **Portal:** https://dev-robert.co.za/portal

## License

Internal 1-grid tool — use with permission.
