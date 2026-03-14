# Local Agentic Development Setup

## New Machine Setup

```bash
git clone --recursive https://github.com/pocketsolder/local-agents.git
cd local-agents
cp .env.example .env   # Add your ANTHROPIC_API_KEY
./setup.sh             # Installs everything (~20 min for model download)
```

## Architecture

```
Goose (orchestrator)
├── Provider: Ollama (local) ── qwen3-coder-next (80B MoE, 3B active)
├── Provider: Claude Code     ── claude cli passthrough
├── Provider: Cursor Agent    ── cursor cli passthrough
├── Extensions via MCP        ── Web Search, Fetch, Git
└── Minions (Stanford)        ── Opus 4.6 (planner) + local model (worker)
```

## Installed Components

| Component | Version | Install Method |
|-----------|---------|----------------|
| Goose CLI | 1.27.2 | `brew install block-goose-cli` |
| Ollama | 0.17.7 | `brew install ollama` |
| Model | qwen3-coder-next (Q4_K_M, ~51GB) | `ollama pull qwen3-coder-next` |

## Hardware: M4 Max MacBook Pro (128GB)

- **Chip**: Apple M4 Max, 16 cores (12P + 4E)
- **Memory**: 128GB unified
- **Bandwidth**: ~546 GB/s
- **Model footprint**: ~51GB (leaves ~77GB for OS, apps, context)

## Quick Start

```bash
# Start a Goose session with local Ollama (default)
goose session

# Use Claude Code as the backend instead
GOOSE_PROVIDER=claude-code goose session

# Use Cursor Agent as the backend
GOOSE_PROVIDER=cursor-agent goose session

# Switch default provider permanently
# Edit ~/.config/goose/config.yaml and change GOOSE_PROVIDER
```

## Provider Details

### Ollama (Default - Fully Local, Free)
- Config: `~/.config/goose/config.yaml`
- Model: `qwen3-coder-next` (80B MoE, only 3B active per token)
- 256K native context window (up to 1M with extrapolation)
- Trained via RL on 800K executable coding tasks
- Measured: 36.4 tok/s generation, 283.5 tok/s prompt processing on M4 Max 128GB

### Claude Code (Passthrough)
- Requires: `claude` CLI installed and authenticated
- Set: `GOOSE_PROVIDER=claude-code`
- Known issue: permission prompts can be problematic in auto mode

### Cursor Agent (Passthrough)
- Requires: Cursor IDE installed
- Set: `GOOSE_PROVIDER=cursor-agent`
- Uses Cursor's model routing

## Spark vs M4 Max — Serving Recommendation

**Winner: M4 Max (your machine)**

| Spec | M4 Max (128GB) | DGX Spark (128GB) |
|------|----------------|-------------------|
| Memory Bandwidth | **546 GB/s** | 273 GB/s |
| Token Gen Speed (70B) | **~10-18 tok/s** | ~2.7 tok/s |
| Compute (AI TOPS) | ~38 TOPS | **1,000 TOPS (FP4)** |
| Price | ~$4,499 | $4,699 |
| Upgradeable Memory | No | No |
| CUDA Support | No (MLX) | **Yes** |

**Why M4 Max wins for inference serving:**
- 2x memory bandwidth = ~2x faster token generation
- Token generation is bandwidth-bound, not compute-bound
- Unified memory means zero GPU/CPU copy overhead
- Silent, portable, and doubles as your dev machine

**When DGX Spark would win:**
- Fine-tuning models (CUDA + 1 PFLOP FP4)
- Prefill-heavy workloads (prompt processing)
- CUDA-dependent ML pipelines (PyTorch native)

## Model Selection Rationale

With 128GB, the best options ranked:

1. **qwen3-coder-next (80B MoE, Q4_K_M ~51GB)** — CHOSEN
   - Only 3B active params per token = very fast inference
   - Purpose-built for agentic coding via RL training
   - 256K context handles entire repos
   - Leaves 77GB headroom for OS + tools

2. Llama 3.3 70B (Q4 ~40GB) — solid general purpose, not MoE-optimized
3. Qwen3-Coder 30B (19GB) — faster but less capable
4. Qwen3-Coder 480B (Q3 ~115GB) — too tight, leaves no headroom

## Benchmark Results (M4 Max 128GB)

Model: `qwen3-coder-next` (80B MoE, Q4_K_M) via Ollama

