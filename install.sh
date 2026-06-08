#!/bin/bash

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
    rm -rf "$REPO_DIR"
    echo -e "\033[1;33mDownloading 1-grid Agent Toolkit...\033[0m"
    TARBALL="https://github.com/robertsibanda/zonewalk-tool/archive/master.tar.gz"
    curl -sSL "$TARBALL" | tar xz -C /tmp 2>/dev/null || {
        echo -e "\033[0;31mFailed to download from $TARBALL\033[0m"
        echo -e "\033[1;33mTrying individual files as fallback...\033[0m"
        mkdir -p "$REPO_DIR"
        BASE="https://raw.githubusercontent.com/robertsibanda/zonewalk-tool/master"
        for f in zonewalk.sh version.txt scripts/warehouse-query.py opencode-agent.jsonc; do
            mkdir -p "$(dirname "$REPO_DIR/$f")"
            curl -sSfL "$BASE/$f" -o "$REPO_DIR/$f" || echo -e "  \033[0;31mFailed: $f\033[0m"
        done
    }
    # If tarball worked, the dir is named zonewalk-tool-master
    [ -d "/tmp/zonewalk-tool-master" ] && REPO_DIR="/tmp/zonewalk-tool-master"
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
    (apt install -y python3-pymongo 2>/dev/null || \
     pip3 install pymongo --break-system-packages 2>/dev/null || \
     pip3 install pymongo 2>/dev/null) && echo -e "  ${OK} pymongo installed" \
        || echo -e "  ${WARN}pymongo install failed — warehouse CLI may not work"
}

# ==========================================================
# STEP 2: Install zonewalk script
# ==========================================================
echo -e "${GREEN}[2/6]${NC} Installing zonewalk..."
if [ -f "$REPO_DIR/zonewalk.sh" ]; then
    cp "$REPO_DIR/zonewalk.sh" /usr/local/bin/zonewalk
    chmod +x /usr/local/bin/zonewalk
    echo -e "  ${OK} Installed to ${WHITE}/usr/local/bin/zonewalk${NC}"
else
    echo -e "  ${RED}zonewalk.sh not found — skipping${NC}"
fi

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

# Copy instructions file
if [ -f "$REPO_DIR/instructions/1grid-agent.md" ]; then
    cp "$REPO_DIR/instructions/1grid-agent.md" /usr/local/share/1grid-agent/instructions.md
    echo -e "  ${OK} Instructions file copied${NC}"
fi

# Install the 1grid-agent wrapper
if [ -f "$REPO_DIR/scripts/1grid-agent.sh" ]; then
    cp "$REPO_DIR/scripts/1grid-agent.sh" /usr/local/bin/1grid-agent
    chmod +x /usr/local/bin/1grid-agent
    echo -e "  ${OK} Installed ${WHITE}/usr/local/bin/1grid-agent${NC}"
fi

# ==========================================================
# STEP 4: Install & configure opencode
# ==========================================================
echo -e "${GREEN}[4/6]${NC} Installing opencode..."

install_opencode() {
    echo -e "  ${INFO}Installing opencode via npm..."
    if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/opencode 2>&1 | tail -3 || true
        if command -v opencode &>/dev/null; then
            echo -e "  ${OK} opencode installed via npm"
            return 0
        fi
        npm install -g opencode 2>&1 | tail -3 || true
        if command -v opencode &>/dev/null; then
            echo -e "  ${OK} opencode installed via npm (fallback)"
            return 0
        fi
    fi
    echo -e "  ${INFO}Trying opencode.ai install script..."
    curl -sSL https://opencode.ai/install 2>/dev/null | bash 2>&1 | tail -5 || true
    if command -v opencode &>/dev/null; then
        echo -e "  ${OK} opencode installed via script"
        return 0
    fi
    echo -e "  ${INFO}Trying direct GitHub release..."
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    [ "$ARCH" = "x86_64" ] && ARCH="x64"
    [ "$ARCH" = "aarch64" ] && ARCH="arm64"
    [ "$ARCH" = "armv7l" ] && ARCH="arm"
    [ "$OS" = "darwin" ] && OS="darwin"
    GZIP="opencode-${OS}-${ARCH}.tar.gz"
    URL="https://github.com/anomalyco/opencode/releases/latest/download/${GZIP}"
    mkdir -p /tmp/opencode-install
    curl -sSL "$URL" -o "/tmp/opencode-install/$GZIP" 2>/dev/null && {
        tar xzf "/tmp/opencode-install/$GZIP" -C /tmp/opencode-install 2>/dev/null
        cp /tmp/opencode-install/opencode /usr/local/bin/opencode 2>/dev/null
        chmod +x /usr/local/bin/opencode 2>/dev/null
        rm -rf /tmp/opencode-install
        if command -v opencode &>/dev/null; then
            echo -e "  ${OK} opencode installed from GitHub release"
            return 0
        fi
    }
    echo -e "  ${INFO}Trying .deb package..."
    DEB="opencode-desktop-linux-amd64.deb"
    DEB_URL="https://github.com/anomalyco/opencode/releases/latest/download/${DEB}"
    curl -sSL "$DEB_URL" -o "/tmp/opencode-install/$DEB" 2>/dev/null && {
        dpkg -i "/tmp/opencode-install/$DEB" 2>/dev/null && {
            rm -rf /tmp/opencode-install
            if command -v opencode &>/dev/null; then
                echo -e "  ${OK} opencode installed from .deb"
                return 0
            fi
        }
    }
    rm -rf /tmp/opencode-install
    echo -e "  ${YELLOW}⚠ opencode install failed. Install manually:${NC}"
    echo -e "     curl -sSL https://opencode.ai/install | bash"
}

