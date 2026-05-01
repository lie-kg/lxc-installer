#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================================
#   LXC + LXD AUTO INSTALLER (FIXED VERSION)
#   Ubuntu / Debian (NEW SNAP METHOD)
#   Author: lie_kg
# =========================================================

RESET="\033[0m"
BOLD="\033[1m"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
MAGENTA="\033[35m"

LOG_FILE="/tmp/lxd-installer.log"

# ---------------- ROOT CHECK ----------------

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

# ---------------- HEADER ----------------

show_header() {

    clear
    echo -e "${CYAN}${BOLD}"

    cat << "EOF"

██╗     ██╗  ██╗ ██████╗  ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗
██║     ╚██╗██╔╝██╔════╝  ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗
██║      ╚███╔╝ ██║       ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝
██║      ██╔██╗ ██║       ██║██║╚██╗██║╚════██║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
███████╗██╔╝ ██╗╚██████╗  ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
╚══════╝╚═╝  ╚═╝ ╚═════╝  ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝

EOF

    echo -e "${RESET}"

    echo -e "${MAGENTA}${BOLD}🚀 LXC + LXD AUTO INSTALLER (FIXED SNAP VERSION)${RESET}"
    echo -e "${BLUE}Powered by lie_kg${RESET}"
    echo
}

# ---------------- LOG ----------------

log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

# ---------------- INTERNET CHECK (FIXED) ----------------

check_internet() {

    echo -e "${CYAN}Checking internet connection...${RESET}"

    if curl -fsSL https://google.com >/dev/null 2>&1 || \
       curl -fsSL https://1.1.1.1 >/dev/null 2>&1; then

        echo -e "${GREEN}✔ Internet OK${RESET}"
    else
        echo -e "${RED}❌ No internet connection${RESET}"
        exit 1
    fi

    echo
}

# ---------------- OS CHECK ----------------

check_os() {

    . /etc/os-release

    case "$ID" in
        ubuntu|debian)
            echo -e "${GREEN}✔ Supported OS: $PRETTY_NAME${RESET}\n"
            ;;
        *)
            echo -e "${RED}Unsupported OS${RESET}"
            exit 1
            ;;
    esac
}

# ---------------- INSTALL (FIXED) ----------------

install_packages() {

    echo -e "${YELLOW}Installing base packages...${RESET}"

    $SUDO apt update -y

    $SUDO apt install -y \
        lxc \
        uidmap \
        bridge-utils \
        curl \
        wget \
        ca-certificates \
        snapd

    echo -e "${CYAN}Installing LXD via SNAP (FIXED METHOD)...${RESET}"

    $SUDO snap install lxd --channel=latest/stable
}

# ---------------- ENABLE ----------------

enable_lxd() {
    $SUDO systemctl enable --now snap.lxd.daemon || true
}

# ---------------- USER ----------------

configure_user() {

    USERNAME="${SUDO_USER:-$USER}"

    $SUDO usermod -aG lxd "$USERNAME"
}

# ---------------- INIT ----------------

init_lxd() {

    echo -e "${CYAN}Initializing LXD...${RESET}"

    $SUDO lxd init --auto || true
}

# ---------------- TEST ----------------

test_lxd() {

    $SUDO lxc info || true
    $SUDO lxc list || true
}

# ---------------- MAIN ----------------

main() {

    touch "$LOG_FILE"

    show_header

    log "start"

    check_internet
    check_os
    install_packages
    enable_lxd
    configure_user
    init_lxd
    test_lxd

    echo -e "${GREEN}${BOLD}✔ INSTALL COMPLETE${RESET}"
    echo "Run: newgrp lxd or reboot"
}

main "$@"
