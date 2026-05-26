#!/bin/bash
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common-functions.sh"

echo "Running post-create setup..."
echo "  WORKSPACE_DIR: ${WORKSPACE_DIR}"
echo "  WORKSPACE_LAYOUT: ${WORKSPACE_LAYOUT:-standard}"

###########################################
# Verify MCP Setup
###########################################

verify_mcp_setup


###########################################
# Aliases and Functions
###########################################

setup_common_aliases
setup_common_functions

# Worktree-specific setup
if [ "$WORKSPACE_LAYOUT" = "worktree" ]; then
    setup_worktree_aliases
    setup_worktree_functions
fi


###########################################
# Serena MCP Server Script
###########################################

# Determine project path based on layout
if [ "$WORKSPACE_LAYOUT" = "worktree" ]; then
    SERENA_PROJECT_PATH="${WORKSPACE_DIR}/main"
else
    SERENA_PROJECT_PATH="${WORKSPACE_DIR}"
fi
create_serena_start_script "$SERENA_PROJECT_PATH"


###########################################
# Claude Code Components
###########################################

link_claude_components


###########################################
# Docker Socket
###########################################

fix_docker_socket


###########################################
# TestContainers
###########################################

create_testcontainers_config


###########################################
# Claude MCP Configuration
###########################################

echo "Configuring Claude Code MCP servers..."
claude mcp remove serena 2>/dev/null || true
claude mcp add --transport http serena http://localhost:${SERENA_MCP_PORT}/mcp


###########################################
# Workspace Directories (worktree layout)
###########################################

if [ "$WORKSPACE_LAYOUT" = "worktree" ]; then
    echo -n "Preparing workspace directories..."
    sudo chown -R $(id -u):$(id -g) "${WORKSPACE_DIR}/worktrees"
    sudo chown -R $(id -u):$(id -g) "${WORKSPACE_DIR}/main"
    print_ok
fi


###########################################
# Source workspace-specific post-create script
###########################################

WORKSPACE_POST_CREATE="${SCRIPT_DIR}/post-create-extra.sh"
if [ -f "$WORKSPACE_POST_CREATE" ]; then
    echo "Running workspace-specific post-create..."
    source "$WORKSPACE_POST_CREATE"
fi


echo " "
print_checkmark "Post-create setup complete!"
