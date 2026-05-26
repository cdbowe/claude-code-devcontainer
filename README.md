# Claude Code Devcontainer

A devcontainer setup for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code) inside a containerized development environment. Run multiple workspaces simultaneously on the same machine, sharing a single Claude Code subscription — with credentials, conversation history, and usage tracking unified across all containers through a shared Docker volume.

Includes bare git repo initialization for parallel worktrees, [Serena MCP server](https://github.com/oraios/serena) management, a layered Claude Code component system, and shell utilities.

I run Claude Code exclusively in devcontainers to allow me to safely run `--dangerously-skip-permissions` on a regular basis. It's definitely saved my bacon a few times.

## What's Included

| Component | Description |
|-----------|-------------|
| **Dockerfile** | .NET 8 SDK base, Node.js 20, Claude Code CLI, Serena MCP server, Playwright (optional) |
| **post-create.sh** | One-time setup: symlink Claude components, configure MCP, create shell aliases |
| **post-start.sh** | Every-start setup: bare git init, start Serena, source shell config |
| **common-functions.sh** | Shared library: component linking, worktree management, alias/function injection |
| **devcontainer.json.template** | Full-featured template with all mount categories and placeholders |
| **examples/minimal/** | Working minimal config for standard layout |

## Quick Start

1. Copy `.devcontainer/` into your project root
2. Copy `examples/minimal/devcontainer.json` to `.devcontainer/devcontainer.json`
3. Edit the paths (see [Configuring Mounts](#configuring-mounts))
4. Open in VS Code → "Reopen in Container"

## Workspace Layouts

The devcontainer supports two layouts, controlled by the `WORKSPACE_LAYOUT` build arg and env var.

### Standard Layout

```
/workspaces/myproject/
├── .claude/              # Claude Code config (symlinked from mounts)
├── .devcontainer/        # This config
├── src/                  # Your code (bound from host)
├── tests/
├── package.json
└── claude_files/         # Claude output (optional)
```

Use this when you don't need parallel worktree execution. Your code is bound directly into the workspace root. Git uses the normal `.git/` directory from your host (or a fresh init inside the container).

### Worktree Layout

```
/workspaces/myproject/
├── main/                 # Code files (bound from host)
│   ├── src/
│   ├── tests/
│   └── package.json
├── worktrees/            # Parallel worktrees (local to container)
│   ├── wt-unit-1/
│   └── wt-unit-2/
├── .git/                 # Bare git database (local to container)
├── .claude/              # Claude Code config (symlinked)
├── .devcontainer/
└── claude_files/
```

Use this when you want Claude Code's `/worktree` skill or PRD parallel builds. Code files are bound into `main/`, and the container creates a bare git repo with `main` as a linked worktree. Additional worktrees are created on-the-fly for parallel agent execution.

**Key difference**: In worktree layout, `.git/` is **not** bound from the host — it's created fresh inside the container. This gives Claude a sandboxed git environment where it can freely create branches and worktrees without affecting your host repo.

### When to Use Which

| Scenario | Layout |
|----------|--------|
| General Claude Code usage | `standard` |
| Parallel agent execution (`/worktree`, `/prd build`) | `worktree` |
| You want Claude's git ops isolated from your host | `worktree` |
| Simple setup, no special requirements | `standard` |

## Configuring Mounts

The `devcontainer.json.template` uses `{{PLACEHOLDER}}` syntax. Here's what each one means and how to fill it in.

### Required Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{CONTAINER_NAME}}` | Display name in VS Code | `"My Project - Claude Code"` |
| `{{WORKSPACE_NAME}}` | Directory name under `/workspaces/` | `"myproject"` |
| `{{WORKSPACE_LAYOUT}}` | `"standard"` or `"worktree"` | `"standard"` |
| `{{HOST_CODE_DIR}}` | Absolute path to your code on the host | `"/home/you/projects/myproject"` |

### Optional Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{HOST_CLAUDE_SHARED}}` | Path to shared Claude Code components | `"/home/you/claude-code-tools/.claude"` |
| `{{HOST_CLAUDE_WS}}` | Path to workspace-specific Claude overrides | `"/home/you/claude-configs/myproject"` |
| `{{HOST_SERENA_DIR}}` | Path to `.serena/` config for your project | `"/home/you/projects/myproject/.serena"` |
| `{{HOST_OUTPUT_DIR}}` | Path for Claude output files | `"/home/you/projects/myproject/claude_files"` |

### Code File Mounts

**Standard layout** — bind the whole project root:

```jsonc
"source={{HOST_CODE_DIR}},target=${containerWorkspaceFolder},type=bind,consistency=cached"
```

**Worktree layout** — bind individual directories and files into `main/`:

```jsonc
"source={{HOST_CODE_DIR}}/src,target=${containerWorkspaceFolder}/main/src,type=bind,consistency=cached",
"source={{HOST_CODE_DIR}}/tests,target=${containerWorkspaceFolder}/main/tests,type=bind,consistency=cached",
"source={{HOST_CODE_DIR}}/package.json,target=${containerWorkspaceFolder}/main/package.json,type=bind,consistency=cached",
"source={{HOST_CODE_DIR}}/.gitignore,target=${containerWorkspaceFolder}/main/.gitignore,type=bind,consistency=cached"
```

Why individual binds for worktree layout? Because `.git/` must **not** be bound — the container creates its own bare repo. Binding the entire project root would include `.git/`, breaking the worktree setup. List each top-level directory and config file separately.

### Claude Component Mounts

If you use [claude-code-tools](https://github.com/cdbowe/claude-code-tools) or a similar setup, bind the component directories so the post-create script can symlink them:

```jsonc
// Shared components (available to all workspaces)
"source=/home/you/claude-code-tools/.claude/settings.json,target=${containerWorkspaceFolder}/.claude/settings.json,type=bind",
"source=/home/you/claude-code-tools/.claude/commands,target=/tmp/claude-shared/commands,type=bind",
"source=/home/you/claude-code-tools/.claude/agents,target=/tmp/claude-shared/agents,type=bind",
"source=/home/you/claude-code-tools/.claude/rules,target=/tmp/claude-shared/rules,type=bind",
"source=/home/you/claude-code-tools/.claude/hooks,target=/tmp/claude-shared/hooks,type=bind",
"source=/home/you/claude-code-tools/.claude/skills,target=/tmp/claude-shared/skills,type=bind",
"source=/home/you/claude-code-tools/.claude/statusline,target=/tmp/claude-shared/statusline,type=bind",
```

## Claude Component Layering

The devcontainer supports a two-tier component system: **shared** components (common across workspaces) and **workspace-specific** overrides.

### Why Bind Mounts?

Claude Code automatically discovers and loads files from specific directories (`.claude/commands/`, `.claude/agents/`, `.claude/rules/`, etc.) into its context. The challenge is getting your tools into those directories inside the container in a way that's:

1. **Reusable** — shared tools (skills, agents, rules) are written once and available in every workspace
2. **Overridable** — each workspace can add specialized tools that only apply to that project
3. **Editable live** — because these are bind mounts (not copies), you can edit files, add new agents, or tweak rules from your host machine while the container is running — changes appear immediately inside the container. Rebuild the container to re-run the symlink setup if you add new component directories.

The bind mount + symlink approach solves all three. Host directories are bound into staging paths (`/tmp/claude-shared/`, `/tmp/claude-workspace/`), then the post-create script wires them into `.claude/` where Claude Code expects to find them.

### Two Tiers

| Tier | Mounted to | Purpose | Example |
|------|-----------|---------|---------|
| **Shared** | `/tmp/claude-shared/` | Tools used across all workspaces | Generic PRD agents, worktree scripts, statusline |
| **Workspace** | `/tmp/claude-workspace/` | Tools for one specific project | Project-specific rules, test patterns, specialized agents |

On the host, you'd organize this as two separate directories — one for shared tools (e.g., your [claude-code-tools](https://github.com/cdbowe/claude-code-tools) clone) and one per workspace for project-specific overrides:

```
~/claude-configs/
├── shared/                 # Shared across all workspaces
│   ├── settings.json
│   ├── commands/
│   ├── agents/
│   ├── rules/
│   ├── hooks/
│   ├── skills/
│   └── statusline/
├── project-alpha/          # Workspace-specific for project-alpha
│   ├── rules/
│   ├── agents/
│   └── skills/
└── project-beta/           # Workspace-specific for project-beta
    └── rules/
```

### How It Works

```
Host                                Container                        .claude/ (what Claude sees)
─────────────────────────────────   ─────────────────────────────    ─────────────────────────────
shared/                             /tmp/claude-shared/              .claude/commands/ -> shared
  commands/                ──bind──>  commands/                        └── ~WORKSPACE/ -> workspace
  agents/                  ──bind──>  agents/                       .claude/agents/   -> shared
  rules/                   ──bind──>  rules/                          └── ~WORKSPACE/ -> workspace
  hooks/                   ──bind──>  hooks/                        .claude/rules/    -> shared
  skills/                  ──bind──>  skills/                          └── ~WORKSPACE/ -> workspace
  statusline/              ──bind──>  statusline/

project-alpha/                      /tmp/claude-workspace/
  rules/                   ──bind──>  rules/     ──symlink──> shared/rules/~WORKSPACE/
  agents/                  ──bind──>  agents/    ──symlink──> shared/agents/~WORKSPACE/
  skills/                  ──bind──>  skills/    ──symlink──> .claude/skills/ (project-level)
```

The `link_claude_components` function in `common-functions.sh` handles all the symlink wiring:

1. `.claude/{component}/` symlinks to `/tmp/claude-shared/{component}/`
2. If `/tmp/claude-workspace/{component}/` exists, it's symlinked as a `~WORKSPACE/` subdirectory inside the shared component
3. Claude Code discovers both shared and workspace-specific files through the unified `.claude/` tree

**Skills are special**: Claude Code requires a flat directory for skill discovery. Shared skills go to `~/.claude/skills/` (personal-level) and workspace skills go to `.claude/skills/` (project-level). A browsability symlink at `.claude/~SHARED/skills/` makes shared skills visible in the VS Code file explorer.

### Without Workspace Overrides

If you only need shared components (most common), skip the workspace mount section entirely. The post-create script handles missing workspace directories gracefully.

## Multi-Workspace Subscription Sharing

A core design goal of this devcontainer is running **multiple workspaces simultaneously** on a single Claude Code subscription. All containers mount the same `claude-code-home` Docker volume at `~/.claude/`, which means:

- **Single authentication** — log in once, all containers share the credentials
- **Unified conversation history** — every workspace's `.jsonl` transcripts live in the same `~/.claude/projects/` directory
- **Cross-workspace usage tracking** — the [usage estimator script](https://github.com/cdbowe/claude-code-tools) scans all transcripts in `~/.claude/projects/`, so it captures token consumption from every workspace sharing that volume — giving you a single usage percentage against your subscription's 5-hour budget
- **Shared session state** — the session reset timer (`~/.claude/claude-code-session-state`) is shared, so all containers agree on when the usage window resets
- **Persistent auto-memory** — Claude's memories persist across container rebuilds and are available in every workspace

### How It Works

```
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│  Workspace A        │  │  Workspace B        │  │  Workspace C        │
│  (project-alpha)    │  │  (project-beta)     │  │  (project-gamma)    │
│                     │  │                     │  │                     │
│  ~/.claude/ ────────┼──┼──────────┼──────────┼──┼──> claude-code-home │
│                     │  │          │          │  │    (Docker volume)  │
└─────────────────────┘  └──────────┼──────────┘  └─────────────────────┘
                                    │
                         ┌──────────▼──────────┐
                         │  ~/.claude/          │
                         │  ├── .credentials.json  (shared auth)
                         │  ├── projects/          (all transcripts)
                         │  │   ├── -ws-alpha/     (workspace A)
                         │  │   ├── -ws-beta/      (workspace B)
                         │  │   └── -ws-gamma/     (workspace C)
                         │  ├── claude-code-session-state  (shared timer)
                         │  └── CLAUDE.md          (shared memory)
                         └─────────────────────────┘
```

### Setup

Every `devcontainer.json` in the template already includes this mount:

```jsonc
"source=claude-code-home,target=/home/node/.claude,type=volume"
```

Because `claude-code-home` is a **named volume** (not a bind mount), Docker creates it once and reuses it for every container that references it by name. No extra configuration is needed — just use the same volume name across all your devcontainers.

If you need to isolate a workspace from the shared subscription (e.g., a different account), give it a different volume name:

```jsonc
"source=claude-code-home-other-account,target=/home/node/.claude,type=volume"
```

## Persistent Volumes

| Volume | Purpose | Shared Across Containers |
|--------|---------|--------------------------|
| `claude-code-home` | `~/.claude/` — auth, transcripts, session state, auto-memory | Yes |
| `npm-cache` | npm download cache | Yes |
| `npm-global-packages` | Global npm packages (Playwright, etc.) | Yes |
| `claude-mcp-servers` | Serena MCP server installation | Yes |

The `claude-code-home` volume is the foundation of the multi-workspace model. All other volumes are shared for build performance — they avoid re-downloading packages across container rebuilds and workspaces.

## Shell Aliases

The post-create script injects these into `~/.bashrc`:

### Claude Code

| Alias | Command |
|-------|---------|
| `cc` | `clear && claude` |
| `ccr` | `clear && claude --resume` |
| `ccdsp` | `clear && claude --dangerously-skip-permissions` |
| `ccmh` / `ccms` / `ccmo` | Launch with Haiku / Sonnet / Opus |
| `ccu` | Fetch actual usage from Anthropic API |
| `cceu` | Run estimated usage calculator |
| `cccs` | Print model cheatsheet |

### Navigation

| Alias | Command |
|-------|---------|
| `ws` | `cd $WORKSPACE_DIR` |
| `wsm` | `cd $WORKSPACE_DIR/main` (worktree layout) |
| `wswt` | `cd $WORKSPACE_DIR/worktrees` (worktree layout) |

### Serena

| Alias | Command |
|-------|---------|
| `serena-start` | Start Serena MCP server (foreground) |
| `serena-start-bg` | Start in background |
| `serena-log` | Tail Serena log |

### Worktree Management

| Alias | Command |
|-------|---------|
| `cwt` / `wtc` | Clean up stale worktrees (pattern: `wt-*`) |

### Shell Functions

| Function | Description |
|----------|-------------|
| `set_session_reset <time>` | Override usage session reset time (e.g., `set_session_reset "10:30pm"`) |
| `fetch_claude_usage` | Curl Anthropic OAuth usage API with your credentials |
| `clean_worktrees [pattern]` | Remove worktrees matching pattern (default: `wt-*`) |

## Workspace Customization

The setup scripts source optional extension scripts for per-workspace additions:

| Script | When | Use For |
|--------|------|---------|
| `scripts/post-create-extra.sh` | After post-create | Extra package installs, workspace-specific aliases |
| `scripts/post-start-extra.sh` | After post-start | Workspace-specific services, env setup |

Create these files alongside the other scripts. They're sourced (not executed), so they have access to all variables and functions from `common-functions.sh`.

## Dockerfile Customization

The Dockerfile uses build args to toggle features:

| Arg | Default | Description |
|-----|---------|-------------|
| `WORKSPACE_DIR` | (required) | Container workspace path |
| `WORKSPACE_LAYOUT` | `standard` | `standard` or `worktree` |
| `INSTALL_PLAYWRIGHT` | `false` | Install Playwright + Chromium/Firefox/Edge |
| `USERNAME` | `node` | Container user |
| `USER_UID` / `USER_GID` | `1000` | User/group IDs |

### Base Image

The default base is `mcr.microsoft.com/dotnet/sdk:8.0-bookworm-slim`. Change this to match your stack:

```dockerfile
# Node.js project
FROM node:20-bookworm-slim

# Python project
FROM python:3.12-bookworm-slim

# Generic (no SDK)
FROM debian:bookworm-slim
```

If you change the base image, remove or adjust the .NET-specific sections and ensure `git`, `jq`, `bc`, `curl`, and `Node.js` are still installed (required by Claude Code and the setup scripts).

### Serena MCP Server

Serena is installed at build time from a pinned commit. To update:

```dockerfile
RUN cd /tmp/mcp-servers/serena \
  && git checkout <new-commit-hash> \
  && uv sync
```

To remove Serena entirely, delete the Serena sections from the Dockerfile, `post-create.sh`, `post-start.sh`, and `common-functions.sh`.

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) or compatible Docker engine
- [VS Code](https://code.visualstudio.com/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- A Claude Code subscription (Pro, Max, or Enterprise)

## License

MIT
