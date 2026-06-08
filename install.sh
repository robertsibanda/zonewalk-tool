#!/bin/bash
set -e

# =========================================================
# ZONEWALK INSTALLER
# Repo: https://github.com/robertsibanda/zonewalk-tool
# Author: Robert Sibanda
# Portfolio: https://dev-robert.co.za
# Portal:    https://dev-robert.co.za/portal
# =========================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="/usr/local/bin"
OPM_DIR="${HOME}/.config/opencode"
OPM_CONFIG="${OPM_DIR}/opencode.jsonc"
ZONEWALK_BIN="${BIN_DIR}/zonewalk"
ZONEWALK_SCRIPT="${REPO_DIR}/zonewalk.sh"
VERSION_FILE="${REPO_DIR}/version.txt"
REPO_URL="https://raw.githubusercontent.com/robertsibanda/zonewalk-tool/main"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${WHITE}  ZONEWALK INSTALLER${NC}                                         ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}                                                      ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${GREEN}Developed by Robert Sibanda${NC}                          ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Portfolio:${NC} https://dev-robert.co.za                   ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Portal:${NC}    https://dev-robert.co.za/portal            ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ---- Detect OS / Package Manager ----
if command -v apt &>/dev/null; then
    PKG_MGR="apt"
    PKG_INSTALL="apt install -y"
    PKGS=("dnsutils" "whois" "curl" "netcat-openbsd" "openssl" "bind9-host")
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
    PKG_INSTALL="yum install -y"
    PKGS=("bind-utils" "whois" "curl" "nmap-ncat" "openssl" "bind")
elif command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
    PKG_INSTALL="dnf install -y"
    PKGS=("bind-utils" "whois" "curl" "nmap-ncat" "openssl" "bind")
elif command -v pacman &>/dev/null; then
    PKG_MGR="pacman"
    PKG_INSTALL="pacman -S --noconfirm"
    PKGS=("bind" "whois" "curl" "openssl" "inetutils")
elif command -v zypper &>/dev/null; then
    PKG_MGR="zypper"
    PKG_INSTALL="zypper install -y"
    PKGS=("bind-utils" "whois" "curl" "netcat" "openssl")
else
    echo -e "${YELLOW}Package manager not detected — skipping dependency install.${NC}"
    echo -e "${YELLOW}Ensure these are installed manually: dig whois curl nc openssl${NC}"
    PKG_MGR=""
fi

# ---- Step 1: Install dependencies ----
echo -e "${GREEN}[1/5]${NC} Installing dependencies..."
if [ -n "$PKG_MGR" ]; then
    echo -e "  ${INFO}Using ${WHITE}$PKG_MGR${NC}"
    for pkg in "${PKGS[@]}"; do
        if command -v "$pkg" &>/dev/null; then
            # Already installed
            :
        else
            echo -e "  ${YELLOW}Installing $pkg...${NC}"
            $PKG_INSTALL "$pkg" >/dev/null 2>&1 || echo -e "  ${WARN}Failed to install $pkg"
        fi
    done
    echo -e "  ${GREEN}OK${NC} Dependencies installed"
else
    echo -e "  ${WARN}Skipping — install manually: dig whois curl nc openssl"
fi

# ---- Step 2: Install zonewalk script ----
echo -e "${GREEN}[2/5]${NC} Installing zonewalk..."
if [ "$(id -u)" -ne 0 ]; then
    BIN_DIR="${HOME}/.local/bin"
    mkdir -p "$BIN_DIR"
fi
cp "$ZONEWALK_SCRIPT" "$ZONEWALK_BIN" 2>/dev/null || {
    echo -e "  ${YELLOW}Need sudo for system install...${NC}"
    sudo cp "$ZONEWALK_SCRIPT" "$ZONEWALK_BIN"
    sudo chmod +x "$ZONEWALK_BIN"
}
chmod +x "$ZONEWALK_BIN" 2>/dev/null
echo -e "  ${GREEN}OK${NC} Installed to ${WHITE}$ZONEWALK_BIN${NC}"

# Add to PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    SHELL_PROFILE="${HOME}/.bashrc"
    [ -f "${HOME}/.zshrc" ] && SHELL_PROFILE="${HOME}/.zshrc"
    if ! grep -q "export PATH=.*${BIN_DIR}" "$SHELL_PROFILE" 2>/dev/null; then
        echo "export PATH=\"\$PATH:${BIN_DIR}\"" >> "$SHELL_PROFILE"
        echo -e "  ${GREEN}OK${NC} Added ${WHITE}$BIN_DIR${NC} to PATH in ${WHITE}$SHELL_PROFILE${NC}"
    fi
