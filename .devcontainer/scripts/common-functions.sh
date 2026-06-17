#!/bin/bash
# Common functions for devcontainer setup scripts
# Source this file in post-create.sh and post-start.sh

######################
# Colors and Output
######################

COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
COLOR_GREEN="\033[32m"
COLOR_RESET="\033[0m"

print_checkmark() {
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} ${1}"
}

print_ok() {
    echo -e "${COLOR_GREEN} OK${COLOR_RESET}"
}

print_warning() {
    echo -e "${COLOR_YELLOW}⚠ WARNING: ${1}${COLOR_RESET}"
}

print_error() {
    echo -e "${COLOR_RED}✖ ERROR: ${1}${COLOR_RESET}"
}

######################
# Alias Management
######################

add_alias_if_not_exists() {
    local alias_name="$1"
    local alias_command="$2"
    local bashrc_file="${HOME}/.bashrc"

    if grep -q "^alias $alias_name=" "$bashrc_file"; then
      echo "Alias '$alias_name' already exists in $bashrc_file"
      return 0
    fi

    echo "alias $alias_name='$alias_command'" >> "$bashrc_file"
    echo "Added '$alias_name' to $bashrc_file"
    source "$bashrc_file"
}


######################
# Function Management
######################

add_function_if_not_exists() {
    local function_name="$1"
    local function_body="$2"
    local bashrc_file="${HOME}/.bashrc"

    if grep -q "^${function_name}()" "$bashrc_file" 2>/dev/null; then
      echo "Function '${function_name}' already exists in $bashrc_file"
      return 0
    fi

    echo "" >> "$bashrc_file"
    echo "# ${function_name} function" >> "$bashrc_file"
    echo "$function_body" >> "$bashrc_file"
    echo "Added '${function_name}' to $bashrc_file"
    source "$bashrc_file"
}


######################
# Standard Shell Functions
######################

# set_session_reset function body
SET_SESSION_RESET_FUNC='set_session_reset() {
    local new_time_input="$1"
    local new_reset_time="$(date -d "$new_time_input" +%s)"
    echo "$new_reset_time" > "$HOME/.claude/claude-code-session-state"
    echo "Session reset time set to: $(date -d "@$new_reset_time")"
}'

# clean_worktrees function body (for worktree layout only)
# Calls worktree-cleanup.sh script with pattern (default: wt-*)
CLEAN_WORKTREES_FUNC='clean_worktrees() {
    local pattern="${1:-wt-*}"
    bash "${WORKSPACE_DIR}/.claude/commands/scripts/worktree-cleanup.sh" "$pattern"
}'

# fetch_claude_usage function body
FETCH_CLAUDE_USAGE_FUNC='fetch_claude_usage() {
    local response=$(curl -s --max-time 5 "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $(jq -r ".claudeAiOauth.accessToken // empty" "$HOME/.claude/.credentials.json")" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Content-Type: application/json" \
        -i)
    echo "$response"
    echo "-----"
    echo "$response" | sed "1,/^\s*$/d" | jq .
}'


######################
# Claude Code Cheatsheet
######################

# cccs function body
CCCS_FUNC='cccs() {
    echo ""
    echo "=== Claude Code Cheatsheet ==="
    echo ""
    echo "--- Models ---"
    echo "/model $HAIKU_MODEL    Set model to Haiku"
    echo "/model $SONNET_MODEL   Set model to Sonnet"
    echo "/model $OPUS_MODEL     Set model to Opus"
    echo ""
    echo "=============================="
    echo ""
}'


######################
# Standard Aliases
######################