| Task | Prompt Tok | Gen Tok | Prompt tok/s | Gen tok/s | Total |
|------|-----------|---------|-------------|----------|-------|
| Simple greeting | 14 | 10 | 103.9 | 39.6 | 3.3s |
| Code generation (Python) | 48 | 324 | 195.9 | 36.7 | 9.3s |
| Code review / debugging | 146 | 804 | 401.8 | 36.6 | 22.9s |
| Multi-file architecture | 48 | 1823 | 238.3 | 36.2 | 51.8s |
| Tool-call / function calling | 89 | 158 | 327.0 | 36.7 | 4.7s |
| **AVERAGE** | **345** | **3119** | **283.5** | **36.4** | |

- Avg generation: **36.4 tok/s** (consistent across all task types)
- Avg prompt processing: **283.5 tok/s** (scales with prompt length)
- Total tokens generated in benchmark: 3,119

## Enabled Extensions

### Built-in (Platform)
| Extension | Status | Purpose |
|-----------|--------|---------|
| Developer | enabled | Shell commands, file editing, code analysis |
| Analyze | enabled | Tree-sitter code structure analysis |
| Chat Recall | enabled | Search past conversations |
| Memory (Top Of Mind) | enabled | Persistent context via env vars |
| Todo | enabled | Task tracking within sessions |
| Extension Manager | enabled | Dynamic extension management |
| Summon | enabled | Delegate to subagents |
| Apps | enabled | HTML/CSS/JS sandboxed apps |
| Code Mode | disabled | Token-saving code execution (conflicts with tool calls for local LLMs) |

### MCP Servers (External)
| Extension | Command | Purpose |
|-----------|---------|---------|
| Web Search (DuckDuckGo) | `uvx duckduckgo-mcp-server` | Free web search, no API key |
| Web Fetch | `uvx mcp-server-fetch` | Fetch URLs, convert to markdown |
| Git | `uvx mcp-server-git` | Git operations from within sessions |

### Verified Working
- Web search: searched DuckDuckGo, fetched Python 3.14.3 release info
- Web fetch: fetched httpbin.org/get and returned JSON response
- Git: ran `git_status` on local repo, correctly identified branch and untracked files

## Configuration

Config file: `~/.config/goose/config.yaml`

## Stanford Minions Integration

Minions (hazyresearch/minions) enables frontier + local model collaboration:
- **Frontier model (Claude)** decomposes tasks, plans, and synthesizes answers
- **Local model (qwen3-coder-next)** reads the full context and executes subtasks
- Result: 5-30x cloud cost reduction while recovering 97.9% of frontier quality

### Setup
- Repo: `local-agents/minions/`
- Venv: `minions/.venv/` (Python 3.11)
- API keys: sourced from `~/Development/voice-dev-assistant/.env`
- Wrapper script: `local-agents/minions-run`

### Usage

```bash
# Interactive chat over a codebase (uses gitingest for full repo context)
./minions-run --context /path/to/project --protocol minions --use-gitingest

# Interactive chat over a single file
./minions-run --context ./some-file.py --protocol minion

# Override models
MINIONS_LOCAL=ollama/qwen3-coder-next MINIONS_REMOTE=anthropic/claude-opus-4-6 ./minions-run --context ./code.py --protocol minion

# From within a Goose session (via Developer extension shell)
# Goose can shell out to minions-run for complex tasks that benefit from frontier+local collaboration
```

### Two Protocols
- **Minion (singular)**: Conversational back-and-forth between local worker and cloud supervisor. Good for focused analysis of a single document/file.
- **Minions (plural)**: Cloud supervisor decomposes into parallel subtasks, local workers process chunks concurrently, cloud synthesizes. Better for large codebases.

### Tested
- Protocol: Minion (singular), 2 rounds
- Local: qwen3-coder-next via Ollama
- Remote: claude-opus-4-6 via Anthropic API
- Task: Bug detection in Python code — successfully identified integer division bug
- Full round-trip completed in ~53 seconds

## Useful Commands

```bash
# Check running models
ollama list

# Test model directly
ollama run qwen3-coder-next

# Check Goose config
goose info

# Start Goose session (uses config defaults)
goose session

# Start Goose with extra extensions on-the-fly
goose session --with-extension "uvx some-mcp-server"

# One-shot command
echo "do something" | goose run -i -

# Start Goose with verbose logging
GOOSE_LOG=debug goose session

# Update Goose
goose update

# Update Ollama
brew upgrade ollama
```
