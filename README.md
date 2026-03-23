# claude-server

A Docker image that runs an SSH server with [Claude Code](https://github.com/anthropics/claude-code) pre-installed, intended for use as a remote development environment.

## What it does

- Runs an OpenSSH server accessible via public key authentication
- Installs Claude Code CLI globally via npm
- Runs as the `ubuntu` user
- SSH host keys are persisted via a mounted volume so they survive container restarts

## Build

```sh
docker build -t claude-server .
```

### Build arguments

| Argument | Default | Description |
|---|---|---|
| `BASE_IMAGE` | `ubuntu:24.04` | Base image to build from |
| `NODE_VERSION` | `22` | Node.js major version to install |

```sh
docker build --build-arg BASE_IMAGE=ubuntu:22.04 --build-arg NODE_VERSION=20 -t claude-server .
```

## Run

Two mounts are required:

- **Host keys volume** at `/etc/ssh/host-keys` — persists SSH host keys across restarts
- **Authorized keys file** at `/etc/ssh/authorized_keys/authorized_keys` — public keys allowed to connect

```sh
docker run -d \
  -p 22:22 \
  -e ANTHROPIC_API_KEY=sk-ant-... \
  -v claude-host-keys:/etc/ssh/host-keys \
  -v /path/to/authorized_keys:/etc/ssh/authorized_keys/authorized_keys:ro \
  claude-server
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `22` | Port sshd listens on |
| `ANTHROPIC_API_KEY` | — | Injected into the `ubuntu` user's environment for Claude Code |
| `ANTHROPIC_BASE_URL` | — | Optional custom Anthropic API base URL (passed through via SSH `AcceptEnv`) |

### Connecting

```sh
ssh ubuntu@<host>
```

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
docker build -t your-registry/claude-server:latest .
docker push your-registry/claude-server:latest
```

Then update `image:` in `k8s-manifest.yaml` to match.

#### 2. Set your SSH public key

```sh
kubectl create secret generic ssh-authorized-keys \
  --from-file=authorized_keys=$HOME/.ssh/id_ed25519.pub \
  -n claude-workspace
```

#### 3. Set your Anthropic API key

```sh
kubectl create secret generic anthropic-credentials \
  --from-literal=api-key=sk-ant-... \
  -n claude-workspace
```

#### 4. Deploy

```sh
kubectl apply -f k8s/manifests.yaml
```

#### 5. Get the SSH address

```sh
kubectl get svc claude-ssh -n claude-workspace
# Note the EXTERNAL-IP
```

For local clusters without LoadBalancer:

```sh
kubectl port-forward svc/claude-ssh 2222:22 -n claude-workspace
# Then SSH to localhost:2222
```

#### 6. Connect

```sh-config
Host claude-k8s
    HostName <EXTERNAL-IP>
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

### GPU nodes

To request a GPU, add to the container resources in `manifests.yaml`:

```yaml
resources:
  limits:
    nvidia.com/gpu: "1"
```

And add a node selector or toleration for your GPU node pool.
