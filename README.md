# Claude Code Kubernetes Setup

Runs Claude Code as a remote SSH server so Claude Desktop can connect to it.

## Volumes

| Mount | PVC | Purpose |
|---|---|---|
| `/home/claude/workspace` | `workspace-pvc` (10Gi) | Project code |
| `/home/claude/data` | `data-pvc` (500Gi) | Video training data |
| `/home/claude/models` | `models-pvc` (50Gi) | Model checkpoints |
| `/etc/ssh/host-keys` | `ssh-host-keys-pvc` (1Mi) | Stable SSH host keys |

## Setup

### 1. Build and push the image

```bash
docker build -t your-registry/claude-server:latest k8s/
docker push your-registry/claude-server:latest
```

Update `image:` in `manifests.yaml` to match.

### 2. Set your SSH public key

```bash
# Base64-encode your public key
cat ~/.ssh/id_ed25519.pub | base64

# Paste the output into manifests.yaml under ssh-authorized-keys.data.authorized_keys
```

Or use kubectl directly (skips editing the YAML):

```bash
kubectl create secret generic ssh-authorized-keys \
  --from-file=authorized_keys=$HOME/.ssh/id_ed25519.pub \
  -n claude-workspace
```

### 3. Set your Anthropic API key

```bash
kubectl create secret generic anthropic-credentials \
  --from-literal=api-key=sk-ant-... \
  -n claude-workspace
```

### 4. Deploy

```bash
kubectl apply -f k8s/manifests.yaml
```

### 5. Get the SSH address

```bash
kubectl get svc claude-ssh -n claude-workspace
# Note the EXTERNAL-IP
```

For local clusters without LoadBalancer:

```bash
kubectl port-forward svc/claude-ssh 2222:22 -n claude-workspace
# Then SSH to localhost:2222
```

### 6. Connect from Claude Desktop

In Claude Desktop settings, add a remote connection:

```
Host: <EXTERNAL-IP>   (or localhost if port-forwarding)
Port: 22              (or 2222 if port-forwarding)
User: claude
Identity file: ~/.ssh/id_ed25519
```

Or configure `~/.ssh/config`:

```ssh-config
Host claude-k8s
    HostName <EXTERNAL-IP>
    User claude
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

Then connect via: `ssh claude-k8s` to verify, then point Claude Desktop at `claude-k8s`.

## GPU nodes

To request a GPU, add to the container resources in `manifests.yaml`:

```yaml
resources:
  limits:
    nvidia.com/gpu: "1"
```

And add a node selector or toleration for your GPU node pool.
