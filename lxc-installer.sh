#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================================
#   LXC + LXD AUTO INSTALLER (VPS SAFE VERSION)
#   Ubuntu / Debian
#   Author: lie_kg
# =========================================================

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# ---------------- COLORS ----------------

RESET="\033[0m"
BOLD="\033[1m"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
MAGENTA="\033[35m"
WHITE="\033[97m"

# ---------------- SAFE SYMBOLS ----------------

OK="[OK]"
FAIL="[FAIL]"
WARN="[WARN]"
INFO="[INFO]"
ARROW=">>"

# ---------------- CONFIG ----------------

INSTALL_LOG="/tmp/lxd_installer.log"
MAX_RETRIES=3
RETRY_DELAY=5

TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)

# ---------------- ROOT CHECK ----------------

SUDO=""

if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

# ---------------- LOGGING ----------------

init_log() {
    echo "=== LXC/LXD INSTALLER LOG ===" > "$INSTALL_LOG"
    echo "Started: $(date)" >> "$INSTALL_LOG"
}

log_message() {
    local level="$1"
    local msg="$2"

    echo "[$(date '+%H:%M:%S')] [$level] $msg" >> "$INSTALL_LOG"
}

# ---------------- HEADER ----------------

show_header() {
    clear

    echo -e "${BLUE}${BOLD}"

cat << "EOF"

██╗      ██╗  ██╗ ██████╗  ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗
██║      ╚██╗██╔╝██╔════╝  ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗
██║       ╚███╔╝ ██║       ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝
██║       ██╔██╗ ██║       ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗
███████╗ ██╔╝ ██╗╚██████╗  ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
╚══════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝

EOF

    echo -e "${RESET}"

    echo -e "${MAGENTA}${BOLD}AUTO LXC + LXD INSTALLER${RESET}"
    echo -e "${CYAN}Made by lie_kg${RESET}"

    _progress_bar 2 "Initializing"
}

# ---------------- BOX ----------------

print_box() {
    local msg="$1"

    echo
    echo "+================================================+"
    printf "| %-46s |\n" "$msg"
    echo "+================================================+"
}

# ---------------- PROGRESS BAR ----------------

_progress_bar() {
    local duration=${1:-2}
    local message="${2:-Loading}"
    local width=40

    printf "\n${CYAN}${BOLD}%s:${RESET} [" "$message"

    for ((i=0; i<width; i++)); do
        printf "#"
        sleep 0.03
    done

    printf "] ${GREEN}${OK}${RESET}\n\n"
}

# ---------------- SPINNER ----------------

_spinner() {
    local pid=$1
    local delay=0.10
    local spin='-\|/'

    while ps -p $pid > /dev/null 2>&1; do
        for i in $(seq 0 3); do
            printf "\r${CYAN}[%c]${RESET} " "${spin:$i:1}"
            sleep $delay
        done
    done

    printf "\r"
}

# ---------------- RUN WITH SPINNER ----------------

run_with_spinner() {
    local desc="$1"
    shift

    printf "${CYAN}${INFO}${RESET} ${BOLD}%s${RESET}\n" "$desc"

    (
        "$@"
    ) >> "$INSTALL_LOG" 2>&1 &

    local pid=$!

    _spinner $pid

    wait $pid

    if [ $? -eq 0 ]; then
        printf "${GREEN}${OK}${RESET} %s\n\n" "$desc"
        log_message "SUCCESS" "$desc"
    else
        printf "${RED}${FAIL}${RESET} %s\n\n" "$desc"
        log_message "ERROR" "$desc"
        return 1
    fi
}

# ---------------- SYSTEM INFO ----------------

show_system_info() {

    print_box "SYSTEM INFORMATION"

    local os_info
    os_info=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")

    local kernel_info
    kernel_info=$(uname -r)

    local arch_info
    arch_info=$(uname -m)

    local mem_info
    mem_info=$(free -h | awk '/^Mem:/ {print $2}')

    local disk_info
    disk_info=$(df -h / | awk 'NR==2 {print $4}')

    echo -e "${CYAN}OS:${RESET}           ${GREEN}${os_info}${RESET}"
    echo -e "${CYAN}Architecture:${RESET} ${GREEN}${arch_info}${RESET}"
    echo -e "${CYAN}Kernel:${RESET}       ${GREEN}${kernel_info}${RESET}"
    echo -e "${CYAN}Memory:${RESET}       ${GREEN}${mem_info}${RESET}"
    echo -e "${CYAN}Disk Space:${RESET}   ${GREEN}${disk_info}${RESET}"
    echo
}

# ---------------- CHECK PRIVILEGES ----------------

check_privileges() {

    if [ "$(id -u)" -ne 0 ]; then

        if ! groups | grep -q '\bsudo\b'; then
            echo -e "${RED}${FAIL} No sudo privileges${RESET}"
            exit 1
        fi
    fi
}

# ---------------- DETECT OS ----------------

detect_os() {

    if [ -f /etc/os-release ]; then
        . /etc/os-release

        OS_ID="${ID:-unknown}"
        OS_VERSION="${VERSION_ID:-unknown}"
    else
        echo -e "${RED}${FAIL} Cannot detect OS${RESET}"
        exit 1
    fi

    case "$OS_ID" in
        ubuntu|debian)
            echo -e "${GREEN}${OK} Supported OS detected: ${OS_ID} ${OS_VERSION}${RESET}\n"
            ;;
        *)
            echo -e "${RED}${FAIL} Unsupported OS${RESET}"
            exit 1
            ;;
    esac
}

