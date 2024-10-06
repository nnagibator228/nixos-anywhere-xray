#!/bin/bash

set -e

# Use the DIRPATH environment variable defined in the Dockerfile
DIRPATH=$DIRPATH

# Function to check if a file exists and is non-empty
check_file() {
    local file="$1"
    if [ ! -f "$file" ] || [ ! -s "$file" ]; then
        return 1
    fi
    return 0
}

# Check for authorized keys file
if ! check_file "$DIRPATH/root_authorized_keys.txt" && ! check_file "$DIRPATH/authorized_keys.txt"; then
    echo "Error: Neither root_authorized_keys.txt nor authorized_keys.txt exists or is empty."
    exit 1
fi

# Check for SSH private key
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    echo "Error: SSH private key not found in $HOME/.ssh/"
    exit 1
fi

# Check if TARGET environment variable is set
if [ -z "${TARGET}" ]; then
    echo "Error: TARGET env ip/host is not set."
    exit 1
fi

nix run github:nix-community/nixos-anywhere -- --flake '.#nixos-anywhere-vm' --option pure-eval false --print-build-logs root@$TARGET
echo "done. "
