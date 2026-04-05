# agentic-coding-container

A Docker image that runs an SSH server with AI coding agents pre-installed, intended for use as a remote development environment. Compatible with the ssh feature of the Claude desktop app allowing for development on a remote machine, for example a kubernetes node with a GPU.

Ships with [Claude Code](https://github.com/anthropics/claude-code) and [OpenAI Codex](https://github.com/openai/codex) out of the box — either can be toggled off at build time.

## What it does

- Runs an OpenSSH server accessible via public key authentication
- Installs Claude Code and Codex CLIs globally via npm (configurable)
- Runs as the `ubuntu` user
- SSH host keys are persisted via a mounted volume so they survive container restarts

## Build

```sh
docker build -t agentic-coding-container .
```

### Build arguments

| Argument | Default | Description |
|---|---|---|
| `BASE_IMAGE` | `ubuntu:24.04` | Base image to build from |
| `NODE_VERSION` | `22` | Node.js major version to install |
| `EXTRA_APT_PACKAGES` | — | Space-separated extra apt packages to install |
| `EXTRA_NPM_PACKAGES` | — | Space-separated extra global npm packages to install |
| `ENABLE_SUDO` | `false` | Grant the `ubuntu` user passwordless `sudo` (grants full root access — use with caution) |
| `INSTALL_CLAUDE` | `true` | Install [Claude Code](https://github.com/anthropics/claude-code) CLI |
| `INSTALL_CODEX` | `true` | Install [OpenAI Codex](https://github.com/openai/codex) CLI |

```sh
# Custom base image and Node version
docker build --build-arg BASE_IMAGE=ubuntu:22.04 --build-arg NODE_VERSION=20 -t agentic-coding-container .

# Claude Code only
docker build --build-arg INSTALL_CODEX=false -t agentic-coding-container .

# Codex only
docker build --build-arg INSTALL_CLAUDE=false -t agentic-coding-container .
```

## Run

Two mounts are required:

- **Host keys volume** at `/etc/ssh/host-keys` — persists SSH host keys across restarts
- **Authorized keys file** at `/etc/ssh/authorized_keys/authorized_keys` — public keys allowed to connect

```sh
docker run -d \
  -p 22:22 \
  -e ANTHROPIC_API_KEY=sk-ant-... \
  -e OPENAI_API_KEY=sk-... \
  -v host-keys:/etc/ssh/host-keys \
  -v /path/to/authorized_keys:/etc/ssh/authorized_keys/authorized_keys:ro \
  agentic-coding-container
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `22` | Port sshd listens on |
| `ANTHROPIC_API_KEY` | — | Injected into the `ubuntu` user's environment for Claude Code (written to `.bashrc`/`.profile` in plaintext) |
| `ANTHROPIC_BASE_URL` | — | Optional custom Anthropic API base URL (passed through via SSH `AcceptEnv`) |
| `OPENAI_API_KEY` | — | Injected into the `ubuntu` user's environment for Codex CLI (written to `.bashrc`/`.profile` in plaintext) |

### Connecting

```sh
ssh ubuntu@<host>
```

## Desktop app sandboxing

The Claude Desktop app runs in a sandbox that may block outbound SSH connections. If the app cannot reach your server directly, use a local port forward so it connects via `localhost` instead.

**SSH port forward:**

```sh
ssh -N -L 2222:<host>:22 ubuntu@<host>
```

Then point the desktop app at `localhost:2222`.

**Persistent forward with autossh:**

```sh
autossh -M 0 -N -L 2222:<host>:22 ubuntu@<host>
```

`autossh` monitors the tunnel and restarts it if it drops. Install via `brew install autossh` on macOS.

## Kubernetes deployment

### Volumes

| Mount | PVC | Purpose |
|---|---|---|
| `/home/ubuntu/workspace` | `workspace-pvc` (10Gi) | Project code |
| `/etc/ssh/host-keys` | `ssh-host-keys-pvc` (1Mi) | Stable SSH host keys |

### Setup

#### 1. Build and push the image

The manifest defaults to `ghcr.io/n1mmy/claude-server:main`. To use a custom image:

```sh
docker build -t your-registry/agentic-coding-container:latest .
docker push your-registry/agentic-coding-container:latest
```

Then update `image:` in `k8s-manifest.yaml` to match.

#### 2. Set your SSH public key

```sh
kubectl create secret generic ssh-authorized-keys \
  --from-file=authorized_keys=$HOME/.ssh/id_ed25519.pub \
  -n claude-workspace
```

#### 3. Set your API keys

```sh
kubectl create secret generic ai-credentials \
  --from-literal=anthropic-api-key=sk-ant-... \
  --from-literal=openai-api-key=sk-... \
  -n claude-workspace
```

#### 4. Deploy

```sh
kubectl apply -f k8s-manifest.yaml
```

#### 5. Get the SSH address

```sh
kubectl get svc agentic-coding-ssh -n claude-workspace
# Note the EXTERNAL-IP
```

For local clusters without LoadBalancer:

```sh
kubectl port-forward svc/agentic-coding-ssh 2222:22 -n claude-workspace
# Then SSH to localhost:2222
```

#### 6. Connect

```sh-config
Host agentic-coding
    HostName <EXTERNAL-IP>
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

### GPU nodes

To request a GPU, add to the container resources in `k8s-manifest.yaml`:

```yaml
resources:
  limits:
    nvidia.com/gpu: "1"
```

And add a node selector or toleration for your GPU node pool.
