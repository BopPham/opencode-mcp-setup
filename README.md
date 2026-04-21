# opencode-mcp-setup

One-command setup OpenCode with MCP servers. **No account required**.

## What it installs

- **Bun** (auto-install if missing)
- **OpenCode CLI** (auto-install if missing)
- **4 MCP servers:**
  - `gitnexus` — code intelligence, impact analysis, call graph
  - `context7` — library/framework documentation
  - `playwright` — browser automation, UI validation
  - `sequential-thinking` — complex reasoning, step-by-step analysis
- **4 Agents:** orchestrator, coder, review, commit
- **Rules:** token-budget, lazy-mcp, goal-hint-search, mandatory-search, global
- **Plugin:** auto-save-memory

## Install (No account needed)

### Option 1: curl (Linux/macOS/Windows Git Bash)
```bash
curl -fsSL https://raw.githubusercontent.com/thiennc/opencode-mcp-setup/main/index.js | node
```

### Option 2: bunx (if published to npm)
```bash
bunx @thiennc/opencode-mcp-setup
```

### Option 3: Download & Run
```bash
curl -fsSL -o setup-opencode.js https://raw.githubusercontent.com/thiennc/opencode-mcp-setup/main/index.js
node setup-opencode.js
```

## After Setup

1. **Add your model** in `~/.opencode/opencode.json`:
```json
"provider": {
  "openai": {
    "npm": "@ai-sdk/openai",
    "name": "OpenAI",
    "options": { "apiKey": "sk-your-key" },
    "models": { "gpt-4o": { "name": "GPT-4o" } }
  }
}
```

2. **Start using:**
```bash
cd your-project
opencode
```

## Safety Features

- ✅ **Won't overwrite** your existing config - backs up first
- ✅ **Cross-platform** — Linux, macOS, Windows
- ✅ **Idempotent** — run multiple times safely
- ✅ **No zai MCPs** — only gitnexus, context7, playwright, sequential-thinking

## Publish to npm (optional)

```bash
npm login
npm publish --access public
```

Then users can run: `bunx @thiennc/opencode-mcp-setup`