setup_common_aliases() {
    echo "Setting common alias commands..."

    # cd to WORKSPACE_DIR
    add_alias_if_not_exists "ws" "cd \"${WORKSPACE_DIR}\""

    # Serena
    add_alias_if_not_exists "serena-log" "tail -f /tmp/serena.log"
    add_alias_if_not_exists "serena-start-bg" "nohup serena-start > /tmp/serena.log 2>&1 &"

    # bashrc
    add_alias_if_not_exists "bashrc" "cat ~/.bashrc"
    add_alias_if_not_exists "ebashrc" "vim ~/.bashrc"
    add_alias_if_not_exists "bashrcrefresh" "source ~/.bashrc"
    add_alias_if_not_exists "bashrefresh" "bashrcrefresh"
    add_alias_if_not_exists "loadbashrc" "bashrcrefresh"
    add_alias_if_not_exists "f5" "bashrcrefresh"

    # Claude Code
    add_alias_if_not_exists "cc" "clear && claude"
    add_alias_if_not_exists "ccr" "clear && claude --resume"
    add_alias_if_not_exists "ccdsp" "clear && claude --dangerously-skip-permissions"
    add_alias_if_not_exists "ccmh" "clear && claude --model $HAIKU_MODEL"
    add_alias_if_not_exists "ccms" "clear && claude --model $SONNET_MODEL"
    add_alias_if_not_exists "ccmo" "clear && claude --model $OPUS_MODEL"
    add_alias_if_not_exists "get-claude-usage" "fetch_claude_usage"
    add_alias_if_not_exists "claude-usage" "fetch_claude_usage"
    add_alias_if_not_exists "ccu" "fetch_claude_usage"
    add_alias_if_not_exists "cceu" "bash ${WORKSPACE_DIR}/.claude/statusline/est_claude_usage.sh"
    add_alias_if_not_exists "ccue" "cceu"
    add_alias_if_not_exists "commit-main" "bash ${WORKSPACE_DIR}/.claude/commands/scripts/commit-main.sh"

    # PRD utilities
    add_alias_if_not_exists "prd-stat" "bash ${WORKSPACE_DIR}/.claude/commands/prd/scripts/prd-stat.sh"
    add_alias_if_not_exists "prd-read-phase" "bash ${WORKSPACE_DIR}/.claude/commands/prd/scripts/prd-read.sh"
    add_alias_if_not_exists "prd-read" "prd-read-phase"
    add_alias_if_not_exists "prd-load-prd" "bash ${WORKSPACE_DIR}/.claude/commands/prd/scripts/prd-load.sh"
    add_alias_if_not_exists "prd-load" "prd-load-prd"

    print_ok
}

setup_worktree_aliases() {
    echo "Setting worktree-specific aliases..."

    # cd to main and worktrees directories
    add_alias_if_not_exists "wsm" "cd \"${WORKSPACE_DIR}/main\""
    add_alias_if_not_exists "wswt" "cd \"${WORKSPACE_DIR}/worktrees\""

    # Git worktree cleanup
    add_alias_if_not_exists "clean-worktrees" "clean_worktrees"
    add_alias_if_not_exists "cwt" "clean-worktrees"
    add_alias_if_not_exists "wtc" "clean-worktrees"

    print_ok
}


######################
# Common Functions Setup
######################

setup_common_functions() {
    echo "Adding common shell functions to bashrc..."

    add_function_if_not_exists "set_session_reset" "$SET_SESSION_RESET_FUNC"
    add_function_if_not_exists "fetch_claude_usage" "$FETCH_CLAUDE_USAGE_FUNC"
    add_function_if_not_exists "cccs" "$CCCS_FUNC"

    print_ok
}

setup_worktree_functions() {
    echo "Adding worktree shell functions to bashrc..."

    add_function_if_not_exists "clean_worktrees" "$CLEAN_WORKTREES_FUNC"

    print_ok
}


######################
# Serena Setup
######################

create_serena_start_script() {
    local project_path="$1"

    echo -n "Creating serena-start script..."
    sudo mkdir -p ~/.local/bin
    sudo cat > ~/.local/bin/serena-start << EOF
#!/bin/bash
uv run --directory /tmp/mcp-servers/serena serena start-mcp-server \
    --transport streamable-http \
    --context claude-code \
    --project "${project_path}" \
    --host 0.0.0.0 \
    --port ${SERENA_MCP_PORT}
EOF
    sudo chmod +x ~/.local/bin/serena-start
    print_ok
}

verify_mcp_setup() {
    if [ ! -d /tmp/mcp-servers ]; then
        print_error "MCP Directory /tmp/mcp-servers not found. Check Dockerfile."
        exit 1
    fi

    cd /tmp/mcp-servers
    if [ ! -d serena ]; then
        print_error "Serena not installed. Check Dockerfile."
        exit 1
    fi
}


######################
# Claude Code Components
######################

