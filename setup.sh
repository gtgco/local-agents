#!/usr/bin/env bash
# Setup script for local-agents on a new machine
# Tested on macOS (Apple Silicon). Requires Homebrew.
set -euo pipefail

echo "=== Local Agentic Development Setup ==="
echo ""

# Check prerequisites
if ! command -v brew &>/dev/null; then
    echo "Error: Homebrew required. Install from https://brew.sh"
    exit 1
fi

# 1. Install Goose CLI
echo "[1/5] Installing Goose CLI..."
if command -v goose &>/dev/null; then
    echo "  Goose already installed: $(goose --version)"
else
    brew install block-goose-cli
    echo "  Installed: $(goose --version)"
fi

# 2. Install Ollama
echo "[2/5] Installing Ollama..."
if command -v ollama &>/dev/null; then
    echo "  Ollama already installed: $(ollama --version)"
else
    brew install ollama
fi

# Start Ollama service
if ! curl -s http://localhost:11434/ &>/dev/null; then
    echo "  Starting Ollama service..."
    brew services start ollama
    sleep 3
fi

# 3. Pull the local model
echo "[3/5] Pulling qwen3-coder-next model (~51GB)..."
if ollama list 2>/dev/null | grep -q "qwen3-coder-next"; then
    echo "  Model already downloaded."
else
    echo "  This will take 10-20 minutes depending on your connection."
    ollama pull qwen3-coder-next
fi

# 4. Install uv (for MCP server extensions)
echo "[4/5] Installing uv (Python package manager)..."
if command -v uv &>/dev/null; then
    echo "  uv already installed."
else
    brew install uv
fi

# 5. Set up Minions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MINIONS_DIR="$SCRIPT_DIR/minions"

echo "[5/5] Setting up Minions (Stanford hazyresearch/minions)..."
if [ ! -d "$MINIONS_DIR" ]; then
    echo "  Error: minions/ directory not found. Run:"
    echo "    git submodule update --init"
    exit 1
fi

if [ ! -d "$MINIONS_DIR/.venv" ]; then
    echo "  Creating Python 3.11 venv..."
    cd "$MINIONS_DIR"
    uv venv --python 3.11 .venv
    echo "  Installing dependencies..."
    uv pip install -e .
    cd "$SCRIPT_DIR"
else
    echo "  Minions venv already exists."
fi

# 6. Configure Goose
echo ""
echo "[6/6] Configuring Goose..."
GOOSE_CONFIG_DIR="$HOME/.config/goose"
mkdir -p "$GOOSE_CONFIG_DIR"

if [ ! -f "$GOOSE_CONFIG_DIR/config.yaml" ]; then
    cat > "$GOOSE_CONFIG_DIR/config.yaml" << 'YAML'
GOOSE_PROVIDER: ollama
GOOSE_MODEL: qwen3-coder-next
OLLAMA_HOST: http://localhost:11434
YAML
    echo "  Created Goose config at $GOOSE_CONFIG_DIR/config.yaml"
    echo "  Run 'goose configure' to add extensions and customize."
else
    echo "  Goose config already exists. Skipping."
fi

# 7. Check for .env
echo ""
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "⚠  No .env file found. Copy the example and add your API keys:"
    echo "    cp .env.example .env"
    echo "    # Edit .env with your ANTHROPIC_API_KEY"
else
    echo "✓  .env file found."
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Quick start:"
echo "  goose session                           # Local AI agent (free)"
echo "  GOOSE_PROVIDER=claude-code goose session # Use Claude Code"
echo "  ./minions-run --context ./file.py --protocol minion  # Frontier+local"
echo ""
echo "See SETUP.md for full documentation."
