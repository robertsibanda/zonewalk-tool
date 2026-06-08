#!/bin/bash
set -e

# =========================================================
# ZONEWALK INSTALLER
# Repo: https://github.com/robertsibanda/zonewalk-tool
# Author: Robert Sibanda
# Portfolio: https://dev-robert.co.za
# Portal:    https://dev-robert.co.za/portal
# =========================================================

# --- Detect repo location (supports both cloned repo and curl pipe) ---
SCRIPT_SRC="$0"
if echo "$SCRIPT_SRC" | grep -q "install.sh"; then
    REPO_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null || echo "/tmp/zonewalk")"
else
    REPO_DIR="/tmp/zonewalk-install"
    mkdir -p "$REPO_DIR"
    echo -e "\033[1;33mFetching latest zonewalk...\033[0m"
    for f in zonewalk.sh version.txt; do
        curl -sSfL "https://raw.githubusercontent.com/robertsibanda/zonewalk-tool/main/$f" -o "$REPO_DIR/$f" 2>/dev/null || {
            echo -e "\033[0;31mFailed to fetch $f — check internet connection\033[0m"
            exit 1
        }
    done
fi

# --- Colors ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'
OK="${GREEN}OK${NC}"; WARN="${YELLOW}WARN${NC}"; INFO="${CYAN}INFO${NC}"

# --- Paths ---
BIN_DIR="/usr/local/bin"
OPCODE_DIR="${HOME}/.config/opencode"
OPCODE_CONFIG="${OPCODE_DIR}/opencode.jsonc"
ZONEWALK_BIN="${BIN_DIR}/zonewalk"
ZONEWALK_SCRIPT="${REPO_DIR}/zonewalk.sh"
VERSION_FILE="${REPO_DIR}/version.txt"
REPO_URL="https://raw.githubusercontent.com/robertsibanda/zonewalk-tool/main"

# --- Header ---
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${WHITE}  ZONEWALK INSTALLER${NC}                                         ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}                                                      ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${GREEN}Developed by Robert Sibanda${NC}                          ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Portfolio:${NC} https://dev-robert.co.za                   ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Portal:${NC}    https://dev-robert.co.za/portal            ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# --- Self-elevate to root if not already ---
if [ "$(id -u)" -ne 0 ]; then
    echo -e "  ${INFO}Not running as root — re-executing with sudo..."
    exec sudo bash "$0" "$@"
fi

# ==========================================================
# STEP 1: Install system dependencies
# ==========================================================
echo -e "${GREEN}[1/5]${NC} Installing system dependencies..."

# Map commands to packages per distro
declare -A CMD_PKGS=(
    [dig]="dnsutils,bind-utils,bind,bind-utils"
    [whois]="whois,whois,whois,whois"
    [curl]="curl,curl,curl,curl"
    [nc]="netcat-openbsd,nmap-ncat,nmap-ncat,inetutils"
    [openssl]="openssl,openssl,openssl,openssl"
)

detect_pkg_mgr() {
    if command -v apt &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v yum &>/dev/null; then echo "yum"
    elif command -v pacman &>/dev/null; then echo "pacman"
    elif command -v zypper &>/dev/null; then echo "zypper"
    else echo "unknown"
    fi
}

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

for cmd in dig whois curl nc openssl; do
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${OK} $cmd already installed"
    else
        echo -e "  ${WARN} $cmd not found — installing..."
        if [ "$PKG_MGR" != "unknown" ]; then
            install_pkg "$cmd" "$PKG_MGR" && echo -e "  ${OK} $cmd installed" \
                || echo -e "  ${RED} Failed to install $cmd — try manually${NC}"
        else
            echo -e "  ${RED} No package manager detected — install $cmd manually${NC}"
        fi
    fi
done

# ==========================================================
# STEP 2: Install zonewalk script
# ==========================================================
echo -e "${GREEN}[2/5]${NC} Installing zonewalk..."
cp "$ZONEWALK_SCRIPT" "$ZONEWALK_BIN"
chmod +x "$ZONEWALK_BIN"
echo -e "  ${OK} Installed to ${WHITE}$ZONEWALK_BIN${NC}"

# ==========================================================
# STEP 3: Install & configure opencode
# ==========================================================
echo -e "${GREEN}[3/5]${NC} Setting up opencode..."