link_claude_components() {
    echo "Linking Claude Code components (shared + workspace subfolders)..."

    # Fix ownership of .claude directory
    sudo chown -R $(id -u):$(id -g) "${WORKSPACE_DIR}/.claude/" 2>/dev/null || true

    # Workspace subfolder name
    WS_SUBFOLDER="~WORKSPACE"

    # Components with workspace subfolder (shared root + workspace override)
    # Skills excluded — handled separately for Claude Code flat discovery
    for component in "commands" "agents" "rules" "hooks"; do
        component_path="${WORKSPACE_DIR}/.claude/${component}"

        rm -rf "$component_path"
        if [ -d "/tmp/claude-shared/${component}" ]; then
            ln -sf "/tmp/claude-shared/${component}" "$component_path"
            print_checkmark "Linked .claude/${component}/ -> /tmp/claude-shared/${component}"

            find "/tmp/claude-shared/${component}" -maxdepth 1 -type l -lname "/tmp/claude-workspace/${component}" -delete 2>/dev/null || true

            if [ -d "/tmp/claude-workspace/${component}" ]; then
                ln -sf "/tmp/claude-workspace/${component}" "/tmp/claude-shared/${component}/${WS_SUBFOLDER}"
                print_checkmark "Linked .claude/${component}/${WS_SUBFOLDER}/ -> /tmp/claude-workspace/${component}"
            fi
        fi
    done

    # Skills: split into two discovery paths (Claude Code requires flat structure)
    #   Project-level: .claude/skills/ -> workspace skills (discovered by Claude Code)
    #   Personal-level: ~/.claude/skills/ -> shared skills (discovered by Claude Code)
    #   Browsability:   .claude/~SHARED/skills/ -> shared skills (visible in VS Code)
    rm -rf "${WORKSPACE_DIR}/.claude/skills"
    # Clean up stale ~WORKSPACE symlink from shared skills if present
    find "/tmp/claude-shared/skills" -maxdepth 1 -type l -lname "/tmp/claude-workspace/skills" -delete 2>/dev/null || true

    if [ -d "/tmp/claude-workspace/skills" ]; then
        ln -sf "/tmp/claude-workspace/skills" "${WORKSPACE_DIR}/.claude/skills"
        print_checkmark "Linked .claude/skills/ -> /tmp/claude-workspace/skills (project-level discovery)"
    fi

    if [ -d "/tmp/claude-shared/skills" ]; then
        ln -sfn "/tmp/claude-shared/skills" "/home/node/.claude/skills"
        print_checkmark "Linked ~/.claude/skills/ -> /tmp/claude-shared/skills (personal-level discovery)"

        # Browsability symlink so shared skills appear in VS Code explorer
        rm -rf "${WORKSPACE_DIR}/.claude/~SHARED"
        mkdir -p "${WORKSPACE_DIR}/.claude/~SHARED"
        ln -sf "/tmp/claude-shared/skills" "${WORKSPACE_DIR}/.claude/~SHARED/skills"
        print_checkmark "Linked .claude/~SHARED/skills/ -> /tmp/claude-shared/skills (browsable)"
    fi

    # Statusline: shared only
    rm -rf "${WORKSPACE_DIR}/.claude/statusline"
    if [ -d "/tmp/claude-shared/statusline" ]; then
        ln -sf "/tmp/claude-shared/statusline" "${WORKSPACE_DIR}/.claude/statusline"
        print_checkmark "Linked .claude/statusline/ -> /tmp/claude-shared/statusline (shared only)"
    fi

    print_ok
}


######################
# Docker Socket Fix
######################

fix_docker_socket() {
    echo -n "Fixing Docker socket permissions..."
    if [ -S /var/run/docker.sock ]; then
        sudo chgrp docker /var/run/docker.sock
        sudo chmod g+rw /var/run/docker.sock

        # Add node user to docker group for Testcontainers access
        if ! groups node | grep -q '\bdocker\b'; then
            sudo usermod -aG docker node
        fi
        print_ok
    else
        print_warning "Docker socket not found at /var/run/docker.sock"
    fi
}


######################
# TestContainers Config
######################

create_testcontainers_config() {
    echo -n "Creating TestContainers configuration..."
    cat > /home/node/.testcontainers.properties << 'EOF'
# TestContainers configuration for devcontainer/docker-outside-of-docker
host.override=host.docker.internal
container.startup.timeout=00:03:00
EOF
    print_ok
}


######################
# Git Worktree Setup
######################

setup_git_safe_directories() {
    echo -n "Setting '$WORKSPACE_DIR' as safe in Git..."
    git config --global --add safe.directory "$WORKSPACE_DIR" || (print_error "ERROR: Could not set directory as safe" && exit 1)

    # For worktree layout, also add main directory
    if [ "$WORKSPACE_LAYOUT" = "worktree" ]; then
        git config --global --add safe.directory "$WORKSPACE_DIR/main" || true
    fi
    print_ok
}

