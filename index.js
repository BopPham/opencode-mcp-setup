#!/usr/bin/env node
/**
 * OpenCode MCP Setup - Cross Platform (Linux, macOS, Windows)
 * Safe: Won't overwrite existing config without prompting
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const HOME = os.homedir();
const OPENCODE_DIR = path.join(HOME, '.opencode');
const BACKUP_DIR = path.join(HOME, '.opencode-backup');

// Colors for terminal output
const GREEN = '\x1b[32m';
const BLUE = '\x1b[34m';
const YELLOW = '\x1b[33m';
const RED = '\x1b[31m';
const NC = '\x1b[0m';

function log_info(msg) { console.log(`${BLUE}[INFO]${NC} ${msg}`); }
function log_success(msg) { console.log(`${GREEN}[OK]${NC} ${msg}`); }
function log_warn(msg) { console.log(`${YELLOW}[WARN]${NC} ${msg}`); }
function log_error(msg) { console.log(`${RED}[ERROR]${NC} ${msg}`); }

// ============================================
// SAFETY: Check existing config
// ============================================
function check_existing() {
    if (fs.existsSync(OPENCODE_DIR)) {
        log_warn(`Existing OpenCode config found at: ${OPENCODE_DIR}`);
        
        const opencodeJsonPath = path.join(OPENCODE_DIR, 'opencode.json');
        if (fs.existsSync(opencodeJsonPath)) {
            const existing = fs.readFileSync(opencodeJsonPath, 'utf8');
            log_warn('Existing opencode.json found. Will backup first.');
            return true;
        }
    }
    return false;
}

function backup_existing() {
    if (!fs.existsSync(OPENCODE_DIR)) return;
    
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupPath = `${BACKUP_DIR}-${timestamp}`;
    
    log_info(`Backing up existing config to: ${backupPath}`);
    
    if (process.platform === 'win32') {
        // Windows: use robocopy or xcopy
        try {
            execSync(`xcopy "${OPENCODE_DIR}" "${backupPath}" /E /I /H`, { stdio: 'ignore' });
        } catch {
            // Fallback: manual copy
            copyRecursive(OPENCODE_DIR, backupPath);
        }
    } else {
        // Linux/macOS: use cp -r
        execSync(`cp -r "${OPENCODE_DIR}" "${backupPath}"`, { stdio: 'ignore' });
    }
    
    log_success(`Backup created: ${backupPath}`);
}

function copyRecursive(src, dest) {
    fs.mkdirSync(dest, { recursive: true });
    const entries = fs.readdirSync(src, { withFileTypes: true });
    
    for (const entry of entries) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);
        
        if (entry.isDirectory()) {
            copyRecursive(srcPath, destPath);
        } else {
            fs.copyFileSync(srcPath, destPath);
        }
    }
}

// ============================================
// 1. Check & Install Bun
// ============================================
function install_bun() {
    log_info('Checking Bun installation...');
    
    try {
        const version = execSync('bun --version', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }).trim();
        log_success(`Bun already installed: v${version}`);
        return;
    } catch {
        // Bun not found
    }
    
    log_warn('Bun not found. Installing Bun...');
    
    try {
        if (process.platform === 'win32') {
            // Windows
            execSync('powershell -c "irm bun.sh/install.ps1 | iex"', { stdio: 'inherit' });
        } else {
            // Linux/macOS
            execSync('curl -fsSL https://bun.sh/install | bash', { stdio: 'inherit' });
        }
        
        // Source bun for current session
        const bunPaths = [
            path.join(HOME, '.bun', 'bin', 'bun'),
            path.join(HOME, '.bun', 'bin'),
        ];
        
        for (const p of bunPaths) {
            if (fs.existsSync(p)) {
                process.env.PATH = `${path.dirname(p)}${path.delimiter}${process.env.PATH}`;
                break;
            }
        }
        
        const version = execSync('bun --version', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }).trim();
        log_success(`Bun installed: v${version}`);
    } catch (e) {
        log_error(`Bun installation failed: ${e.message}`);
        log_info('Please install manually: https://bun.sh');
        process.exit(1);
    }
}

// ============================================
// 2. Check & Install Node.js
// ============================================
function install_nodejs() {
    log_info('Checking Node.js installation...');
    
    try {
        const version = execSync('node --version', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }).trim();
        log_success(`Node.js already installed: ${version}`);
        return;
    } catch {
        log_warn('Node.js not found. Please install Node.js for MCP servers to work.');
        log_info('Download from: https://nodejs.org');
    }
}

// ============================================
// 3. Install OpenCode CLI
// ============================================
function install_opencode() {
    log_info('Checking OpenCode CLI...');
    
    try {
        const version = execSync('opencode --version', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }).trim();
        log_success(`OpenCode already installed: ${version}`);
        return;
    } catch {
        // Not installed
    }
    
    log_warn('OpenCode not found. Installing...');
    
    try {
        execSync('bun install -g @opencode-ai/cli', { stdio: 'inherit' });
        
        // Verify
        execSync('opencode --version', { stdio: ['pipe', 'pipe', 'ignore'] });
        log_success('OpenCode installed successfully');
    } catch (e) {
        log_error(`OpenCode installation failed: ${e.message}`);
        process.exit(1);
    }
}

// ============================================
// 4. Create Directory Structure
// ============================================
function setup_directories() {
    log_info('Creating OpenCode directory structure...');
    
    const dirs = [
        'agents',
        'agents-backup',
        'commands/agents',
        'memory/projects',
        'plugins',
        'rules/common',
        'rules/typescript',
        'rules/python',
        'rules/golang',
        'rules/rust',
        'rules/java',
        'rules/kotlin',
        'rules/php',
        'rules/swift',
        'rules/cpp',
        'rules/csharp',
        'rules/perl',
        'rules/zh',
        'skills',
        'bin',
    ];
    
    for (const dir of dirs) {
        fs.mkdirSync(path.join(OPENCODE_DIR, dir), { recursive: true });
    }
    
    log_success('Directory structure created');
}

// ============================================
// 5. Create opencode.json (MCPs only, no providers)
// ============================================
function setup_opencode_config() {
    log_info('Creating opencode.json configuration...');
    
    const config = {
        $schema: 'https://opencode.ai/config.json',
        instructions: [
            '~/.opencode/rules/common/token-budget.md',
            '~/.opencode/rules/common/lazy-mcp.md',
            '~/.opencode/rules/common/goal-hint-search.md',
            '~/.opencode/rules/common/mandatory-codebase-search.md',
            '~/.opencode/rules/global.md',
        ],
        plugin: ['opencode-mem', '@mohak34/opencode-notifier@latest'],
        provider: {},
        mcp: {
            gitnexus: {
                type: 'local',
                command: ['gitnexus', 'mcp'],
            },
            context7: {
                type: 'local',
                command: ['npx', '-y', '@upstash/context7-mcp'],
            },
            playwright: {
                type: 'local',
                command: ['npx', '-y', '@playwright/mcp'],
            },
            'sequential-thinking': {
                type: 'local',
                command: ['npx', '-y', '@modelcontextprotocol/server-sequential-thinking'],
            },
        },
        mode: {
            build: {
                disable: true,
            },
        },
        compaction: {
            auto: true,
            prune: true,
            reserved: 20000,
        },
        command: {
            compact: {
                description: 'Enhanced compact summary',
                subtask: true,
                agent: 'planner',
                template: 'Create a high-signal compact summary of this session for continuation. Focus on:\n1) Current objective and scope\n2) Key decisions made and why\n3) Concrete code changes done (files/functions)\n4) Remaining TODOs in priority order\n5) Known risks/assumptions\n6) Exact next action to continue\n\nKeep it concise, structured, and continuation-ready.',
            },
            'enhance-prompt': {
                description: 'Enhance a prompt for OpenCode',
                subtask: true,
                agent: 'planner',
                template: 'You are a prompt optimizer for OpenCode. Improve the user\'s raw prompt below for maximum execution quality.\n\nRaw prompt:\n$ARGUMENTS\n\nReturn exactly these sections:\n1) Optimized Prompt (ready to paste)\n2) Missing Context (bullet list)\n3) Clarifying Questions (only essential)\n4) Execution Checklist (step-by-step)\n5) Short Version (1-2 lines)\n\nIf input is empty, ask user to provide prompt text.',
            },
            'enhance-promtp': {
                description: 'Alias typo: enhance prompt',
                subtask: true,
                agent: 'planner',
                template: 'You are a prompt optimizer for OpenCode. Improve the user\'s raw prompt below for maximum execution quality.\n\nRaw prompt:\n$ARGUMENTS\n\nReturn exactly these sections:\n1) Optimized Prompt (ready to paste)\n2) Missing Context (bullet list)\n3) Clarifying Questions (only essential)\n4) Execution Checklist (step-by-step)\n5) Short Version (1-2 lines)\n\nIf input is empty, ask user to provide prompt text.',
            },
        },
    };
    
    const configPath = path.join(OPENCODE_DIR, 'opencode.json');
    
    // Safety: Don't overwrite existing config
    if (fs.existsSync(configPath)) {
        log_warn('opencode.json already exists. Skipping creation.');
        log_info('Your existing config is preserved. MCPs need to be added manually if missing.');
        return;
    }
    
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    log_success('opencode.json created (4 MCPs: gitnexus, context7, playwright, sequential-thinking)');
}

// ============================================
// 6. Create Agents
// ============================================
function setup_agents() {
    log_info('Creating agent configurations...');
    
    const agentsDir = path.join(OPENCODE_DIR, 'agents');
    
    // Safety: Don't overwrite existing agents
    const existingAgents = fs.readdirSync(agentsDir).filter(f => f.endsWith('.md'));
    if (existingAgents.length > 0) {
        log_warn(`Found existing agents: ${existingAgents.join(', ')}`);
        log_info('Skipping agent creation to preserve your existing config.');
        return;
    }
    
    const orchestrator = `---
name: "orchestrator"
description: "Plan + route + dispatch. Uses ALL agents, skills, and MCPs available."
---

# Orchestrator - Full Stack Dispatcher

## All Agents (dispatch via Task tool)

| subagent_type | Use When |
|---------------|----------|
| \`coder\` | Implement code, fix bugs, apply review fixes |
| \`review\` | Code review, PR review, security audit |
| \`bug-finder\` | Diagnose errors, root cause analysis |
| \`uiux\` | UI/UX planning, design skeleton, wireframe |
| \`explore\` | Find files, search code, understand architecture |
| \`general\` | Multi-step research, parallel ops, complex tasks |
| \`commit\` | Git commit with safety checks |
| \`fix\` | Apply fixes from review report |
| \`designmd\` | Apply DESIGN.md templates |

## Key Skills (invoke via skill tool)

### Flutter / Mobile
| Skill | Trigger |
|-------|---------|
| \`flutter-patterns\` | Clean Architecture, Riverpod, BLoC, feature implementation |
| \`flutter-testing\` | Widget test, bloc_test, unit test, coverage |
| \`flutter-tdd\` | RED-GREEN-REFACTOR cycle |
| \`flutter-state-management\` | Riverpod vs BLoC decision, hybrid approach |
| \`flutter-performance\` | Rebuild optimization, list rendering, app size |
| \`flutter-dart-code-review\` | Full Flutter/Dart review checklist |

### General Engineering
| Skill | Trigger |
|-------|---------|
| \`feat\` / \`fix\` / \`chore\` / \`refactor\` | Plan + implement changes |
| \`codex-impl-review\` / \`codex-pr-review\` | Peer review via debate |
| \`codex-security-review\` | Security audit (OWASP) |
| \`tdd-workflow\` | Test-driven development |
| \`blueprint\` | Multi-session plan |
| \`explain\` | Explain code to user |
| \`security-review\` | Security checklist |
| \`benchmark\` / \`perf\` | Performance |
| \`api-design\` | REST API patterns |

## MCP Stack

### Primary: gitnexus

Luôn gọi **gitnexus trước** để lấy code context:
- \`gitnexus\` → code graph, call chain, impact analysis, process flows

### Full MCP Table

| MCP | Purpose | Fallback |
|-----|---------|----------|
| \`gitnexus\` | **Luôn gọi trước** — code graph + semantic search | \`grep\` + \`glob\` + \`read\` |
| \`context7\` | Framework/library docs | Manual docs lookup |
| \`sequential-thinking\` | Complex tradeoffs | Step-by-step analysis |
| \`playwright\` | UI validation | Manual testing |

### MCP Rules
1. **gitnexus luôn gọi trước** — code context phong phú nhất
2. **MCP lỗi → fallback + CHẠY TIẾP** — không dừng, không block workflow
3. **Timeout 5s** → chuyển fallback ngay
4. **Báo user ngắn gọn**: "⚠️ {mcp} lỗi, dùng {fallback}" rồi tiếp tục

## Route Table

| User says | Route |
|-----------|-------|
| implement/add/create feature | → \`coder\` → **ask "commit?"** |
| fix bug | → \`bug-finder\` → \`coder\` → **ask "commit?"** |
| review / check PR | → \`review\` → \`coder\` → **ask "commit?"** |
| UI/UX / design screen | → \`uiux\` plan → \`coder\` → **ask "commit?"** |
| explain how X works | → \`explain\` skill |
| security check | → \`codex-security-review\` skill |
| TDD / write tests | → \`tdd-workflow\` skill → \`coder\` |

**COMMIT RULE:** Khi task xong, hỏi user "Cần commit không?" nhưng **KHÔNG tự commit**.

## Complex Task Phase Flow

\`\`\`
P0: gitnexus → context
P1: 2-3 options with tradeoffs → user picks
P2: task breakdown + agent + skill assignments
P3: wave dispatch (max parallel)
\`\`\`

## Rules

- gitnexus **always first**
- Use skill tool for domain workflows
- Call \`uiux\` for any UI task before \`coder\`
- Call \`bug-finder\` for any error before \`coder\`
- Max parallel: independent tasks same wave
- Warn on HIGH/CRITICAL impact
- Context >80% → suggest compact
- **KHÔNG tự commit** — hỏi user trước
`;

    const coder = `# Coder Agent - Implementation & Fix

Mã code mới và apply fix từ review report.

## Mode Detection
- **Normal mode**: User asks to implement/fix/create → code directly
- **Review-fix mode**: User provides review report → read report, apply ISSUE blocks

## Workflow - Normal Mode
1. **ANALYZE** - Read existing code, identify files (gitnexus mandatory)
2. **PLAN** - Numbered steps, edge cases
3. **EXECUTE** - Write code following plan
4. **VERIFY** - Build passes? Patterns followed?

## MCP Strategy

| MCP | When to Use |
|-----|-------------|
| \`gitnexus\` | **MANDATORY first** - code context, impact analysis |
| \`context7\` | Framework/library/API docs when uncertain |
| \`sequential-thinking\` | Complex logic, architecture decisions |
| \`playwright\` | UI behavior verification |

## MUST
- Read existing code BEFORE writing
- Run \`gitnexus_impact\` before modifying any symbol
- Follow project patterns exactly
- Explicit types (no \`any\`)
- Handle all errors
- Functions <50 lines, files <200 lines

## MUST NOT
- Invent new patterns
- Add features beyond scope
- Leave TODOs
`;

    const review = `---
name: "review"
description: "Read-only code review agent"
---

# Review Agent - Read-Only Code Review

## Mission
Review code changes in read-only mode. Save findings to Markdown report.

## Hard Guardrails
- **Read-only**: never edit application code
- No git write actions
- File write allowed only for review artifacts (\`.md\` report files)

## Review Modes
- \`working-tree\` (default): review staged + unstaged changes
- \`branch\`: review \`base...HEAD\`
- \`single-file\`: review one file

## MCP Strategy
| MCP | When to Use |
|-----|-------------|
| \`gitnexus\` | **MANDATORY first** - map impacted symbols |
| \`context7\` | External framework/library behavior |
| \`sequential-thinking\` | Complex findings |
| \`playwright\` | UI behavior validation |

## Required Output Format
\`\`\`markdown
### ISSUE-{N}: {title}
- Category: bug | edge-case | security | performance | maintainability
- Severity: low | medium | high | critical
- Confidence: low | medium | high
- Location: {file:line}
- Problem: {what is wrong}
- Suggested fix: {implementation guidance}
\`\`\`

## Report File
Default: \`reports/review/review-{YYYYMMDD-HHMMSS}.md\`
`;

    const commit = `---
name: "commit"
description: "Git commit agent"
---

# Git Commit Agent

## Trigger
- \`/commit\`

## Workflow

1. **Get changes** - \`git diff\` + \`git diff --staged\`
2. **Security check** - No secrets, env files, credentials
3. **Impact check** - \`gitnexus_detect_changes()\` **MANDATORY**
4. **Group changes** - Separate unrelated changes
5. **Commit** - \`git commit -m "<type>: <message>"\`

## Allowed Commit Types
- \`feat\` — new feature
- \`fix\` — bug fix
- \`docs\` — documentation
- \`style\` — formatting
- \`test\` — tests
- \`chore\` — maintenance
- \`refactor\` — restructuring
- \`perf\` — performance

## Rules
- Never commit secrets or env files
- Prefer multiple focused commits
- Keep messages under 72 characters
`;

    fs.writeFileSync(path.join(agentsDir, 'orchestrator.md'), orchestrator);
    fs.writeFileSync(path.join(agentsDir, 'coder.md'), coder);
    fs.writeFileSync(path.join(agentsDir, 'review.md'), review);
    fs.writeFileSync(path.join(agentsDir, 'commit.md'), commit);
    
    log_success('4 agents created (orchestrator, coder, review, commit)');
}

// ============================================
// 7. Create Rules
// ============================================
function setup_rules() {
    log_info('Creating rules...');
    
    const rulesDir = path.join(OPENCODE_DIR, 'rules');
    
    // Safety: Check if rules exist
    const globalPath = path.join(rulesDir, 'global.md');
    if (fs.existsSync(globalPath)) {
        log_warn('Existing rules found. Skipping rule creation to preserve your config.');
        return;
    }
    
    const global = `# Global Rules - OpenCode

**Token Budget**: See \`rules/common/token-budget.md\`
**MCP Invocation**: See \`rules/common/lazy-mcp.md\`

## Core Principles
1. **Reuse First** — Search existing code/libs before writing new
2. **Agent-First** — Delegate to Task tool specialists
3. **Test-Driven** — Write tests first, 80%+ coverage
4. **Security-First** — Validate all inputs
5. **Immutability** — New objects, never mutate
6. **Plan Before Execute** — Use Plan mode for complex features
7. **Planner Is Read-Only**

## MCP-First Gate (MANDATORY)
For every coding/debug/review/planning task:
1. Start with \`gitnexus\` MCP
2. Use others as needed (\`context7\`, \`sequential-thinking\`, \`playwright\`)
3. Fallback only when MCP insufficient

## Development Workflow
1. **Plan First**
2. **TDD Approach** — RED → GREEN → REFACTOR
3. **Code Review**
4. **Commit & Push** — Conventional commits

## Coding Standards
- Functions <50 lines
- Files <800 lines
- No deep nesting >4 levels
- No hardcoded values
- No mutation

## Security Guidelines
Before ANY Commit:
- [ ] No hardcoded secrets
- [ ] All inputs validated
- [ ] SQL injection prevention
- [ ] XSS prevention

## Testing Requirements
- Minimum Coverage: 80%
- Unit + Integration + E2E

## Git Workflow
Format: \`<type>: <description>\`
Types: feat, fix, refactor, docs, test, chore, perf, ci
`;

    const tokenBudget = `---
name: "token-budget"
description: "Token budget management"
---

# Token Budget Management

## Core Principle
**Context is not free.** Optimize proactively.

## Budget Thresholds

| Context % | Action |
|----------|--------|
| < 40% | Normal |
| 40-60% | Begin context hygiene |
| 60-80% | Suggest new session |
| > 80% | Critical: wrap up |
| > 90% | Emergency only |

## MCP Lazy Invocation
**KHÔNG gọi tất cả MCPs mỗi câu hỏi.**

| Question Type | MCPs Needed |
|---------------|-------------|
| Trivial | NONE |
| Code Search | gitnexus |
| Library/Framework | context7 only |
| Complex Logic | gitnexus + sequential-thinking |

**ALWAYS search:** Security ops, DB modifications, auth changes
**NEVER search:** Path + line provided, trivial edits
`;

    const lazyMcp = `---
name: "lazy-mcp"
description: "MCP-first invocation"
---

# MCP-First Invocation

## Core Rule
Use MCP tools first. Fallback to non-MCP only when MCP cannot provide enough context.

## Mandatory Order
1. **GitNexus** first
2. Add by need: context7, sequential-thinking, playwright
3. Fallback: grep/glob/read

## Codebase Search Gate
- Always call gitnexus before editing
- Include goal-directed query
- Retry with narrower query before fallback

## Do Not
- Skip MCP for convenience
- Start with plain grep/find
- Use fallback silently
`;

    const goalHint = `---
name: "goal-hint-search"
description: "Goal-directed code search"
---

# Goal-Directed Code Search

## Template
\`\`\`
SEARCH FOR: [what you need]
GOAL HINT: [specific question being answered]
\`\`\`

## Example
❌ BAD: Find auth files
✅ GOOD: Find auth middleware. Need JWT validation flow for refresh token.

## Token Savings Target: 50-70% reduction
`;

    const mandatorySearch = `---
name: "mandatory-codebase-search"
description: "Bắt buộc dùng GitNexus"
---

# Mandatory Codebase Search

## Rule
LUÔN sử dụng \`gitnexus\` MCP làm công cụ đầu tiên.

## Không được phép
- Dùng grep/find/cat làm bước đầu tiên
- Đọc toàn bộ file lớn không cần thiết

## Được phép (fallback)
- \`grep\`: Sau khi MCP xác định vị trí
- \`read\`: Với offset/limit
- \`Glob\`: Khi MCP không khả dụng
`;

    fs.writeFileSync(path.join(rulesDir, 'global.md'), global);
    fs.writeFileSync(path.join(rulesDir, 'common', 'token-budget.md'), tokenBudget);
    fs.writeFileSync(path.join(rulesDir, 'common', 'lazy-mcp.md'), lazyMcp);
    fs.writeFileSync(path.join(rulesDir, 'common', 'goal-hint-search.md'), goalHint);
    fs.writeFileSync(path.join(rulesDir, 'common', 'mandatory-codebase-search.md'), mandatorySearch);
    
    log_success('Rules created');
}

// ============================================
// 8. Create package.json for OpenCode
// ============================================
function setup_package_json() {
    const pkgPath = path.join(OPENCODE_DIR, 'package.json');
    
    if (fs.existsSync(pkgPath)) {
        log_warn('package.json already exists. Skipping.');
        return;
    }
    
    const pkg = {
        type: 'module',
        dependencies: {
            '@kilocode/plugin': '7.2.14',
            '@opencode-ai/plugin': '1.4.6',
            'opencode-mem': '^2.13.0',
        },
    };
    
    fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));
    log_success('package.json created');
}

// ============================================
// 9. Create Plugin
// ============================================
function setup_plugin() {
    const pluginPath = path.join(OPENCODE_DIR, 'plugins', 'auto-save-memory.ts');
    
    if (fs.existsSync(pluginPath)) {
        log_warn('auto-save-memory.ts already exists. Skipping.');
        return;
    }
    
    const plugin = `import type { Plugin } from "@opencode-ai/plugin"

interface SessionState {
  filesModified: string[]
  decisions: { what: string; why: string }[]
  nextSteps: string[]
  blockers: string[]
  summary: string
  project: string
}

const sessions = new Map<string, SessionState>()
const MEMORY_DIR = process.env.HOME + "/.opencode/memory/projects"

function getState(sessionId: string): SessionState {
  let state = sessions.get(sessionId)
  if (!state) {
    state = {
      filesModified: [],
      decisions: [],
      nextSteps: [],
      blockers: [],
      summary: "",
      project: "unknown",
    }
    sessions.set(sessionId, state)
  }
  return state
}

async function saveMemory(state: SessionState) {
  const fs = await import("fs/promises")
  const path = await import("path")
  await fs.mkdir(MEMORY_DIR, { recursive: true })

  const memory = {
    project: state.project,
    lastSession: new Date().toISOString(),
    summary: state.summary || "Session in progress",
    leftOff: state.summary,
    nextSteps: [...new Set(state.nextSteps)],
    decisions: state.decisions,
    blockers: state.blockers,
    filesModified: [...new Set(state.filesModified)],
  }

  const filePath = path.join(MEMORY_DIR, \`\${state.project}.json\`)
  await fs.writeFile(filePath, JSON.stringify(memory, null, 2))
}

function trackToolUsage(state: SessionState, tool: string, args: any) {
  if (tool === "edit" || tool === "write") {
    const filePath = args?.filePath as string
    if (filePath && !state.filesModified.includes(filePath)) {
      state.filesModified.push(filePath)
    }
  }
  if (tool === "bash") {
    const cmd = args?.command as string
    if (/git\\s+commit/.test(cmd)) {
      state.decisions.push({
        what: \`Committed: \${cmd.slice(0, 100)}\`,
        why: "Code change committed to git",
      })
    }
  }
}

export const AutoSaveMemory: Plugin = async ({ client }) => {
  return {
    event: async ({ event }) => {
      const sessionId = event.session_id || event.sessionID
      if (!sessionId) return

      const state = getState(sessionId)

      if (event.type === "session.created") {
        const cwd = event.properties?.cwd || process.cwd()
        state.project = cwd.split("/").pop() || "unknown"
      }

      if (event.type === "tool.execute.after") {
        trackToolUsage(state, (event as any).tool, (event as any).args || {})
      }

      if (event.type === "session.idle" && state.filesModified.length > 0) {
        state.summary = \`Modified \${state.filesModified.length} file(s)\`
        await saveMemory(state)
      }

      if (event.type === "session.deleted") {
        if (state.filesModified.length > 0 || state.decisions.length > 0) {
          await saveMemory(state)
        }
        sessions.delete(sessionId)
      }
    },
  }
}
`;

    fs.writeFileSync(pluginPath, plugin);
    log_success('Plugin created');
}

// ============================================
// 10. Install MCP Servers
// ============================================
function setup_mcp_servers() {
    log_info('Installing MCP servers...');
    
    // GitNexus
    try {
        execSync('gitnexus --version', { stdio: ['pipe', 'pipe', 'ignore'] });
        log_success('GitNexus already installed');
    } catch {
        log_info('Installing GitNexus...');
        try {
            execSync('bun install -g gitnexus', { stdio: 'inherit' });
            log_success('GitNexus installed');
        } catch {
            log_warn('Failed to install GitNexus globally. Install manually: bun install -g gitnexus');
        }
    }
    
    // Other MCPs (installed via npx on demand)
    log_info('Other MCPs (context7, playwright, sequential-thinking) will be installed via npx on first use');
    log_success('MCP servers configured');
}

// ============================================
// 11. Install Dependencies
// ============================================
function install_dependencies() {
    log_info('Installing OpenCode dependencies...');
    
    try {
        process.chdir(OPENCODE_DIR);
        execSync('bun install', { stdio: 'inherit' });
        log_success('Dependencies installed');
    } catch {
        log_warn('Failed to install dependencies. Run "bun install" in ~/.opencode manually.');
    }
}

// ============================================
// 12. Create .gitignore
// ============================================
function setup_gitignore() {
    const gitignorePath = path.join(OPENCODE_DIR, '.gitignore');
    if (!fs.existsSync(gitignorePath)) {
        fs.writeFileSync(gitignorePath, 'node_modules/\n*.log\n.DS_Store\n');
    }
}

// ============================================
// MAIN
// ============================================
function main() {
    console.log('==========================================');
    console.log('  OpenCode MCP Setup (Cross-Platform)');
    console.log('  MCPs: gitnexus, context7, playwright,');
    console.log('        sequential-thinking');
    console.log('==========================================');
    console.log();
    
    const hasExisting = check_existing();
    if (hasExisting) {
        backup_existing();
    }
    
    install_bun();
    install_nodejs();
    install_opencode();
    setup_directories();
    setup_opencode_config();
    setup_agents();
    setup_rules();
    setup_package_json();
    setup_plugin();
    setup_gitignore();
    setup_mcp_servers();
    install_dependencies();
    
    console.log();
    console.log('==========================================');
    console.log(`${GREEN}✅ OpenCode Setup Complete!${NC}`);
    console.log('==========================================');
    console.log();
    console.log('1. Add your model/provider in ~/.opencode/opencode.json');
    console.log('2. Start using: cd your-project && opencode');
    console.log();
}

main();
