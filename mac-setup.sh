#!/bin/bash

#===============================================================================
# Mac AI Server Setup Script
# Sets up: Homebrew, Colima (Docker), Ollama, Open WebUI
# 
# Works on any Apple Silicon Mac (M1/M2/M3/M4)
# Run with: bash mac-setup.sh
# Dry run:  bash mac-setup.sh --dry-run
#
# Safe to run multiple times - checks for existing installations
#===============================================================================

set -e  # Exit on any error

# Check for dry-run flag
DRY_RUN=false
if [[ "$1" == "--dry-run" ]] || [[ "$1" == "-n" ]]; then
    DRY_RUN=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_dry() { echo -e "${CYAN}[DRY-RUN]${NC} Would: $1"; }

# Wrapper function to execute or simulate commands
run_cmd() {
    if $DRY_RUN; then
        print_dry "$*"
    else
        eval "$@"
    fi
}

echo ""
echo "=============================================="
echo "   Mac AI Server Setup"
echo "=============================================="
if $DRY_RUN; then
    echo ""
    echo -e "${CYAN}   *** DRY-RUN MODE - No changes will be made ***${NC}"
fi
echo ""
echo "This script will install:"
echo "  • Homebrew (package manager)"
echo "  • Xcode Command Line Tools"
echo "  • Colima (Docker runtime)"
echo "  • Docker & Docker Compose"
echo "  • Ollama (local LLM server)"
echo "  • Open WebUI (chat interface)"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

#===============================================================================
# 1. Xcode Command Line Tools
#===============================================================================
print_status "Checking Xcode Command Line Tools..."

if xcode-select -p &>/dev/null; then
    print_success "Xcode Command Line Tools already installed"
else
    if $DRY_RUN; then
        print_dry "Install Xcode Command Line Tools (xcode-select --install)"
    else
        print_status "Installing Xcode Command Line Tools..."
        xcode-select --install
        echo ""
        print_warning "A dialog box will appear. Click 'Install' and wait for completion."
        read -p "Press Enter after installation completes..."
    fi
fi

#===============================================================================
# 2. Homebrew
#===============================================================================
print_status "Checking Homebrew..."

if command -v brew &>/dev/null; then
    print_success "Homebrew already installed"
else
    if $DRY_RUN; then
        print_dry "Install Homebrew from https://brew.sh"
        print_dry "Add Homebrew to PATH in ~/.zprofile"
    else
        print_status "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for this session
        eval "$(/opt/homebrew/bin/brew shellenv)"
        
        # Add to .zprofile for future sessions
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        
        print_success "Homebrew installed"
    fi
fi

# Ensure brew is in PATH for rest of script
if ! $DRY_RUN; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

#===============================================================================
# 3. Colima and Docker
#===============================================================================
print_status "Checking Colima and Docker..."

if command -v colima &>/dev/null; then
    print_success "Colima already installed"
else
    if $DRY_RUN; then
        print_dry "brew install colima docker docker-compose"
    else
        print_status "Installing Colima and Docker..."
        brew install colima docker docker-compose
    fi
fi

# Check if Colima is running
if colima status &>/dev/null 2>&1; then
    print_success "Colima already running"
else
    if $DRY_RUN; then
        print_dry "colima start --cpu 4 --memory 8 --disk 60"
    else
        print_status "Starting Colima with 4 CPUs and 8GB RAM..."
        colima start --cpu 4 --memory 8 --disk 60
    fi
fi

# Set Docker context
if ! $DRY_RUN; then
    docker context use colima 2>/dev/null || true
fi

# Verify Docker works
print_status "Verifying Docker installation..."
if $DRY_RUN; then
    print_dry "docker ps (verify Docker responds)"
    print_success "Docker check (skipped in dry-run)"
elif docker ps &>/dev/null; then
    print_success "Docker is working"
else
    print_error "Docker is not responding. Check Colima status."
    exit 1
fi

#===============================================================================
# 4. Colima Auto-start on Boot
#===============================================================================
print_status "Configuring Colima to start on boot..."

if $DRY_RUN; then
    print_dry "Create ~/Library/LaunchAgents/com.colima.autostart.plist"
    print_dry "launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/com.colima.autostart.plist"
    print_success "Colima autostart configured (dry-run)"
else
    mkdir -p ~/Library/LaunchAgents

    USERNAME=$(whoami)

    cat << EOF > ~/Library/LaunchAgents/com.colima.autostart.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.colima.autostart</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-c</string>
        <string>sleep 10 && /opt/homebrew/bin/colima start --cpu 4 --memory 8</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>/Users/${USERNAME}</string>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/colima.out.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/colima.err.log</string>
</dict>
</plist>
EOF

    # Load the launch agent
    launchctl bootout gui/$(id -u)/com.colima.autostart 2>/dev/null || true
    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.colima.autostart.plist

    print_success "Colima will start automatically on boot"
fi

#===============================================================================
# 5. Ollama
#===============================================================================
print_status "Checking Ollama..."

