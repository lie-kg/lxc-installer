#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================================
#   LXC + LXD AUTO INSTALLER (VPS SAFE FIXED)
#   Kali / Ubuntu / Debian compatible
#   Author: lie_kg
# =========================================================

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

# ---------------- COLORS ----------------

RESET="\033[0m"
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
CYAN="\033[36m"
BLUE="\033[34m"
MAGENTA="\033[35m"

OK="[OK]"
FAIL="[FAIL]"
INFO="[INFO]"
WARN="[WARN]"

INSTALL_LOG="/tmp/lxd_installer.log"

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

# ---------------- LOG ----------------

init_log() {
    echo "=== LXD INSTALL LOG ===" > "$INSTALL_LOG"
    echo "Started: $(date)" >> "$INSTALL_LOG"
}

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$INSTALL_LOG"
}

# ---------------- HEADER ----------------

show_header() {
    clear
    echo -e "${BLUE}"
cat << "EOF"
██╗      ██╗  ██╗ ██████╗  ██╗███╗   ██╗███████╗
██║      ╚██╗██╔╝██╔════╝  ██║████╗  ██║██╔════╝
██║       ╚███╔╝ ██║       ██║██╔██╗ ██║███████╗
██║       ██╔██╗ ██║       ██║██║╚██╗██║╚════██║
███████╗ ██╔╝ ██╗╚██████╗  ██║██║ ╚████║███████║
╚══════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═╝╚═╝  ╚═══╝╚══════╝
EOF
    echo -e "${RESET}"
    echo -e "${MAGENTA}AUTO LXC + LXD INSTALLER${RESET}"
    echo -e "${CYAN}Made by lie_kg${RESET}"
    echo
}

# ---------------- OS DETECT ----------------

detect_os() {

    . /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"

    case "$OS_ID" in
        ubuntu|debian|kali)
            echo -e "${GREEN}${OK} OS: $OS_ID $OS_VERSION${RESET}"
            ;;
        *)
            echo -e "${YELLOW}${WARN} Unknown OS: $OS_ID (continuing)${RESET}"
            ;;
    esac

    virt=$(systemd-detect-virt 2>/dev/null || echo "none")
    echo -e "${CYAN}${INFO} Virtualization: $virt${RESET}"
    echo
}

# ---------------- SYSTEM INFO ----------------

system_info() {

    echo -e "${CYAN}SYSTEM INFO${RESET}"
    echo "Kernel: $(uname -r)"
    echo "Arch: $(uname -m)"

    mem=$(free -h 2>/dev/null | awk '/Mem:/ {print $2}' || echo "unknown")
    echo "RAM: $mem"

    disk=$(df -h / | awk 'NR==2 {print $4}')
    echo "Disk: $disk"
    echo
}

# ---------------- INSTALL ----------------

install_packages() {

    echo -e "${CYAN}${INFO} Installing packages...${RESET}"

    $SUDO apt update -y >> "$INSTALL_LOG" 2>&1

    $SUDO apt install -y \
        lxc snapd curl wget uidmap bridge-utils squashfs-tools \
        ca-certificates locales software-properties-common \
        iptables jq nano procps locales-all >> "$INSTALL_LOG" 2>&1

    $SUDO locale-gen en_US.UTF-8 >> "$INSTALL_LOG" 2>&1
}

# ---------------- LXD ----------------

install_lxd() {

    echo -e "${CYAN}${INFO} Installing LXD...${RESET}"

    $SUDO systemctl enable --now snapd >> "$INSTALL_LOG" 2>&1
    $SUDO systemctl restart snapd >> "$INSTALL_LOG" 2>&1

    sleep 3

    $SUDO snap install lxd --channel=latest/stable >> "$INSTALL_LOG" 2>&1

    $SUDO lxd init --auto >> "$INSTALL_LOG" 2>&1
}

# ---------------- USER ----------------

configure_user() {

    user="${SUDO_USER:-$(whoami)}"

    if ! groups "$user" | grep -q lxd; then
        $SUDO usermod -aG lxd "$user"
    fi
}

# ---------------- VALIDATE ----------------

validate() {

    echo -e "${CYAN}${INFO} Validating...${RESET}"

    $SUDO lxc info >> "$INSTALL_LOG" 2>&1
    $SUDO lxc list >> "$INSTALL_LOG" 2>&1
}

# ---------------- MAIN ----------------

main() {

    init_log
    show_header
    detect_os
    system_info
    install_packages
    install_lxd
    configure_user
    validate

    echo -e "${GREEN}${OK} INSTALL COMPLETE${RESET}"
    echo "Run: newgrp lxd"
}

trap 'echo -e "${RED}${FAIL} ERROR at line $LINENO${RESET}"' ERR

main