initialize_bare_git_repo() {
    # Only for worktree layout
    if [ "$WORKSPACE_LAYOUT" != "worktree" ]; then
        return 0
    fi

    local current_ownership="$(id -u):$(id -g)"

    # Check if already initialized
    if [ -d "${WORKSPACE_DIR}/.git" ] && \
       git --git-dir="${WORKSPACE_DIR}/.git" config core.bare 2>/dev/null | grep -q "true" && \
       [ -f "${WORKSPACE_DIR}/main/.git" ] && \
       grep -q "gitdir.*worktrees/main" "${WORKSPACE_DIR}/main/.git" 2>/dev/null; then

        echo -n "Syncing git index with bind-mounted files..."
        cd "${WORKSPACE_DIR}/main"
        git add -A . 2>/dev/null || true
        print_ok
    else
        echo "Initializing bare git repository..."

        # Clean slate
        sudo rm -rf "${WORKSPACE_DIR}/.git" "${WORKSPACE_DIR}/main/.git"

        # Initialize and configure git (once)
        cd "${WORKSPACE_DIR}/main"
        echo "  Initializing git in ${WORKSPACE_DIR}/main..."
        if ! git init --quiet; then
            print_error "git init failed"
            return 1
        fi

        git config user.email "claude-sandbox@local"
        git config user.name "Claude Sandbox"
        git branch -m main 2>/dev/null || git checkout -b main 2>/dev/null || true

        # Stage files
        echo -n "  Staging files..."
        git add -A . 2>/dev/null || true
        print_ok

        # Commit (may fail if nothing staged, that's ok)
        git commit -m "Initial commit (sandbox)" --quiet 2>/dev/null || echo "  (no files to commit)"

        # Convert to bare repository
        echo "  Converting to bare repository..."
        TEMP_BARE="${WORKSPACE_DIR}/.git-temp"
        sudo git clone --bare --quiet . "$TEMP_BARE"
        rm -rf .git
        sudo mv "$TEMP_BARE" "${WORKSPACE_DIR}/.git"

        # Fix ownership immediately so we can create subdirectories
        sudo chown -R "$current_ownership" "${WORKSPACE_DIR}/.git"

        # Set up worktree linkage
        mkdir -p "${WORKSPACE_DIR}/.git/worktrees/main"
        echo "ref: refs/heads/main" > "${WORKSPACE_DIR}/.git/worktrees/main/HEAD"
        echo "${WORKSPACE_DIR}/main/.git" > "${WORKSPACE_DIR}/.git/worktrees/main/gitdir"
        echo "../.." > "${WORKSPACE_DIR}/.git/worktrees/main/commondir"
        echo "gitdir: ${WORKSPACE_DIR}/.git/worktrees/main" > "${WORKSPACE_DIR}/main/.git"

        # Finalize
        git --git-dir="${WORKSPACE_DIR}/.git" config core.bare true
        git --git-dir="${WORKSPACE_DIR}/.git" worktree repair 2>/dev/null || true

        # Regenerate the index file for the worktree (lost during bare conversion)
        cd "${WORKSPACE_DIR}/main"
        git reset 2>/dev/null || true

        print_checkmark "Bare git repository initialized with main worktree"
    fi

    # Ensure worktrees directory exists (created in Dockerfile, chown if needed)
    sudo mkdir -p "${WORKSPACE_DIR}/worktrees"
    sudo chown -R "$current_ownership" "${WORKSPACE_DIR}/worktrees"
}


######################
# Serena Server Start
######################

start_serena_server() {
    echo "Checking for Serena MCP server scripts..."

    if ! command -v serena-start &>/dev/null; then
        echo "'serena-start' command not found. Check Dockerfile and post-create.sh"
        exit 1
    fi
    print_checkmark "serena-start found"

    # Note: serena-log and serena-start-bg are aliases, not commands
    # They're available in interactive shells after sourcing .bashrc
    print_checkmark "serena-log alias configured"
    print_checkmark "serena-start-bg alias configured"

    echo -n "Starting Serena MCP server in background..."
    # Use actual command instead of alias (aliases don't work in scripts)
    nohup serena-start > /tmp/serena.log 2>&1 &
    print_ok
}

######################
# Xvfb Virtual Display
######################

start_xvfb() {
    if ! command -v Xvfb &> /dev/null; then
        return
    fi

    echo -n "Starting Xvfb virtual display..."

    if pgrep -x Xvfb > /dev/null 2>&1; then
        print_ok
        return
    fi

    Xvfb :99 -screen 0 1280x720x24 -nolisten tcp > /dev/null 2>&1 &
    sleep 0.5

    if pgrep -x Xvfb > /dev/null 2>&1; then
        print_ok
    else
        print_warning "Xvfb failed to start"
    fi
}

print_serena_help() {
    echo "  "
    echo "=== Serena MCP Server ==="
    echo "Start manually:"
    echo "  "
    echo "  serena-start"
    echo "  "
    echo "See log output:"
    echo "  "
    echo "  serena-log"
    echo "  "
    echo "Endpoint: http://localhost:${SERENA_MCP_PORT}/mcp"
    echo "Dashboard: http://localhost:24282/dashboard"
    echo "NOTE: Dashboard port starts at 24282 and auto-increments for every Serena instance running"
    echo "  "
    echo "All Claude Code sessions share the same server"
    echo "========================="
    echo "  "
}
