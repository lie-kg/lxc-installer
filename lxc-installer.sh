#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================================
#   LXC + LXD AUTO INSTALLER
#   Ubuntu / Debian
#   Author: lie_kg
# =========================================================

# ---------------- COLORS ----------------

RESET="\033[0m"
BOLD="\033[1m"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[97m"

# ---------------- CONFIG ----------------

LOG_FILE="/tmp/lxd-installer.log"

# ---------------- ROOT CHECK ----------------

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ---------------- HEADER ----------------

show_header() {

    clear

    printf "${CYAN}${BOLD}"

    cat << "EOF"

██╗     ██╗  ██╗ ██████╗
██║     ╚██╗██╔╝██╔════╝
██║      ╚███╔╝ ██║
██║      ██╔██╗ ██║
███████╗██╔╝ ██╗╚██████╗
╚══════╝╚═╝  ╚═╝ ╚═════╝

██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗
██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗
██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝
██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗
██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝

EOF

    printf "${RESET}"

    echo
    printf "${MAGENTA}${BOLD}🚀 LXC + LXD AUTO INSTALLER${RESET}\n"
    printf "${BLUE}Powered by lie_kg${RESET}\n\n"
}

# ---------------- LOGGING ----------------

log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

# ---------------- SPINNER ----------------

spinner() {

    local pid=$1
    local delay=0.1
    local spin='|/-\'

    while ps -p "$pid" > /dev/null 2>&1; do

        for i in $(seq 0 3); do
            printf "\r${CYAN}${spin:$i:1}${RESET} "
            sleep $delay
        done

    done

    printf "\r"
}

# ---------------- RUN COMMAND ----------------

run_cmd() {

    local text="$1"
    shift

    printf "${YELLOW}▶${RESET} ${BOLD}%s${RESET}\n" "$text"

    (
        "$@"
    ) >> "$LOG_FILE" 2>&1 &

    local pid=$!

    spinner "$pid"

    wait "$pid"

    printf "${GREEN}✔${RESET} %s\n\n" "$text"
}

# ---------------- ERROR HANDLER ----------------

error_handler() {

    local line="$1"

    printf "\n${RED}${BOLD}❌ INSTALL FAILED${RESET}\n"
    printf "${YELLOW}Line:${RESET} %s\n" "$line"
    printf "${YELLOW}Log:${RESET} %s\n\n" "$LOG_FILE"

    exit 1
}

trap 'error_handler ${LINENO}' ERR

# ---------------- INTERNET CHECK ----------------

check_internet() {

    printf "${CYAN}${BOLD}Checking internet connection...${RESET}\n"

    if ping -c 1 google.com >/dev/null 2>&1; then
        printf "${GREEN}✔ Internet connection OK${RESET}\n\n"
    else
        printf "${RED}❌ No internet connection${RESET}\n"
        exit 1
    fi
}

# ---------------- OS CHECK ----------------

check_os() {

    if [ ! -f /etc/os-release ]; then
        echo "Unsupported OS"
        exit 1
    fi

    . /etc/os-release

    case "$ID" in
        ubuntu|debian)

            printf "${GREEN}✔ Supported OS:${RESET} %s\n\n" "$PRETTY_NAME"

            ;;

        *)

            printf "${RED}Unsupported OS:${RESET} %s\n" "$PRETTY_NAME"
            exit 1

            ;;

    esac
}

# ---------------- SYSTEM INFO ----------------

system_info() {

    echo "${CYAN}${BOLD}System Information${RESET}"

    echo "OS:        $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
    echo "Kernel:    $(uname -r)"
    echo "Arch:      $(uname -m)"
    echo "CPU:       $(nproc) Cores"

    if command -v free >/dev/null 2>&1; then
        echo "RAM:       $(free -h | awk '/Mem:/ {print $2}')"
    fi

    echo
}

# ---------------- INSTALL PACKAGES ----------------

install_packages() {

    run_cmd "Updating packages" \
        $SUDO apt-get update -y

    run_cmd "Installing dependencies" \
        $SUDO apt-get install -y \
        lxd \
        lxc \
        uidmap \
        bridge-utils \
        curl \
        wget \
        ca-certificates

}

# ---------------- ENABLE LXD ----------------

enable_lxd() {

    if command -v systemctl >/dev/null 2>&1; then

        run_cmd "Enabling LXD service" \
            $SUDO systemctl enable --now lxd || true

    fi
}

# ---------------- USER CONFIG ----------------

configure_user() {

    TARGET_USER="${SUDO_USER:-$USER}"

    if id -nG "$TARGET_USER" | grep -qw lxd; then

        printf "${GREEN}✔${RESET} User already in lxd group\n\n"
        return

    fi

    run_cmd "Adding user to lxd group" \
        $SUDO usermod -aG lxd "$TARGET_USER"
}

# ---------------- INIT LXD ----------------

init_lxd() {

    printf "${CYAN}${BOLD}Initializing LXD...${RESET}\n\n"

    run_cmd "Running automatic LXD init" \
        $SUDO lxd init --auto
}

# ---------------- TEST LXD ----------------

test_lxd() {

    printf "${CYAN}${BOLD}Testing LXD...${RESET}\n\n"

    run_cmd "Checking LXD info" \
        $SUDO lxc info

    run_cmd "Checking container list" \
        $SUDO lxc list
}

# ---------------- SUCCESS MESSAGE ----------------

success_message() {

    printf "\n${GREEN}${BOLD}"

    cat << "EOF"

╔══════════════════════════════════════╗
║                                      ║
║       INSTALLATION COMPLETED 🚀     ║
║                                      ║
╚══════════════════════════════════════╝

EOF

    printf "${RESET}"

    echo "${CYAN}Quick Commands:${RESET}"
    echo

    echo "lxc list"
    echo "lxc info"
    echo "lxc storage list"
    echo "lxc network list"

    echo
    echo "Launch Ubuntu container:"
    echo

    echo "lxc launch ubuntu:24.04 mycontainer"

    echo
    echo "${YELLOW}IMPORTANT:${RESET}"
    echo

    echo "Run:"
    echo
    echo "newgrp lxd"

    echo
    echo "OR reboot:"
    echo
    echo "sudo reboot"

    echo
    echo "${MAGENTA}${BOLD}Powered by lie_kg 🔥${RESET}"
    echo
}

# ---------------- MAIN ----------------

main() {

    touch "$LOG_FILE"

    show_header

    log "Installer started"

    check_internet

    check_os

    system_info

    install_packages

    enable_lxd

    configure_user

    init_lxd

    test_lxd

    success_message

    log "Installer completed"
}

main "$@"
