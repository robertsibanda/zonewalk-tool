#!/bin/bash
# 1-grid Agent — opencode wrapper with auto-setup
# First run prompts for name, registers in warehouse, then opens opencode

CONFIG_FILE="$HOME/.1grid-agent-user.json"
MONGO_URI="${MONGO_URI:-mongodb://support_admin:claire6772147@41.61.20.67:27017/admin}"
MONGO_DB="${MONGO_DB:-support_ai}"

# ── Colors ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

# ── First-run registration ──
if [ ! -f "$CONFIG_FILE" ]; then
    clear
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}  1-GRID AGENT TOOLKIT${NC}                                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}Let's get you set up!${NC}                                    ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${YELLOW}This is your first time running 1-grid Agent.${NC}"
    echo ""
    echo -en "  ${WHITE}Enter your name:${NC} "
    read -r USER_NAME
    echo -en "  ${WHITE}Enter your email (optional):${NC} "
    read -r USER_EMAIL
    echo -en "  ${WHITE}Enter your team (e.g., L1 Support):${NC} "
    read -r USER_TEAM

    # Defaults
    USER_NAME="${USER_NAME:-$USER}"
    USER_TEAM="${USER_TEAM:-1-grid Support}"

    # Register in MongoDB warehouse
    echo ""
    echo -e "  ${CYAN}Registering in warehouse...${NC}"
    if warehouse-query register-user --id "$USER_NAME" --name "$USER_NAME" \
        --email "$USER_EMAIL" --team "$USER_TEAM" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Registered successfully${NC}"
    else
        echo -e "  ${YELLOW}⚠ Could not reach MongoDB warehouse. Continuing anyway.${NC}"
    fi

    # Save local config
    cat > "$CONFIG_FILE" << EOF
{
  "user_id": "$USER_NAME",
  "email": "$USER_EMAIL",
  "team": "$USER_TEAM",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    echo ""
    echo -e "  ${GREEN}Welcome, ${WHITE}${USER_NAME}${GREEN}!${NC}"
    echo -e "  ${CYAN}Configuration saved to${NC} ${WHITE}${CONFIG_FILE}${NC}"
    echo ""
    echo -e "  ${YELLOW}Starting 1-grid Agent...${NC}"
    sleep 1
fi

# ── Load user config ──
USER_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['user_id'])" 2>/dev/null)
if [ -z "$USER_ID" ]; then
    echo -e "  ${RED}Error reading user config. Re-run and set up again.${NC}"
    exit 1
fi

# ── Set environment for opencode ──
export USER_ID
export MONGO_URI
export MONGO_DB

# ── Launch opencode ──
cd "$HOME" || /tmp
echo -e "  ${GREEN}Launching opencode as${NC} ${WHITE}${USER_ID}${NC}${GREEN}...${NC}"
echo ""

exec opencode "$@"
