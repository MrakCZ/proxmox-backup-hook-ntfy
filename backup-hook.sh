#!/bin/bash

# Get the directory where the script is stored
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Load variables from the .env file in the script directory
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env" || { echo "Error: .env file not found in script directory ($SCRIPT_DIR)."; exit 1; }

# Check if all required variables were loaded
[[ -z "$auth_token" || -z "$webhook_url" ]] && { echo "Error: Required variables were not loaded from .env file."; exit 1; }

# Variables for script execution
phase="$1"
vmid="$3"
storeid="${STOREID}"
host="$(hostname)"
vmtype="${VMTYPE}"  # lxc or qemu, specifies the VM type

# Path to vzdump log files
vzdump_log="/var/log/vzdump/${vmtype}-${vmid}.log"

# Variables for messages
success_log="/tmp/backup_job_success.log"

# Function to send a notification via curl
send_notification() {
    local message="$1"
    local tags="$2"

    curl -s -o /dev/null -w "Return code: %{http_code}" -H "Authorization: Bearer $auth_token" \
         -H "Icon: https://avatars.githubusercontent.com/u/2678585?s=200&v=4" \
         -H "Title: $host: Backup to $storeid" \
         -H "Tags: $tags" \
         -d "$message" \
         "$webhook_url"
}

# Function to get the name of the virtual machine
get_guest_name() {
    case "$vmtype" in
        "qemu") qm config "$vmid" | awk '/^name:/ {print $2}';;
        "lxc") pct config "$vmid" | awk '/^hostname:/ {print $2}';;
        *) echo "Unknown VM type";;
    esac
}

# End phase of a single VM backup
if [[ "$phase" == "backup-end" ]]; then
    guest_name=$(get_guest_name)
    echo "$vmid ($guest_name)" >> "$success_log"
fi

# Phase for backup interruption/completion (backup-abort/job-abort)
if [[ "$phase" == "backup-abort" || "$phase" == "job-abort" ]]; then
    guest_name=$(get_guest_name)
    if [[ -n "$vmid" || -n "$guest_name" ]]; then
        if [[ -f "$vzdump_log" ]]; then
            error_message=$(grep "ERROR:" "$vzdump_log" | tail -n 1 | awk -F 'ERROR: ' '{print $2}')
            [[ -z "$error_message" ]] && error_message="Unknown error during backup of $vmid ($guest_name)."
        else
            error_message="Log $vzdump_log not found. Error during backup of $vmid ($guest_name)."
        fi
        formatted_error_message=$(echo -e "Error during backup of $vmid ($guest_name):\n$error_message")
        # Send error notification
        send_notification "$formatted_error_message" "x"
    fi
fi

# End phase of the job (job-end or job-abort)
if [[ "$phase" == "job-end" || "$phase" == "job-abort" ]]; then
    if [[ -s "$success_log" ]]; then
        success_message=$(echo -e "Backup successfully completed for the following VM/LXC:\n$(cat "$success_log")")
        # Send success notification
        send_notification "$success_message" "white_check_mark"
    fi
    rm -f "$success_log"
fi