if command -v opencode &>/dev/null; then
    echo -e "  ${OK} opencode already installed: $(opencode --version 2>/dev/null | head -1)"
else
    install_opencode
fi

# Configure opencode
OPCODE_DIR="${HOME}/.config/opencode"
OPCODE_CONFIG="${OPCODE_DIR}/opencode.jsonc"
INSTRUCTIONS_DIR="${OPCODE_DIR}/instructions"
mkdir -p "$OPCODE_DIR" "$INSTRUCTIONS_DIR"

# Install instructions file
if [ -f "/usr/local/share/1grid-agent/instructions.md" ]; then
    cp "/usr/local/share/1grid-agent/instructions.md" "$INSTRUCTIONS_DIR/1grid-agent.md"
    echo -e "  ${OK} Instructions installed to ${WHITE}${INSTRUCTIONS_DIR}/1grid-agent.md${NC}"
fi

# Install opencode config
INSTRUCTIONS_PATH="${HOME}/.config/opencode/instructions/1grid-agent.md"
if [ -f "$OPCODE_CONFIG" ]; then
    if grep -q "warehouse-query" "$OPCODE_CONFIG" 2>/dev/null; then
        echo -e "  ${OK} Warehouse tools already configured in opencode"
    else
        cp "$OPCODE_CONFIG" "$OPCODE_CONFIG.bak"
        sed "s|__INSTRUCTIONS_PATH__|${INSTRUCTIONS_PATH}|g" \
            "/usr/local/share/1grid-agent/opencode-agent.jsonc" > "$OPCODE_CONFIG"
        echo -e "  ${OK} Config updated (backup at ${OPCODE_CONFIG}.bak)"
    fi
else
    sed "s|__INSTRUCTIONS_PATH__|${INSTRUCTIONS_PATH}|g" \
        "/usr/local/share/1grid-agent/opencode-agent.jsonc" > "$OPCODE_CONFIG"
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
MONGO_URI="${MONGO_URI:-mongodb://support_admin:claire6772147@41.61.20.67:27017/admin}"
MONGO_DB="${MONGO_DB:-support_ai}"
if ! python3 -c "import pymongo" 2>/dev/null; then
    echo -e "  ${WARN}pymongo not installed — can't check MongoDB. Run: pip3 install pymongo --break-system-packages"
elif python3 -c "from pymongo import MongoClient; MongoClient('${MONGO_URI}').server_info()" 2>/dev/null; then
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
REPO_URL="https://raw.githubusercontent.com/robertsibanda/zonewalk-tool/master"
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

# Copy startup prompt
if [ -f "$REPO_DIR/prompts/opencode-startup.md" ]; then
    cp "$REPO_DIR/prompts/opencode-startup.md" /usr/local/share/1grid-agent/opencode-startup.md
    echo -e "  ${OK} Startup prompt copied${NC}"
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
echo -e "    1grid-agent              # Start opencode with warehouse integration"
echo -e "    1grid-agent run \"check domain.co.za\"  # Run a single query"
echo -e ""
echo -e "    zonewalk domain.co.za     # Direct DNS diagnostics"
echo -e "    warehouse-query search x  # Direct warehouse search"
echo ""
echo -e "  ${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "  ${YELLOW}║${WHITE}  NEXT STEP: Paste this prompt into opencode${NC}                ${YELLOW}║${NC}"
echo -e "  ${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Run the following to get your startup prompt:"
echo -e "  ${CYAN}cat /usr/local/share/1grid-agent/opencode-startup.md${NC}"
echo ""
echo -e "  Edit the prompt file to replace ${WHITE}[YOUR_NAME]${NC} with your name,"
echo -e "  then paste the entire contents into opencode's first message."
echo ""
echo -e "  ${WHITE}Quick start:${NC}"
echo -e "    nano /usr/local/share/1grid-agent/opencode-startup.md   # set your name"
echo -e "    1grid-agent                                             # start opencode"
echo ""

# Show the prompt inline
if [ -f "/usr/local/share/1grid-agent/opencode-startup.md" ]; then
    echo -e "  ${CYAN}────────────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}STARTUP PROMPT (edit [YOUR_NAME] first)${NC}"
    echo -e "  ${CYAN}────────────────────────────────────────────────────${NC}"
    cat /usr/local/share/1grid-agent/opencode-startup.md
    echo ""
    echo -e "  ${CYAN}────────────────────────────────────────────────────${NC}"
fi
echo ""
echo -e "  ${CYAN}Portfolio:${NC} https://dev-robert.co.za"
echo -e "  ${CYAN}Portal:${NC}    https://dev-robert.co.za/portal"
echo ""