fi

# ---- Step 3: Verify critical tools ----
echo -e "${GREEN}[3/5]${NC} Verifying tools..."
MISSING=()
for tool in dig whois curl nc openssl; do
    command -v "$tool" &>/dev/null \
        && echo -e "  ${GREEN}OK${NC} $tool found" \
        || { echo -e "  ${RED}MISSING${NC} $tool"; MISSING+=("$tool"); }
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}Missing tools: ${MISSING[*]}${NC}"
    echo -e "  ${YELLOW}Install them manually for full functionality${NC}"
fi

# ---- Step 4: Configure opencode (if installed) ----
echo -e "${GREEN}[4/5]${NC} Configuring opencode..."
if command -v opencode &>/dev/null; then
    mkdir -p "$OPM_DIR"
    if [ -f "$OPM_CONFIG" ]; then
        if grep -q "zonewalk" "$OPM_CONFIG" 2>/dev/null; then
            echo -e "  ${GREEN}OK${NC} zonewalk already configured in opencode"
        else
            sed -i '$ d' "$OPM_CONFIG"
            cat >> "$OPM_CONFIG" << EOF
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
            echo -e "  ${GREEN}OK${NC} Added zonewalk tool to opencode config"
        fi
    else
        cat > "$OPM_CONFIG" << EOF
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
        echo -e "  ${GREEN}OK${NC} Created opencode config with zonewalk tool"
    fi
else
    echo -e "  ${YELLOW}opencode not installed — skipping config${NC}"
fi

# ---- Step 5: Set up daily update cron ----
echo -e "${GREEN}[5/5]${NC} Setting up daily update checks..."
UPDATE_SCRIPT="${BIN_DIR}/zonewalk-check-update"
cat > "$UPDATE_SCRIPT" << UEOF
#!/bin/bash
LOCAL_VERSION=\$(cat "${VERSION_FILE}" 2>/dev/null || echo "0")
REMOTE_VERSION=\$(curl -sS --max-time 5 "${REPO_URL}/version.txt" 2>/dev/null | head -1)
if [ -n "\$REMOTE_VERSION" ] && [ "\$REMOTE_VERSION" != "\$LOCAL_VERSION" ]; then
    echo "ZONEWALK update available: v\$LOCAL_VERSION -> v\$REMOTE_VERSION"
    echo "Update: curl -sSL ${REPO_URL}/install.sh | bash"
fi
UEOF
chmod +x "$UPDATE_SCRIPT"

if command -v crontab &>/dev/null; then
    (crontab -l 2>/dev/null | grep -q "zonewalk-check-update") || {
        (crontab -l 2>/dev/null; echo "0 6 * * * ${UPDATE_SCRIPT}") | crontab -
        echo -e "  ${GREEN}OK${NC} Cron job added (daily at 06:00)"
    }
else
    echo -e "  ${YELLOW}crontab not available — skipping scheduled updates${NC}"
fi

# ---- Done ----
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${WHITE}  INSTALLATION COMPLETE${NC}                                      ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${WHITE}Usage:${NC} zonewalk domain.co.za [options]"
echo ""
echo -e "  ${WHITE}Examples:${NC}"
echo "    zonewalk example.co.za"
echo "    zonewalk example.co.za --issue mail-send"
echo "    zonewalk example.co.za --deep --ports"
echo "    zonewalk example.co.za --guide"
echo ""
echo -e "  ${WHITE}Options:${NC}"
echo "    --issue <type>   mail-send | mail-recv | web-down | dns-fail"
echo "    --deep           Subdomain enumeration"
echo "    --ports          Port scan"
echo "    --ip-reputation  Blocklist check"
echo "    --ptr            PTR consistency audit"
echo "    --guide          Fix guide for found issues"
echo "    --headers <file> Email header analysis"
echo ""
echo -e "  ${CYAN}Portfolio:${NC} https://dev-robert.co.za"
echo -e "  ${CYAN}Portal:${NC}    https://dev-robert.co.za/portal"
echo ""

if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo -e "${YELLOW}Run 'source ~/.bashrc' to update your PATH, or log out and back in.${NC}"
    echo ""
fi