# ---------------- INSTALL PACKAGES ----------------

install_prereqs() {

    print_box "INSTALLING PREREQUISITES"

    run_with_spinner \
        "Updating package lists" \
        $SUDO apt-get update -y

    run_with_spinner \
        "Upgrading packages" \
        $SUDO apt-get upgrade -y

    run_with_spinner \
        "Installing required packages" \
        $SUDO apt-get install -y \
        lxc \
        uidmap \
        bridge-utils \
        squashfs-tools \
        curl \
        wget \
        ca-certificates \
        snapd \
        locales
}

# ---------------- FIX LOCALES ----------------

setup_locales() {

    print_box "CONFIGURING LOCALES"

    run_with_spinner \
        "Generating UTF-8 locale" \
        $SUDO locale-gen en_US.UTF-8

    run_with_spinner \
        "Updating locale settings" \
        $SUDO update-locale LANG=en_US.UTF-8
}

# ---------------- INSTALL LXD ----------------

install_lxd() {

    print_box "INSTALLING SNAPD + LXD"

    run_with_spinner \
        "Enabling snapd socket" \
        $SUDO systemctl enable --now snapd.socket

    run_with_spinner \
        "Starting snapd service" \
        $SUDO systemctl enable --now snapd

    echo -e "${CYAN}${INFO}${RESET} Waiting for snapd..."

    local timeout=30
    local count=0

    while [ $count -lt $timeout ]; do

        if snap list >/dev/null 2>&1; then
            echo -e "${GREEN}${OK} snapd ready${RESET}\n"
            break
        fi

        sleep 1
        ((count++))
    done

    if ! snap list lxd >/dev/null 2>&1; then

        run_with_spinner \
            "Installing LXD" \
            $SUDO snap install lxd --channel=latest/stable

    else
        echo -e "${GREEN}${OK} LXD already installed${RESET}\n"
    fi

    run_with_spinner \
        "Enabling LXD daemon" \
        $SUDO systemctl enable --now snap.lxd.daemon
}

# ---------------- USER GROUP ----------------

configure_user() {

    print_box "CONFIGURING USER"

    TARGET_USER="${SUDO_USER:-$(whoami)}"

    echo -e "${CYAN}User:${RESET} ${GREEN}${TARGET_USER}${RESET}\n"

    if ! groups "$TARGET_USER" | grep -q '\blxd\b'; then

        run_with_spinner \
            "Adding user to lxd group" \
            $SUDO usermod -aG lxd "$TARGET_USER"

    else
        echo -e "${GREEN}${OK} User already in lxd group${RESET}\n"
    fi
}

# ---------------- INIT LXD ----------------

init_lxd() {

    print_box "INITIALIZING LXD"

    run_with_spinner \
        "Running lxd init --auto" \
        $SUDO lxd init --auto
}

# ---------------- VALIDATE ----------------

validate_installation() {

    print_box "VALIDATING INSTALLATION"

    run_with_spinner \
        "Checking LXD service" \
        $SUDO lxc info

    run_with_spinner \
        "Checking container list" \
        $SUDO lxc list
}

# ---------------- SUCCESS ----------------

show_success() {

    print_box "INSTALLATION COMPLETE"

    echo -e "${GREEN}${BOLD}${OK} LXC/LXD installed successfully${RESET}\n"

    echo -e "${CYAN}Next Steps:${RESET}"
    echo

    echo -e "${GREEN}${ARROW}${RESET} Reload shell:"
    echo -e "   ${YELLOW}newgrp lxd${RESET}"
    echo

    echo -e "${GREEN}${ARROW}${RESET} Or reboot:"
    echo -e "   ${YELLOW}sudo reboot${RESET}"
    echo

    echo -e "${CYAN}Useful Commands:${RESET}"
    echo

    echo -e "  ${GREEN}lxc list${RESET}"
    echo -e "  ${GREEN}lxc info${RESET}"
    echo -e "  ${GREEN}lxc storage list${RESET}"
    echo -e "  ${GREEN}lxc network list${RESET}"
    echo -e "  ${GREEN}lxc launch ubuntu:24.04 myvm${RESET}"
    echo

    echo -e "${MAGENTA}Log File:${RESET} ${INSTALL_LOG}"
    echo
}

# ---------------- ERROR HANDLER ----------------

handle_error() {

    local exit_code=$?
    local line_number=$1
    local command="$2"

    echo
    echo "+================================================+"
    echo "|               INSTALLATION FAILED              |"
    echo "+================================================+"
    echo
    echo -e "${RED}${FAIL}${RESET} Line: ${line_number}"
    echo -e "${RED}${FAIL}${RESET} Command: ${command}"
    echo -e "${RED}${FAIL}${RESET} Exit Code: ${exit_code}"
    echo
    echo -e "${YELLOW}Check log:${RESET} ${INSTALL_LOG}"
    echo

    exit $exit_code
}

trap 'handle_error ${LINENO} "${BASH_COMMAND}"' ERR

trap 'echo -e "\n${YELLOW}${WARN} Interrupted by user${RESET}\n"; exit 1' INT

# ---------------- MAIN ----------------

main() {

    init_log

    show_header

    check_privileges

    detect_os

    show_system_info

    install_prereqs

    setup_locales

    install_lxd

    configure_user

    init_lxd

    validate_installation

    show_success
}

main "$@"
