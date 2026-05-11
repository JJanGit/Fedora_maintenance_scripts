#!/bin/bash

# Formating
R='\e[0m' # Reset
B='\e[1m' # Bold
GREEN='\e[32m'
CYAN='\e[36m'
RED='\e[31m'

echo -e "${B}========== JJ FEDORA CLEANUP SCRIPT ==========${R}"
echo

# Function to ask user which command to run
ask_run() {
    local title="$1"
    local question="$2"
    local cmd="$3"
    local answer

    echo -e "${B}$title${R}"

    while true; do
        read -r -p "${question}" answer

        case "${answer,,}" in
            y)
                echo -e "${CYAN}${B}Executing:${R} ${CYAN}$cmd${R}"
                echo

                # Execute command and stop script if it fails
                if ! bash -c "$cmd"; then
                    echo -e "${RED}Command failed!${R}"
                    exit 1
                fi

                break
                ;;
            n)
                echo -e "${CYAN}Alright, skipped!${R}"
                break
                ;;
            *)
                echo -e "${RED}Invalid input: '$answer'. Please answer with ${B}y${R}${RED} or ${B}n${R}${RED}.${R}"
                ;;
        esac
    done
    echo
}

# Check for root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${B}Please run this script as root.${R}"
    exit 1
fi

ask_run \
"----- 1. Rremove unnecessary packages -----" \
"Do you want to remove unnecessaty packages? (y/n):" \
"dnf autoremove"

ask_run \
"----- 2. Remove unused flatpaks -----" \
"Do you want to remove unused flatpaks? (y/n):" \
"flatpak uninstall --unused"

ask_run \
"----- 3. Remove old journal entries -----" \
"Do you want to remove journal entries older then 14 days? (y/n):" \
"journalctl --vacuum-time=14d"

ask_run \
"----- 4. Emptying the trash -----" \
"Do you want to empty the trash of every user? (y/n):" \
"trash-empty --all-users"

echo -e "${B}========== JJ FEDORA CLEANUP FINISHED ==========${R}"
echo
