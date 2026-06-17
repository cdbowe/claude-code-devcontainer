#!/bin/bash
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common-functions.sh"

echo "Running post-start setup..."


###########################################
# Docker Socket
###########################################

fix_docker_socket


###########################################
# Git Safe Directories
###########################################

setup_git_safe_directories


###########################################
# Initialize Bare Git Repository (worktree layout only)
###########################################

if [ "$WORKSPACE_LAYOUT" = "worktree" ]; then
    initialize_bare_git_repo
fi


###########################################
# Load Shell Configuration
###########################################

echo -n "Loading shell configuration..."
source ~/.bashrc
shopt -s expand_aliases
print_ok


###########################################
# Start Serena MCP Server
###########################################

start_serena_server


###########################################
# Start Xvfb (virtual display for Playwright Chromium)
###########################################

start_xvfb


###########################################
# Source workspace-specific post-start script
###########################################

WORKSPACE_POST_START="${SCRIPT_DIR}/post-start-extra.sh"
if [ -f "$WORKSPACE_POST_START" ]; then
    echo "Running workspace-specific post-start..."
    source "$WORKSPACE_POST_START"
fi


###########################################
# Help Output
###########################################

print_serena_help


print_checkmark "Post-start setup complete!"
