#!/bin/bash
set -e

# =========================================================
# 1-GRID AGENT TOOLKIT INSTALLER
# Repo: https://github.com/robertsibanda/zonewalk-tool
# =========================================================

# --- Detect repo location ---
SCRIPT_SRC="$0"
if echo "$SCRIPT_SRC" | grep -q "install.sh"; then
    REPO_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null || echo "/tmp/1grid-agent")"
else
    REPO_DIR="/tmp/1grid-agent-install"
    mkdir -p "$REPO_DIR"
    echo -e "\033[1;33mFetching latest 1-grid Agent Toolkit...\033[0m"
    BASE="https://raw.githubusercontent.com/robertsibanda/zonewalk-tool/main"
    for f in zonewalk.sh version.txt scripts/warehouse-query.py opencode-agent.jsonc warehouse/*.json; do
        mkdir -p "$(dirname "$REPO_DIR/$f")"
        curl -sSfL "$BASE/$f" -o "$REPO_DIR/$f" 2>/dev/null || true
    done
fi

# --- Colors ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'
OK="${GREEN}OK${NC}"; WARN="${YELLOW}WARN${NC}"; INFO="${CYAN}INFO${NC}"

# --- Header ---
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${WHITE}  1-GRID AGENT TOOLKIT INSTALLER${NC}                            ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}                                                      ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${GREEN}DNS diagnostics + Warehouse + Opencode${NC}                ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Portfolio:${NC} https://dev-robert.co.za                   ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Portal:${NC}    https://dev-robert.co.za/portal            ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# --- Self-elevate ---
if [ "$(id -u)" -ne 0 ]; then
    echo -e "  ${INFO}Not running as root — re-executing with sudo..."
    exec sudo bash "$0" "$@"
fi

# ---- Detect OS ----
detect_pkg_mgr() {
    if command -v apt &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v yum &>/dev/null; then echo "yum"
    elif command -v pacman &>/dev/null; then echo "pacman"
    elif command -v zypper &>/dev/null; then echo "zypper"
    else echo "unknown"
    fi
}

declare -A CMD_PKGS=(
    [dig]="dnsutils,bind-utils,bind,bind-utils"
    [whois]="whois,whois,whois,whois"
    [curl]="curl,curl,curl,curl"
    [nc]="netcat-openbsd,nmap-ncat,nmap-ncat,inetutils"
    [openssl]="openssl,openssl,openssl,openssl"
    [python3]="python3,python3,python3,python3"
)

install_pkg() {
    local cmd="$1" mgr="$2"
    local pkgs="${CMD_PKGS[$cmd]}"
    local pkg_list=(); IFS=',' read -ra pkg_list <<< "$pkgs"
    local pkg_idx=0
    case "$mgr" in
        apt) pkg_idx=0 ;;
        dnf|yum) pkg_idx=1 ;;
        pacman) pkg_idx=2 ;;
        zypper) pkg_idx=3 ;;
        *) return 1 ;;
    esac
    local pkg="${pkg_list[$pkg_idx]}"
    [ -z "$pkg" ] && return 1
    case "$mgr" in
        apt) apt install -y "$pkg" >/dev/null 2>&1 ;;
        dnf) dnf install -y "$pkg" >/dev/null 2>&1 ;;
        yum) yum install -y "$pkg" >/dev/null 2>&1 ;;
        pacman) pacman -S --noconfirm "$pkg" >/dev/null 2>&1 ;;
        zypper) zypper install -y "$pkg" >/dev/null 2>&1 ;;
    esac
    return $?
}

PKG_MGR=$(detect_pkg_mgr)
echo -e "  ${INFO}Package manager: ${WHITE}${PKG_MGR}${NC}"

# ==========================================================
# STEP 1: Install system dependencies
# ==========================================================
echo -e "${GREEN}[1/6]${NC} Installing system dependencies..."

for cmd in dig whois curl nc openssl python3; do
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${OK} $cmd already installed"
    else
        echo -e "  ${WARN} $cmd not found — installing..."
        if [ "$PKG_MGR" != "unknown" ]; then
            install_pkg "$cmd" "$PKG_MGR" && echo -e "  ${OK} $cmd installed" \
                || echo -e "  ${RED} Failed to install $cmd — try manually${NC}"
        else
            echo -e "  ${RED} No package manager — install $cmd manually${NC}"
        fi
    fi
done

# Install pymongo for warehouse CLI
python3 -c "import pymongo" 2>/dev/null || {
    echo -e "  ${WARN}Installing pymongo..."
    pip3 install pymongo >/dev/null 2>&1 && echo -e "  ${OK} pymongo installed" \
        || echo -e "  ${WARN}pymongo install failed — warehouse CLI may not work"
}

# ==========================================================
# STEP 2: Install zonewalk script
# ==========================================================
echo -e "${GREEN}[2/6]${NC} Installing zonewalk..."
cp "$REPO_DIR/zonewalk.sh" /usr/local/bin/zonewalk
chmod +x /usr/local/bin/zonewalk
echo -e "  ${OK} Installed to ${WHITE}/usr/local/bin/zonewalk${NC}"

# ==========================================================
# STEP 3: Install warehouse CLI
# ==========================================================
echo -e "${GREEN}[3/6]${NC} Installing warehouse CLI..."
mkdir -p /usr/local/share/1grid-agent
if [ -f "$REPO_DIR/scripts/warehouse-query.py" ]; then
    cp "$REPO_DIR/scripts/warehouse-query.py" /usr/local/bin/warehouse-query
    chmod +x /usr/local/bin/warehouse-query
    echo -e "  ${OK} Installed to ${WHITE}/usr/local/bin/warehouse-query${NC}"
else
    echo -e "  ${WARN}warehouse-query.py not found — skipping"
fi

# Copy warehouse data for offline reference
if [ -d "$REPO_DIR/warehouse" ]; then
    cp -r "$REPO_DIR/warehouse" /usr/local/share/1grid-agent/warehouse
    echo -e "  ${OK} Warehouse data copied to ${WHITE}/usr/local/share/1grid-agent/warehouse/${NC}"
fi

# Copy opencode agent config template
if [ -f "$REPO_DIR/opencode-agent.jsonc" ]; then
    cp "$REPO_DIR/opencode-agent.jsonc" /usr/local/share/1grid-agent/opencode-agent.jsonc
    echo -e "  ${OK} Agent config template copied${NC}"
fi

# ==========================================================
# STEP 4: Install & configure opencode
# ==========================================================
echo -e "${GREEN}[4/6]${NC} Setting up opencode..."

install_opencode() {
    echo -e "  ${INFO}Installing opencode..."
    if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/opencode 2>/dev/null && return 0
        npm install -g opencode 2>/dev/null && return 0
    fi
    curl -sSf https://opencode.ai/install.sh 2>/dev/null | bash >/dev/null 2>&1 && return 0
    echo -e "  ${WARN}Automatic install failed — install opencode manually from https://opencode.ai"
    return 1
}

if command -v opencode &>/dev/null; then
    echo -e "  ${OK} opencode already installed: $(opencode --version 2>/dev/null || echo 'present')"
else
    install_opencode
fi

OPCODE_DIR="${HOME}/.config/opencode"
OPCODE_CONFIG="${OPCODE_DIR}/opencode.jsonc"
mkdir -p "$OPCODE_DIR"

# Use the distributed agent config as opencode config
if [ -f "$OPCODE_CONFIG" ]; then
    echo -e "  ${INFO}Existing opencode config found — merging zonewalk + warehouse tools..."
    # Simple merge: add tools section if not present
    if grep -q "warehouse-query" "$OPCODE_CONFIG" 2>/dev/null; then
        echo -e "  ${OK} Warehouse tools already configured"
    else
        # Backup existing
        cp "$OPCODE_CONFIG" "$OPCODE_CONFIG.bak"
        # Write the full agent config
        cp "/usr/local/share/1grid-agent/opencode-agent.jsonc" "$OPCODE_CONFIG"
        echo -e "  ${OK} Config updated (backup at ${OPCODE_CONFIG}.bak)"
    fi
else
    cp "/usr/local/share/1grid-agent/opencode-agent.jsonc" "$OPCODE_CONFIG"
    echo -e "  ${OK} Created opencode config with zonewalk + warehouse tools"
fi

# ==========================================================
# STEP 5: Register user & configure environment
# ==========================================================
echo -e "${GREEN}[5/6]${NC} Configuring multi-user environment..."

# Detect or prompt for user identity
CURRENT_USER="${SUDO_USER:-$USER}"
USER_ID="${CURRENT_USER:-agent}"
TEAM_NAME="L1 Support"

echo -e "  ${INFO}Registering user: ${WHITE}${USER_ID}${NC}"

# Try to register in MongoDB (silent fail if MongoDB unavailable)
MONGO_URI="${MONGO_URI:-mongodb://localhost:27017}"
MONGO_DB="${MONGO_DB:-support_ai}"
if python3 -c "from pymongo import MongoClient; MongoClient('${MONGO_URI}').server_info()" 2>/dev/null; then
    warehouse-query register-user --id "$USER_ID" --name "$CURRENT_USER" --team "$TEAM_NAME" 2>/dev/null || true
    echo -e "  ${OK} Registered in MongoDB warehouse"
else
    echo -e "  ${WARN}MongoDB not reachable at ${MONGO_URI} — user registration skipped"
    echo -e "  ${INFO}Set MONGO_URI env var or start MongoDB, then run: warehouse-query register-user --id ${USER_ID}"
fi

# Add env vars to shell profile
SHELL_PROFILE="${HOME}/.bashrc"
[ -f "${HOME}/.zshrc" ] && SHELL_PROFILE="${HOME}/.zshrc"

if ! grep -q "export USER_ID=" "$SHELL_PROFILE" 2>/dev/null; then
    cat >> "$SHELL_PROFILE" << EOF

# 1-grid Agent Toolkit
export USER_ID="${USER_ID}"
export MONGO_URI="${MONGO_URI}"
export MONGO_DB="${MONGO_DB}"
EOF
    echo -e "  ${OK} Environment vars added to ${WHITE}${SHELL_PROFILE}${NC}"
fi

# ==========================================================
# STEP 6: Set up daily update cron & verify
# ==========================================================
echo -e "${GREEN}[6/6]${NC} Finalizing..."

# Update check script
cat > /usr/local/bin/zonewalk-check-update << 'UEOF'
#!/bin/bash
REPO_URL="https://raw.githubusercontent.com/robertsibanda/zonewalk-tool/main"
LOCAL_VERSION=$(cat /usr/local/share/zonewalk/version.txt 2>/dev/null || echo "0")
REMOTE_VERSION=$(curl -sS --max-time 5 "${REPO_URL}/version.txt" 2>/dev/null | head -1)
if [ -n "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
    echo "1-grid Agent Toolkit update available: v${LOCAL_VERSION} -> v${REMOTE_VERSION}"
    echo "Update: curl -sSL ${REPO_URL}/install.sh | sudo bash"
fi
UEOF
chmod +x /usr/local/bin/zonewalk-check-update

# Version tracking
mkdir -p /usr/local/share/zonewalk
[ -f "$REPO_DIR/version.txt" ] && cp "$REPO_DIR/version.txt" /usr/local/share/zonewalk/version.txt

# Cron
if command -v crontab &>/dev/null; then
    (crontab -l 2>/dev/null | grep -q "zonewalk-check-update") || {
        (crontab -l 2>/dev/null; echo "0 6 * * * /usr/local/bin/zonewalk-check-update") | crontab -
        echo -e "  ${OK} Daily update check added (06:00)"
    }
fi

# Verify
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${WHITE}  INSTALLATION COMPLETE${NC}                                      ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${WHITE}Tools installed:${NC}"
echo -e "    ${CYAN}zonewalk${NC}         DNS & mail diagnostics"
echo -e "    ${CYAN}warehouse-query${NC}  Ticket/conversation warehouse (MongoDB)"
echo ""
echo -e "  ${WHITE}Opencode tools:${NC}"
echo -e "    zonewalk              Run DNS diagnostics"
echo -e "    warehouse-search      Search warehouse"
echo -e "    warehouse-tickets     List recent tickets"
echo -e "    warehouse-my-convs    My conversations"
echo -e "    warehouse-my-tickets  My tickets"
echo ""
echo -e "  ${WHITE}Usage:${NC}"
echo -e "    zonewalk domain.co.za"
echo -e "    warehouse-query search domain.co.za"
echo -e "    warehouse-query my-convs --limit 10"
echo ""
echo -e "  ${WHITE}Multi-user:${NC}"
echo -e "    export USER_ID=alice    # set your identity"
echo -e "    warehouse-query register-user --id alice --name Alice --team \"L1 Support\""
echo ""
echo -e "  ${CYAN}Portfolio:${NC} https://dev-robert.co.za"
echo -e "  ${CYAN}Portal:${NC}    https://dev-robert.co.za/portal"
echo ""