install_opencode() {
    echo -e "  ${INFO}Installing opencode..."
    if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/opencode 2>/dev/null && return 0
        npm install -g opencode 2>/dev/null && return 0
    fi
    # Fallback: direct install script
    curl -sSf https://opencode.ai/install.sh 2>/dev/null | bash >/dev/null 2>&1 && return 0
    echo -e "  ${WARN}Automatic install failed — install opencode manually from https://opencode.ai"
    return 1
}

if command -v opencode &>/dev/null; then
    echo -e "  ${OK} opencode already installed: $(opencode --version 2>/dev/null || echo 'present')"
else
    install_opencode
fi

# Add zonewalk as a tool in opencode config
mkdir -p "$OPCODE_DIR"
if [ -f "$OPCODE_CONFIG" ]; then
    if grep -q "zonewalk" "$OPCODE_CONFIG" 2>/dev/null; then
        echo -e "  ${OK} zonewalk already configured in opencode"
    else
        sed -i '$ d' "$OPCODE_CONFIG"
        cat >> "$OPCODE_CONFIG" << EOF
,
  "tools": {
    "zonewalk": {
      "description": "DNS & mail diagnostics tool. Usage: zonewalk <domain> [options]",
      "command": "${ZONEWALK_BIN}",
      "args": ["\$domain"]
    }
  }
}
EOF
        echo -e "  ${OK} Added zonewalk tool to opencode config"
    fi
else
    cat > "$OPCODE_CONFIG" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "tools": {
    "zonewalk": {
      "description": "DNS & mail diagnostics tool. Usage: zonewalk <domain> [options]",
      "command": "${ZONEWALK_BIN}",
      "args": ["\$domain"]
    }
  }
}
EOF
    echo -e "  ${OK} Created opencode config with zonewalk tool"
fi

# ==========================================================
# STEP 4: Set up daily update cron
# ==========================================================
echo -e "${GREEN}[4/5]${NC} Setting up daily update checks..."

UPDATE_SCRIPT="/usr/local/bin/zonewalk-check-update"
cat > "$UPDATE_SCRIPT" << 'UEOF'
#!/bin/bash
REPO_URL="https://raw.githubusercontent.com/robertsibanda/zonewalk-tool/main"
LOCAL_VERSION=$(cat /usr/local/share/zonewalk/version.txt 2>/dev/null || echo "0")
REMOTE_VERSION=$(curl -sS --max-time 5 "${REPO_URL}/version.txt" 2>/dev/null | head -1)
if [ -n "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
    echo "ZONEWALK update available: v${LOCAL_VERSION} -> v${REMOTE_VERSION}"
    echo "Update: curl -sSL ${REPO_URL}/install.sh | sudo bash"
fi
UEOF
chmod +x "$UPDATE_SCRIPT"

mkdir -p /usr/local/share/zonewalk
cp "$VERSION_FILE" /usr/local/share/zonewalk/version.txt

if command -v crontab &>/dev/null; then
    (crontab -l 2>/dev/null | grep -q "zonewalk-check-update") || {
        (crontab -l 2>/dev/null; echo "0 6 * * * ${UPDATE_SCRIPT}") | crontab -
        echo -e "  ${OK} Cron job added (daily at 06:00)"
    }
fi

# ==========================================================
# STEP 5: Verify installation
# ==========================================================
echo -e "${GREEN}[5/5]${NC} Verifying installation..."
PASS=true
for tool in dig whois curl nc openssl; do
    command -v "$tool" &>/dev/null && echo -e "  ${OK} $tool" || { echo -e "  ${RED} MISSING $tool${NC}"; PASS=false; }
done
if [ -x "$ZONEWALK_BIN" ]; then
    echo -e "  ${OK} zonewalk"
else
    echo -e "  ${RED} zonewalk not installed${NC}"
    PASS=false
fi

# ==========================================================
# DONE
# ==========================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${WHITE}  INSTALLATION COMPLETE${NC}                                      ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${WHITE}Now run:${NC}"
echo "    zonewalk domain.co.za"
echo ""
echo -e "  ${WHITE}Examples:${NC}"
echo "    zonewalk example.co.za"
echo "    zonewalk example.co.za --issue mail-send"
echo "    zonewalk example.co.za --deep --ports"
echo "    zonewalk example.co.za --guide"
echo ""
echo -e "  ${CYAN}Portfolio:${NC} https://dev-robert.co.za"
echo -e "  ${CYAN}Portal:${NC}    https://dev-robert.co.za/portal"
echo ""
