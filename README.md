# Mac AI Server Setup

A single script to turn any Apple Silicon Mac into a local AI server with Ollama and Open WebUI.

## What It Installs

- **Homebrew** — macOS package manager
- **Colima** — lightweight Docker runtime (auto-starts on boot)
- **Docker & Docker Compose** — container management
- **Ollama** — local LLM server (runs entirely offline)
- **Open WebUI** — ChatGPT-style interface for your local models
- **Utilities** — git, htop, tmux, jq, wget

## Quick Start

```bash
# Download the script
curl -O https://raw.githubusercontent.com/dwythdyn/mac-setup.sh

# Run it
bash mac-setup.sh
```

Press Enter when prompted. The script takes 10-15 minutes on a fresh Mac (mostly downloading models).

### Dry Run Mode

Preview what the script will do without making changes:

```bash
bash mac-setup.sh --dry-run
```

## After Setup

### Access Your Services

| Service | Local URL | Network URL |
|---------|-----------|-------------|
| Open WebUI | http://localhost:3000 | http://YOUR_IP:3000 |
| Ollama API | http://localhost:11434 | http://YOUR_IP:11434 |

Find your IP with: `ipconfig getifaddr en0`

### First Time Open WebUI Setup

1. Open http://localhost:3000
2. Create an account (first user becomes admin)
3. Select a model from the dropdown
4. Start chatting

## Working with Ollama

### List Downloaded Models

```bash
ollama list
```

### Download New Models

```bash
# Small & fast (~2GB)
ollama pull llama3.2
ollama pull gemma2:2b

# Medium — better reasoning (~5GB)
ollama pull llama3.1:8b
ollama pull mistral

# Coding focused
ollama pull codellama

# Large — best quality, needs 24GB+ RAM (~40GB)
ollama pull llama3.1:70b
```

### Chat in Terminal

```bash
ollama run llama3.2
```

Type `/bye` or press `Ctrl+D` to exit.

### Remove a Model

```bash
ollama rm model-name
```

## Verifying Everything Works

### Check Colima (Docker runtime)

```bash
colima status
```

Should show: `colima is running using macOS Virtualization.Framework`

### Check Docker

```bash
docker ps
```

Should list running containers including `open-webui`.

### Check Ollama

```bash
# Service status
brew services list | grep ollama

# API responding
curl http://localhost:11434

# Should print: Ollama is running
```

### Check Open WebUI

```bash
docker logs open-webui --tail 20
```

Or just open http://localhost:3000 in your browser.

## Verify Auto-Start on Boot

After a reboot, run these checks:

```bash
# Wait 30 seconds after login, then:
colima status          # Should be running
docker ps              # Should show open-webui
curl localhost:11434   # Should respond
```

If Colima isn't running, check the logs:

```bash
cat /tmp/colima.err.log
```

## Directory Structure

The script creates this layout:

```
~/
├── dev/                    # Your code projects
├── docker/                 # Docker container data
│   └── open-webui/         # Open WebUI persistent data
├── models/                 # Non-Ollama model files
│   ├── gguf/               # GGUF format models
│   └── embeddings/         # Embedding models
├── agents/                 # Automation scripts
│   ├── scheduled/          # Cron-style jobs
│   └── workflows/          # Multi-step automations
└── data/                   # Working data
    ├── inbox/              # Files to process
    └── archive/            # Completed files
```

Ollama stores its models in `~/.ollama/models/` (managed automatically).

## Common Tasks

### Restart Open WebUI

```bash
docker restart open-webui
```

### Update Open WebUI

```bash
docker pull ghcr.io/open-webui/open-webui:main
docker stop open-webui
docker rm open-webui
docker run -d \
  --name open-webui \
  --restart=unless-stopped \
  -p 3000:8080 \
  -v ~/docker/open-webui:/app/backend/data \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  ghcr.io/open-webui/open-webui:main
```

### Stop Everything

```bash
docker stop open-webui
brew services stop ollama
colima stop
```

### Monitor Resource Usage

```bash
# Docker containers
docker stats

# System overview
htop
```

## Network Access

By default, Ollama and Open WebUI are accessible from any device on your local network. From another computer or phone:

- Open WebUI: `http://192.168.x.x:3000`
- Ollama API: `http://192.168.x.x:11434`

Replace `192.168.x.x` with your Mac's IP address.

## Troubleshooting

### "Ollama is not running"

```bash
brew services restart ollama
```

### Docker commands fail

```bash
colima status
# If not running:
colima start --cpu 4 --memory 8
```

### Open WebUI won't load

```bash
docker logs open-webui
# Check for errors, then:
docker restart open-webui
```

### Models are slow

- Smaller models (llama3.2, gemma2:2b) are faster
- Close other memory-hungry apps
- Check RAM usage with `htop`

## Privacy Note

Everything runs locally. Ollama models execute on your Mac's hardware with zero network calls. Your prompts and data never leave your machine.

The only network activity:
- Initial download of models (one-time)
- Open WebUI container updates (when you choose to update)

## Requirements

- Apple Silicon Mac (M1/M2/M3/M4)
- macOS 13+ (Ventura or later)
- 16GB RAM minimum (24GB+ recommended for larger models)
- 50GB+ free disk space
