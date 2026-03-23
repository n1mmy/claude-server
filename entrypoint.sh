#!/bin/bash
set -e

# Generate SSH host keys into the persistent volume if not already present
if [ ! -f /etc/ssh/host-keys/.generated ]; then
    ssh-keygen -t rsa     -b 4096 -f /etc/ssh/host-keys/ssh_host_rsa_key     -N ""
    ssh-keygen -t ecdsa   -b 256  -f /etc/ssh/host-keys/ssh_host_ecdsa_key   -N ""
    ssh-keygen -t ed25519         -f /etc/ssh/host-keys/ssh_host_ed25519_key -N ""
    touch /etc/ssh/host-keys/.generated
fi

# Validate PORT
if [ -n "$PORT" ]; then
    case "$PORT" in
        ''|*[!0-9]*)
            echo "ERROR: PORT must be a number (got: $PORT)" >&2
            exit 1
            ;;
    esac
    if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "ERROR: PORT must be between 1 and 65535 (got: $PORT)" >&2
        exit 1
    fi
fi

# Install authorized keys from mounted secret
if [ -f /etc/ssh/authorized_keys/authorized_keys ]; then
    cp /etc/ssh/authorized_keys/authorized_keys /home/ubuntu/.ssh/authorized_keys
    chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
    chmod 600 /home/ubuntu/.ssh/authorized_keys
else
    echo "WARNING: No authorized_keys found at /etc/ssh/authorized_keys/authorized_keys"
fi

# Write ANTHROPIC_API_KEY into ubuntu's environment so SSH sessions pick it up
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'" >> /home/ubuntu/.bashrc
    echo "export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'" >> /home/ubuntu/.profile
fi

echo "SSH server starting..."
exec /usr/sbin/sshd -D -e ${PORT:+-p $PORT}
