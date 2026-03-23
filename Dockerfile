ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ARG NODE_VERSION=22

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    curl \
    git \
    ca-certificates \
    sudo \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# SSH configuration
RUN mkdir /var/run/sshd \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && echo "AllowUsers ubuntu" >> /etc/ssh/sshd_config \
    && echo "HostKey /etc/ssh/host-keys/ssh_host_rsa_key" >> /etc/ssh/sshd_config \
    && echo "HostKey /etc/ssh/host-keys/ssh_host_ecdsa_key" >> /etc/ssh/sshd_config \
    && echo "HostKey /etc/ssh/host-keys/ssh_host_ed25519_key" >> /etc/ssh/sshd_config \
    && echo "AcceptEnv ANTHROPIC_API_KEY ANTHROPIC_BASE_URL" >> /etc/ssh/sshd_config

# Set up ubuntu user's SSH dir
RUN mkdir -p /home/ubuntu/.ssh \
    && chown -R ubuntu:ubuntu /home/ubuntu \
    && chmod 700 /home/ubuntu/.ssh

# Entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PORT=22
EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