if command -v ollama &>/dev/null; then
    print_success "Ollama already installed"
else
    if $DRY_RUN; then
        print_dry "brew install ollama"
    else
        print_status "Installing Ollama..."
        brew install ollama
    fi
fi

# Configure Ollama to listen on all interfaces (for network access)
if $DRY_RUN; then
    print_dry "launchctl setenv OLLAMA_HOST 0.0.0.0"
else
    launchctl setenv OLLAMA_HOST 0.0.0.0
fi

# Start Ollama service if not running
if ! $DRY_RUN && brew services list | grep ollama | grep -q started; then
    print_success "Ollama service already running"
else
    if $DRY_RUN; then
        print_dry "brew services start ollama"
    else
        print_status "Starting Ollama service..."
        brew services start ollama
        sleep 5
    fi
fi

# Check if llama3.2 is already downloaded
if ! $DRY_RUN && ollama list 2>/dev/null | grep -q "llama3.2"; then
    print_success "llama3.2 model already downloaded"
else
    if $DRY_RUN; then
        print_dry "ollama pull llama3.2"
    else
        print_status "Pulling llama3.2 model (this may take a few minutes)..."
        ollama pull llama3.2
    fi
fi

print_success "Ollama ready"

#===============================================================================
# 6. Open WebUI
#===============================================================================
print_status "Checking Open WebUI..."

if $DRY_RUN; then
    print_dry "mkdir -p ~/docker/open-webui"
    print_dry "docker run -d --name open-webui --restart=unless-stopped -p 3000:8080 -v ~/docker/open-webui:/app/backend/data -e OLLAMA_BASE_URL=http://host.docker.internal:11434 ghcr.io/open-webui/open-webui:main"
    print_success "Open WebUI configured (dry-run)"
else
    mkdir -p ~/docker/open-webui

    if docker ps -a --format '{{.Names}}' | grep -q '^open-webui$'; then
        # Container exists, check if running
        if docker ps --format '{{.Names}}' | grep -q '^open-webui$'; then
            print_success "Open WebUI already running"
        else
            print_status "Starting existing Open WebUI container..."
            docker start open-webui
            print_success "Open WebUI started"
        fi
    else
        print_status "Installing Open WebUI..."
        docker run -d \
          --name open-webui \
          --restart=unless-stopped \
          -p 3000:8080 \
          -v ~/docker/open-webui:/app/backend/data \
          -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
          ghcr.io/open-webui/open-webui:main
        print_success "Open WebUI installed and running"
    fi
fi

#===============================================================================
# 7. Create directory structure
#===============================================================================
print_status "Creating recommended directory structure..."

if $DRY_RUN; then
    print_dry "mkdir -p ~/dev ~/docker ~/models/gguf ~/models/embeddings ~/agents/scheduled ~/agents/workflows ~/data/inbox ~/data/archive"
else
    mkdir -p ~/dev
    mkdir -p ~/docker
    mkdir -p ~/models/gguf
    mkdir -p ~/models/embeddings
    mkdir -p ~/agents/scheduled
    mkdir -p ~/agents/workflows
    mkdir -p ~/data/inbox
    mkdir -p ~/data/archive
fi

print_success "Directory structure created"

#===============================================================================
# 8. Install useful utilities
#===============================================================================
print_status "Checking utilities..."

UTILS="git htop tmux jq wget"
MISSING=""

for util in $UTILS; do
    if ! command -v $util &>/dev/null; then
        MISSING="$MISSING $util"
    fi
done

if [ -z "$MISSING" ]; then
    print_success "All utilities already installed"
else
    if $DRY_RUN; then
        print_dry "brew install$MISSING"
    else
        print_status "Installing:$MISSING"
        brew install $MISSING
    fi
    print_success "Utilities installed"
fi

#===============================================================================
# Summary
#===============================================================================
echo ""
echo "=============================================="
echo "   Setup Complete!"
echo "=============================================="
echo ""

# Get IP address
IP_ADDRESS=$(ipconfig getifaddr en0 2>/dev/null || echo "YOUR_IP")

echo "Your services are running at:"
echo ""
echo "  Ollama API:    http://localhost:11434"
echo "                 http://${IP_ADDRESS}:11434 (from other devices)"
echo ""
echo "  Open WebUI:    http://localhost:3000"
echo "                 http://${IP_ADDRESS}:3000 (from other devices)"
echo ""
echo "Quick commands:"
echo ""
echo "  ollama list              # See downloaded models"
echo "  ollama pull <model>      # Download a new model"
echo "  ollama run <model>       # Chat with a model in terminal"
echo "  docker ps                # See running containers"
echo "  docker stats             # Monitor container resources"
echo ""
echo "Recommended models to try:"
echo ""
echo "  ollama pull mistral      # Good general purpose"
echo "  ollama pull llama3.1:8b  # Larger, better reasoning"
echo "  ollama pull codellama    # Coding focused"
echo ""
print_success "Enjoy your local AI server!"
