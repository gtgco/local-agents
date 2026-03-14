#!/usr/bin/env bash
# Setup script for local-agents on a new machine
# Tested on macOS (Apple Silicon). Requires Homebrew.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Local Agentic Development Setup ==="
echo ""

# Check prerequisites
if ! command -v brew &>/dev/null; then
    echo "Error: Homebrew required. Install from https://brew.sh"
    exit 1
fi

# 1. Install Goose CLI
echo "[1/7] Installing Goose CLI..."
if command -v goose &>/dev/null; then
    echo "  Goose already installed: $(goose --version)"
else
    brew install block-goose-cli
    echo "  Installed: $(goose --version)"
fi

# 2. Install Ollama
echo "[2/7] Installing Ollama..."
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
echo "[3/7] Pulling qwen3-coder-next model (~51GB)..."
if ollama list 2>/dev/null | grep -q "qwen3-coder-next"; then
    echo "  Model already downloaded."
else
    echo "  This will take 10-20 minutes depending on your connection."
    ollama pull qwen3-coder-next
fi

# 4. Install uv (for Python venvs and MCP server extensions)
echo "[4/7] Installing uv (Python package manager)..."
if command -v uv &>/dev/null; then
    echo "  uv already installed."
else
    brew install uv
fi

# 5. Set up Minions
MINIONS_DIR="$SCRIPT_DIR/minions"

echo "[5/7] Setting up Minions (Stanford hazyresearch/minions)..."
if [ ! -d "$MINIONS_DIR/.git" ] && [ ! -f "$MINIONS_DIR/.git" ]; then
    echo "  Initializing submodule..."
    cd "$SCRIPT_DIR"
    git submodule update --init --recursive
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

# Apply mistralai import fix if needed
if grep -q "^from minions.clients.mistral import MistralClient" "$MINIONS_DIR/minions/clients/__init__.py" 2>/dev/null; then
    echo "  Applying mistralai import compatibility fix..."
    sed -i.bak 's/^from minions.clients.mistral import MistralClient/try:\n    from minions.clients.mistral import MistralClient\nexcept ImportError:\n    MistralClient = None/' \
        "$MINIONS_DIR/minions/clients/__init__.py" 2>/dev/null || true
fi

# 6. Install Goose config with all extensions
echo "[6/7] Configuring Goose with extensions..."
GOOSE_CONFIG_DIR="$HOME/.config/goose"
mkdir -p "$GOOSE_CONFIG_DIR"

cp "$SCRIPT_DIR/goose-config.yaml" "$GOOSE_CONFIG_DIR/config.yaml"
echo "  Installed Goose config to $GOOSE_CONFIG_DIR/config.yaml"

# 7. Pre-cache MCP server dependencies so first goose session is fast
echo "[7/7] Pre-caching MCP extension dependencies..."
echo "  Caching duckduckgo-mcp-server..."
uvx --quiet duckduckgo-mcp-server --help >/dev/null 2>&1 || true
echo "  Caching mcp-server-fetch..."
uvx --quiet mcp-server-fetch --help >/dev/null 2>&1 || true
echo "  Caching mcp-server-git..."
uvx --quiet mcp-server-git --help >/dev/null 2>&1 || true
echo "  Done."

# 8. Check for .env
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
