# syntax=docker/dockerfile:1.4
FROM mcr.microsoft.com/dotnet/sdk:8.0-bookworm-slim

######################
# Build ARGs
######################

ARG USERNAME=node
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG WORKSPACE_DIR

# Workspace layout: "worktree" (main/ + worktrees/) or "standard" (flat)
ARG WORKSPACE_LAYOUT=standard

# Optional features
ARG INSTALL_PLAYWRIGHT=false


######################
# Environment Variables
######################

ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV SHELL=/bin/bash
ENV HOME="/home/node"
ENV PATH="$HOME/.local/bin/:$PATH"
ENV DEVCONTAINER=true


######################
# System Packages
######################

RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  iptables \
  ipset \
  iproute2 \
  jq \
  nano \
  vim \
  bc \
  tree \
  aggregate \
  dnsutils \
  gnupg2 \
  manpages \
  bash \
  bash-completion \
  curl \
  ca-certificates \
  && apt-get clean && rm -rf /var/lib/apt/lists/*


######################
# Node.js 20.x
######################

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y nodejs \
  && apt-get clean && rm -rf /var/lib/apt/lists/*


######################
# Workspace Directory Structure
######################

# Create workspace structure based on layout:
# - worktree: /workspaces/{name}/ with main/ and worktrees/ subdirs
# - standard: /workspaces/{name}/ flat structure
RUN mkdir -p "$WORKSPACE_DIR" \
    && if [ "$WORKSPACE_LAYOUT" = "worktree" ]; then \
         mkdir -p "$WORKSPACE_DIR/main" "$WORKSPACE_DIR/worktrees"; \
       fi
WORKDIR "$WORKSPACE_DIR"


######################
# uv Package Manager
######################

ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh


######################
# User Setup
######################

RUN groupadd --gid $USER_GID $USERNAME 2>/dev/null || true \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME 2>/dev/null || true \
    && mkdir -p /home/$USERNAME \
    && chown -R $USER_UID:$USER_GID /home/$USERNAME

RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

RUN mkdir -p "${HOME}/.claude" \
  && chown -R $USER_UID:$USER_GID "${HOME}/.claude"

RUN mkdir -p "${WORKSPACE_DIR}/.claude" \
  && chown -R $USER_UID:$USER_GID "${WORKSPACE_DIR}/.claude"

# Set ownership for worktree layout directories
RUN if [ "$WORKSPACE_LAYOUT" = "worktree" ]; then \
      chown -R $USER_UID:$USER_GID "${WORKSPACE_DIR}/main" \
      && chown -R $USER_UID:$USER_GID "${WORKSPACE_DIR}/worktrees"; \
    fi

RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} \
  && chmod 0440 /etc/sudoers.d/${USERNAME}

RUN mkdir -p /tmp/mcp-servers \
  && chown -R $USER_UID:$USER_GID /tmp/mcp-servers

RUN if [ ! -d "${WORKSPACE_DIR}/claude_files" ]; then mkdir -p "${WORKSPACE_DIR}/claude_files"; fi \
  && chown -R $USER_UID:$USER_GID "${WORKSPACE_DIR}/claude_files"


######################
# Serena MCP Server
######################

RUN cd /tmp/mcp-servers \
  && if [ ! -d serena/.git ]; then \
       git clone https://github.com/oraios/serena serena; \
     fi \
  && cd serena \
  && git checkout 502d3f3 \
  && /home/node/.local/bin/uv sync


######################
# NPM Update
######################

RUN npm install -g --loglevel=verbose npm@11.10.0


######################
# Playwright (Optional)
######################

RUN if [ "$INSTALL_PLAYWRIGHT" = "true" ]; then \
      npm install -g playwright \
      && npx playwright install-deps \
      && apt-get update && apt-get install -y --no-install-recommends xvfb \
      && apt-get clean && rm -rf /var/lib/apt/lists/* \
      && npx playwright install chromium firefox msedge; \
    fi


######################
# Final Setup
######################

RUN mkdir -p /home/node/.cache \
  && chown -R $USER_UID:$USER_GID /home/node/.cache

RUN mkdir -p "$HOME/.local/share" \
  && chown -R $USER_UID:$USER_GID "$HOME/.local"


######################
# Claude Code CLI
######################

USER $USERNAME
RUN cd $WORKSPACE_DIR
RUN curl -fsSL https://claude.ai/install.sh | bash -s -- 2.1.129
# Version history: 2.1.84, 2.1.121, 2.1.129
