#!/bin/bash
set -e

# ============================================
# OpenCode MCP Setup Script
# Auto-install Bun + OpenCode + 4 MCPs + Agents + Rules
# MCPs: gitnexus, context7, playwright, sequential-thinking
# No model/provider config - user adds manually if needed
# No zai/zread/web-search/web-reader MCPs
# ============================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

OPENCODE_DIR="$HOME/.opencode"

# ============================================
# 1. Check & Install Bun
# ============================================
install_bun() {
    log_info "Checking Bun installation..."
    if command -v bun &> /dev/null; then
        BUN_VERSION=$(bun --version)
        log_success "Bun already installed: v$BUN_VERSION"
        return
    fi

    log_warn "Bun not found. Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    
    # Source bun for current session
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    if command -v bun &> /dev/null; then
        BUN_VERSION=$(bun --version)
        log_success "Bun installed: v$BUN_VERSION"
    else
        log_error "Bun installation failed. Please install manually: https://bun.sh"
        exit 1
    fi
}

# ============================================
# 2. Check & Install Node.js (fallback for npx)
# ============================================
install_nodejs() {
    log_info "Checking Node.js installation..."
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log_success "Node.js already installed: $NODE_VERSION"
    else
        log_warn "Node.js not found. Installing via Bun..."
        bun install -g node
        if command -v node &> /dev/null; then
            log_success "Node.js installed via Bun"
        else
            log_warn "Please install Node.js manually for MCP servers"
        fi
    fi
}

# ============================================
# 3. Install OpenCode CLI
# ============================================
install_opencode() {
    log_info "Checking OpenCode CLI..."
    if command -v opencode &> /dev/null; then
        OPENCODE_VERSION=$(opencode --version 2>/dev/null || echo "unknown")
        log_success "OpenCode already installed: $OPENCODE_VERSION"
        return
    fi

    log_warn "OpenCode not found. Installing..."
    
    # Try bun first, fallback to npm
    if command -v bun &> /dev/null; then
        bun install -g @opencode-ai/cli
    else
        npm install -g @opencode-ai/cli
    fi
    
    if command -v opencode &> /dev/null; then
        log_success "OpenCode installed successfully"
    else
        log_error "OpenCode installation failed"
        exit 1
    fi
}

# ============================================
# 4. Create Directory Structure
# ============================================
setup_directories() {
    log_info "Creating OpenCode directory structure..."
    
    mkdir -p "$OPENCODE_DIR"/{agents,agents-backup,commands/agents,memory/projects,plugins,rules/common,rules/{typescript,python,golang,rust,java,kotlin,php,swift,cpp,csharp,perl,zh},skills,bin}
    
    log_success "Directory structure created"
}

# ============================================
# 5. Create opencode.json (without API keys)
# ============================================
setup_opencode_config() {
    log_info "Creating opencode.json configuration..."
    
    cat > "$OPENCODE_DIR/opencode.json" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "~/.opencode/rules/common/token-budget.md",
    "~/.opencode/rules/common/lazy-mcp.md",
    "~/.opencode/rules/common/goal-hint-search.md",
    "~/.opencode/rules/common/mandatory-codebase-search.md",
    "~/.opencode/rules/global.md"
  ],
  "plugin": [
    "opencode-mem",
    "@mohak34/opencode-notifier@latest"
  ],
  "mcp": {
    "gitnexus": {
      "type": "local",
      "command": ["gitnexus", "mcp"]
    },
    "context7": {
      "type": "local",
      "command": ["npx", "-y", "@upstash/context7-mcp"]
    },
    "playwright": {
      "type": "local",
      "command": ["npx", "-y", "@playwright/mcp"]
    },
    "sequential-thinking": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
  },
  "mode": {
    "build": {
      "disable": true
    }
  },
  "compaction": {
    "auto": true,
    "prune": true,
    "reserved": 20000
  },
  "command": {
    "compact": {
      "description": "Enhanced compact summary",
      "subtask": true,
      "agent": "planner",
      "template": "Create a high-signal compact summary of this session for continuation. Focus on:\n1) Current objective and scope\n2) Key decisions made and why\n3) Concrete code changes done (files/functions)\n4) Remaining TODOs in priority order\n5) Known risks/assumptions\n6) Exact next action to continue\n\nKeep it concise, structured, and continuation-ready."
    },
    "enhance-prompt": {
      "description": "Enhance a prompt for OpenCode",
      "subtask": true,
      "agent": "planner",
      "template": "You are a prompt optimizer for OpenCode. Improve the user's raw prompt below for maximum execution quality.\n\nRaw prompt:\n$ARGUMENTS\n\nReturn exactly these sections:\n1) Optimized Prompt (ready to paste)\n2) Missing Context (bullet list)\n3) Clarifying Questions (only essential)\n4) Execution Checklist (step-by-step)\n5) Short Version (1-2 lines)\n\nIf input is empty, ask user to provide prompt text."
    },
    "enhance-promtp": {
      "description": "Alias typo: enhance prompt",
      "subtask": true,
      "agent": "planner",
      "template": "You are a prompt optimizer for OpenCode. Improve the user's raw prompt below for maximum execution quality.\n\nRaw prompt:\n$ARGUMENTS\n\nReturn exactly these sections:\n1) Optimized Prompt (ready to paste)\n2) Missing Context (bullet list)\n3) Clarifying Questions (only essential)\n4) Execution Checklist (step-by-step)\n5) Short Version (1-2 lines)\n\nIf input is empty, ask user to provide prompt text."
    }
  }
}
EOF

    log_success "opencode.json created (4 MCPs: gitnexus, context7, playwright, sequential-thinking)"
}

# ============================================
# 6. Create Agents
# ============================================
setup_agents() {
    log_info "Creating agent configurations..."

    # Orchestrator Agent
    cat > "$OPENCODE_DIR/agents/orchestrator.md" << 'EOF'
---
name: "orchestrator"
description: "Plan + route + dispatch. Uses ALL agents, skills, and MCPs available."
---

# Orchestrator - Full Stack Dispatcher

## All Agents (dispatch via Task tool)

| subagent_type | Use When |
|---------------|----------|
| `coder` | Implement code, fix bugs, apply review fixes |
| `review` | Code review, PR review, security audit |
| `bug-finder` | Diagnose errors, root cause analysis |
| `uiux` | UI/UX planning, design skeleton, wireframe |
| `explore` | Find files, search code, understand architecture |
| `general` | Multi-step research, parallel ops, complex tasks |
| `commit` | Git commit with safety checks |
| `fix` | Apply fixes from review report |
| `designmd` | Apply DESIGN.md templates |

## Key Skills (invoke via skill tool)

### Flutter / Mobile
| Skill | Trigger |
|-------|---------|
| `flutter-patterns` | Clean Architecture, Riverpod, BLoC, feature implementation |
| `flutter-testing` | Widget test, bloc_test, unit test, coverage |
| `flutter-tdd` | RED-GREEN-REFACTOR cycle |
| `flutter-state-management` | Riverpod vs BLoC decision, hybrid approach |
| `flutter-performance` | Rebuild optimization, list rendering, app size |
| `flutter-dart-code-review` | Full Flutter/Dart review checklist |

### Auth / Mobile Flows
| Flow | Skill combo |
|------|-------------|
| Login / Register / OTP | `security-review` + `flutter-patterns` + `coder` |
| Social login (Google, Apple, FB) | `security-review` + `flutter-patterns` + `coder` |
| Auth token / refresh token | `security-review` + `api-design` + `coder` |
| Deep link / URL scheme | `flutter-patterns` + `coder` |
| Push notification | `flutter-patterns` + `coder` |
| Payment / IAP | `security-review` + `flutter-patterns` + `coder` |

### General Engineering
| Skill | Trigger |
|-------|---------|
| `feat` / `fix` / `chore` / `refactor` | Plan + implement changes |
| `codex-impl-review` / `codex-pr-review` | Peer review via debate |
| `codex-security-review` | Security audit (OWASP) |
| `tdd-workflow` | Test-driven development |
| `blueprint` | Multi-session plan |
| `browser` / `browser-qa` | Browser automation |
| `explain` | Explain code to user |
| `security-review` | Security checklist |
| `benchmark` / `perf` | Performance |
| `api-design` | REST API patterns |

## MCP Stack

### Primary: gitnexus (chạy SONG SONG với codebase tools)

Luôn gọi **gitnexus trước** để lấy code context phong phú nhất:
- `gitnexus` → code graph, call chain, impact analysis, process flows

### Full MCP Table

| MCP | Purpose | Fallback (chạy tiếp, không dừng) |
|-----|---------|----------------------------------|
| `gitnexus` | **Luôn gọi trước** — code graph + semantic search | `grep` + `glob` + `read` |
| `context7` | Framework/library docs | Tự tra docs/manual |
| `sequential-thinking` | Complex tradeoffs | Tự phân tích step-by-step |
| `playwright` | UI validation | `read` screenshot URL |

### MCP Rules
1. **gitnexus + auggie luôn gọi cùng lúc** — merge kết quả cho coverage tối đa
2. **MCP lỗi → fallback + CHẠY TIẾP** — không dừng, không block workflow
3. **Timeout 5s** → chuyển fallback ngay, không chờ treo
4. **Báo user ngắn gọn**: "⚠️ {mcp} lỗi, dùng {fallback}" rồi tiếp tục
5. **Fallback cuối cùng**: `grep` + `glob` + `read` — luôn available

## Route Table

| User says | Route |
|-----------|-------|
| implement/add/create feature | → `coder` → **ask "commit?"** |
| fix bug | → `bug-finder` → `coder` → **ask "commit?"** |
| fix from review report | → `coder` (review-fix mode) → **ask "commit?"** |
| review / check PR | → `review` → `coder` → **ask "commit?"** |
| UI/UX / design screen | → `uiux` plan → `coder` → **ask "commit?"** |
| explain how X works | → `explain` skill |
| security check | → `codex-security-review` skill |
| research topic | → `deep-research` skill |
| benchmark / performance | → `benchmark` or `perf` skill |
| TDD / write tests | → `tdd-workflow` skill → `coder` |
| complex multi-step | → Phase flow below |

**COMMIT RULE:** Khi task xong, hỏi user "Cần commit không?" nhưng **KHÔNG tự commit**. Đợi user nói mới gọi `commit`.

## Complex Task Phase Flow

```
P0: gitnexus → context
P1: 2-3 options with tradeoffs → user picks
P2: task breakdown + agent + skill assignments
P3: wave dispatch (max parallel)
```

Wave pattern:
```
W1: [explore] + [gitnexus]
W2: [bug-finder] + [review] + [uiux]  (as needed)
W3: [coder(impl)] + [coder(fix)]
W4: [commit]
```

## Dispatch Format

```
@{agent} | {objective} | files: {paths} | mcp: {which} | skill: {which} | verify: {how}
```

## Rules

- gitnexus **always first**
- Use skill tool for domain workflows (flutter, security, TDD, etc.)
- Call `uiux` for any UI task before `coder`
- Call `bug-finder` for any error before `coder`
- Max parallel: independent tasks same wave
- Warn on HIGH/CRITICAL impact
- `gitnexus_detect_changes()` when user asks to commit
- Context >80% → suggest compact
- **KHÔNG tự commit** — hỏi user trước, đợi user nói mới gọi `commit`
- Orchestrator **never edits code** — plans & dispatches only
EOF

    # Coder Agent
    cat > "$OPENCODE_DIR/agents/coder.md" << 'EOF'
# Coder Agent - Implementation & Fix

Mã code mới và apply fix từ review report. Một agent làm cả hai.

## Auto-Enhance Prompt Gate
Before coding, silently optimize the prompt for clarity, scope, and execution quality.
- Expand vague scope into concrete boundaries
- Add implicit success criteria
- Remove ambiguity

## Mode Detection
- **Normal mode**: User asks to implement/fix/create → code directly
- **Review-fix mode**: User provides review report path or says "fix from review" → read report, apply ISSUE blocks

---

## Workflow - Normal Mode
1. **ANALYZE** - Read existing code, identify files (gitnexus mandatory)
2. **PLAN** - Numbered steps, edge cases
3. **EXECUTE** - Write code following plan
4. **VERIFY** - Build passes? Patterns followed?

## Workflow - Review-Fix Mode
1. **LOAD** - Read review report, extract ISSUE-{N} blocks
2. **TRIAGE** - ACCEPT / SKIP / NEED_INFO per issue
3. **PLAN_FIX** - Order by severity: critical → high → medium → low
4. **APPLY** - Implement accepted fixes (gitnexus_impact mandatory before each)
5. **VERIFY** - Run tests/validation
6. **REPORT** - Write fix summary to `reports/fix/fix-{YYYYMMDD-HHMMSS}.md`

---

## MCP Strategy (All Available)

| MCP | When to Use |
|-----|-------------|
| `gitnexus` | **MANDATORY first** - code context, impact analysis, call graph, detect_changes |
| `context7` | Framework/library/API docs when uncertain |
| `sequential-thinking` | Complex logic, architecture decisions, root cause analysis |
| `playwright` | UI behavior verification |

---

## MUST
- Read existing code BEFORE writing
- Run `gitnexus_impact` before modifying any symbol
- Follow project patterns exactly
- Explicit types (no `any`)
- Handle all errors
- Functions <50 lines, files <200 lines
- Keep ISSUE-{N} IDs stable when in review-fix mode

## MUST NOT
- Invent new patterns
- Add features beyond scope
- Leave TODOs
- Output without planning
- Ignore critical/high issues in review-fix mode
EOF

    # Review Agent
    cat > "$OPENCODE_DIR/agents/review.md" << 'EOF'
# Review Agent - Read-Only Code Review

## Mission
Review code changes in read-only mode. Save findings to Markdown report for `fix` agent.

## Hard Guardrails
- **Read-only**: never edit application code, tests, configs, or docs under review
- No implementation actions: no fix loops, no apply_patch, no auto-refactor
- No git write actions: never stage, commit, amend, rebase, or push
- File write allowed only for review artifacts (`.md` report files)

## Auto-Enhance Prompt Gate
Before review, silently optimize scope clarity and success criteria.

## Review Modes
- `working-tree` (default): review staged + unstaged local changes
- `branch`: review `base...HEAD` when user requests branch-level review
- `single-file`: review one file when path is provided

## Workflow
| Phase | Action | Output |
|-------|--------|--------|
| 1. SCAN | Detect mode, collect file list + diff | Scope summary |
| 2. ANALYZE | Inspect correctness, regressions, edge cases, security, performance | ISSUE blocks |
| 3. VERIFY | Cross-check uncertain claims | Validated findings |
| 4. REPORT | Save findings to Markdown file | Report path + summary |

## MCP Strategy (All Available)
| MCP | When to Use |
|-----|-------------|
| `gitnexus` | **MANDATORY first** - map impacted symbols and nearby risk areas |
| `context7` | Issue depends on external framework/library behavior |
| `sequential-thinking` | Contradictory or complex findings |
| `playwright` | Optional UI behavior validation evidence |

## Required Output Format
```markdown
### ISSUE-{N}: {title}
- Category: bug | edge-case | security | performance | maintainability
- Severity: low | medium | high | critical
- Confidence: low | medium | high
- Location: {file:line}
- Problem: {what is wrong}
- Evidence: {diff/code evidence}
- Why it matters: {impact}
- Suggested fix: {implementation guidance}
- Suggested test: {how to verify after fix}
```

## Report File
Default: `reports/review/review-{YYYYMMDD-HHMMSS}.md`
Create directory if missing.

## Report Template
```markdown
# Review Report

## Metadata
- Mode: {working-tree|branch|single-file}
- Generated at: {timestamp}
- Files reviewed: {count}

## Executive Summary
- Overall risk: low | medium | high
- Total issues: {N}
- Critical/High: {count}

## Findings
{ISSUE blocks}

## Prioritized Fix Plan
1. {highest risk fix}

## Verification Checklist
- [ ] Re-run affected tests
- [ ] Add regression tests for high-risk issues
- [ ] Re-review changed files after fixes
```

## Must Do
- Keep findings actionable and evidence-based
- Return the report file path in final response

## Must Not Do
- Do not change source code
- Do not claim a fix was applied
- Do not skip report file creation
EOF

    # Commit Agent
    cat > "$OPENCODE_DIR/agents/commit.md" << 'EOF'
---
name: "commit"
description: "Agent assisting developers in committing based on current code changes. Triggered by /commit."
---

# Git Commit Agent

Help developers create clean, safe commits based on working tree changes.

## Trigger
- `/commit`

## MCP Strategy (All Available)
| MCP | When to Use |
|-----|-------------|
| `gitnexus` | `gitnexus_detect_changes()` **MANDATORY** before committing - verify change scope |
| `context7` | Not typically needed for commits |
| `sequential-thinking` | Complex change grouping decisions |

## Workflow

1. **Get changes**
   - Run `git --no-pager diff` to see unstaged changes
   - Run `git --no-pager diff --staged` to see staged changes
   - If no changes, stop: "No changes to commit."

2. **Security check**
   - Hardcoded API keys, passwords, tokens, secrets → **STOP, warn**
   - `.env`, `.env.*`, environment files → **STOP, warn**
   - Private keys, certificates → **STOP, warn**

3. **Impact check** (MANDATORY)
   - Run `gitnexus_detect_changes()` to verify affected scope
   - Warn user if HIGH or CRITICAL risk detected

4. **Group changes**
   - Identify logical groups. Unrelated changes → separate commits.

5. **Commit**
   ```
   git add <files>
   git commit -m "<type>: <message>"
   ```

## Allowed Commit Types
- `feat` — new feature
- `fix` — bug fix
- `docs` — documentation only
- `style` — formatting (no code change)
- `test` — adding or correcting tests
- `chore` — maintenance, build, tooling
- `refactor` — code restructuring
- `perf` — performance improvement

## Rules
- Never commit secrets, env files, or hardcoded credentials
- Prefer multiple focused commits over one large mixed commit
- Do not use `-a` flag with `git commit`
- Keep messages under 72 characters
EOF

    log_success "4 active agents created (orchestrator, coder, review, commit)"
}

# ============================================
# 7. Create Rules
# ============================================
setup_rules() {
    log_info "Creating rules..."

    # Global Rules
    cat > "$OPENCODE_DIR/rules/global.md" << 'EOF'
# Global Rules - OpenCode

**Token Budget**: See `rules/common/token-budget.md`
**MCP Invocation**: See `rules/common/lazy-mcp.md` (MCP-first policy)
**Search Principles**: See `rules/common/goal-hint-search.md`
**Mandatory Search**: See `rules/common/mandatory-codebase-search.md`

---

## Core Principles
1. **Reuse First** — Search existing code/libs before writing new
2. **Agent-First** — Delegate to Task tool specialists
3. **Test-Driven** — Write tests first, 80%+ coverage
4. **Security-First** — Validate all inputs
5. **Immutability** — New objects, never mutate
6. **Plan Before Execute** — Use Plan mode (Tab) for complex features
7. **Planner Is Read-Only** — Planning mode must not modify code/files

---

## Planner Mode Guardrail (MANDATORY)

When user intent is planning (plan/roadmap/options/"how should we do this"):
- **DO**: analyze, compare options, produce actionable plan with acceptance criteria.
- **DO NOT**: call `Edit`, `Write`, or perform implementation commands.
- **DO NOT**: stage/commit/push during planning.

Execution is allowed only after explicit user approval, e.g.:
- "implement"
- "apply plan"
- "bắt đầu code"
- "tiến hành sửa"

If any edit happens accidentally in planning mode:
1. Stop immediately
2. Report the mistake transparently
3. Offer rollback before continuing

---

## MCP-First Gate (MANDATORY)

For every coding/debug/review/planning task:
1. Start with `gitnexus` MCP to fetch relevant code context.
2. Use other MCPs as needed (`context7`, `sequential-thinking`, `playwright`).
3. Only fallback to non-MCP search/tools when MCP cannot provide sufficient results.

Fallback policy:
- Retry gitnexus with narrower queries before fallback.
- If fallback is used, state the reason briefly in the response.

---

## Reuse First (MANDATORY)

**Priority**: Existing > Compose > Extract > Create new

Before implementing anything new:
- [ ] Search codebase for existing implementation (`gitnexus`)
- [ ] Search GitHub for existing open-source solutions (`gh search code`)
- [ ] Check package registries (npm, pub, PyPI, crates.io)
- [ ] Check library docs via Context7

Only create new code when existing options are insufficient.

---

## Task Delegation

Use the **Task tool** to delegate work to specialized subagents:

| Trigger | subagent_type | When |
|---------|---------------|------|
| Codebase exploration | `explore` | Find files, search code, understand architecture |
| Complex multi-step work | `general` | Research, multi-file changes, parallel operations |

Use **skills** (via `skill` tool) for domain-specific workflows:
- `codex-impl-review` — Review uncommitted changes via Codex debate
- `codex-pr-review` — Review PR before merge
- `codex-plan-review` — Debate plans before implementation
- `codex-security-review` — Security-focused review (OWASP + CWE)
- `codex-commit-review` — Review commits before push
- `codex-think-about` — Peer reasoning/debate on technical questions
- `codex-parallel-review` — Multi-perspective parallel review
- `codex-codebase-review` — Full codebase review (50-500+ files)

**Rules**: Always ask user before loading review skills. Phrase as suggestion.

---

## Development Workflow

### Research & Reuse (mandatory before new implementation)
1. **Codebase search first** — GitNexus MCP
2. **GitHub code search** — Find existing implementations
3. **Library docs** — Context7 for API behavior
4. **Web research only when insufficient** — Exa after GitHub/docs

### Feature Implementation
1. **Plan First** — Use Plan mode (Tab key) to explore, then switch to Build mode
2. **TDD Approach** — Write tests first (RED), implement (GREEN), refactor (IMPROVE), 80%+ coverage
3. **Code Review** — Load review skills, address CRITICAL/HIGH issues
4. **Commit & Push** — Detailed messages, conventional commits format
5. **Pre-Review Checks** — CI/CD passing, no merge conflicts, branch up to date

### OpenSpec Workflow (when using ECC skills)
```
skill: spx-plan → skill: spx-ff → skill: spx-apply → skill: spx-verify
```

---

## Coding Standards

### Immutability (CRITICAL)
```
WRONG:  modify(original, field, value) → changes original
CORRECT: update(original, field, value) → returns new copy
```

### File Organization
- MANY SMALL FILES > FEW LARGE FILES
- 200-400 lines typical, 800 max
- High cohesion, low coupling
- Organize by feature/domain, not type

### Quality Checklist
- [ ] Functions <50 lines
- [ ] Files <800 lines
- [ ] No deep nesting >4 levels
- [ ] No hardcoded values
- [ ] No mutation

### Error Handling
- Handle errors at every level
- User-friendly messages in UI code
- Log detailed context server-side
- Never silently swallow errors

### Input Validation
- Validate all user input before processing
- Fail fast with clear error messages
- Never trust external data

---

## Security Guidelines

### Before ANY Commit
- [ ] No hardcoded secrets
- [ ] All user inputs validated
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention
- [ ] CSRF protection
- [ ] Auth/authz verified
- [ ] Rate limiting
- [ ] Error messages don't leak data

### If Security Issue Found
1. STOP immediately
2. Load `security-review` or `codex-security-review` skill
3. Fix CRITICAL issues first
4. Review for similar issues

---

## Testing Requirements

### Minimum Coverage: 80%

### Test Types (ALL required)
1. **Unit** — Functions, utilities, components
2. **Integration** — API endpoints, database
3. **E2E** — Critical user flows

### TDD Workflow
1. Write test first (RED) — should FAIL
2. Implement minimal (GREEN) — should PASS
3. Refactor (IMPROVE)
4. Verify 80%+ coverage

### Test Failures
1. Check test isolation
2. Verify mocks
3. Fix implementation (not tests unless wrong)

---

## Code Review Standards

### When to Review (MANDATORY)
- After writing/modifying code
- Before commits to shared branches
- Security-sensitive changes (auth, payments, user data)
- Architectural changes

### Checklist
- [ ] Readable, well-named
- [ ] Functions <50 lines, files <800 lines
- [ ] No deep nesting >4 levels
- [ ] Errors handled explicitly
- [ ] No hardcoded secrets or console.log
- [ ] Tests exist, coverage >=80%

### Security Triggers → STOP + security-review skill
Auth, user input, DB queries, file ops, external APIs, crypto, payments

### Severity Levels
| Level | Action |
|-------|--------|
| CRITICAL | **BLOCK** — security/data loss |
| HIGH | **WARN** — bug/quality issue |
| MEDIUM | **INFO** — maintainability |
| LOW | **NOTE** — style |

### Approval Criteria
- **Approve**: No CRITICAL or HIGH
- **Warning**: HIGH only
- **Block**: CRITICAL found

---

## Performance

### Context Window
Avoid last 20% for large refactoring/multi-file features.
Start new sessions at logical milestones (research→plan, plan→implement, debug→next).

### Build Failures
Use Task tool (general agent) to analyze, fix incrementally, verify.

---

## Git Workflow

### Commit Format
```
<type>: <description>
<optional body>
```
Types: feat, fix, refactor, docs, test, chore, perf, ci

### PR Workflow
1. Analyze full commit history (`git diff [base]...HEAD`)
2. Draft comprehensive PR summary with test plan
3. Push with `-u` flag if new branch

---

## Common Patterns

### Repository Pattern
```
findAll, findById, create, update, delete
Business logic depends on interface, not storage
```

### API Response Format
```json
{
  "success": true,
  "data": {},
  "error": null,
  "metadata": {}
}
```
EOF

    # Token Budget Rules
    cat > "$OPENCODE_DIR/rules/common/token-budget.md" << 'EOF'
---
name: "token-budget"
description: "Token budget management - proactive context hygiene"
---

# Token Budget Management

## Core Principle
**Context is not free.** Every tool call, every file read, every search has a token cost. Optimize proactively.

## Token Distribution

| Operation | % of Total | Target |
|-----------|------------|--------|
| Read operations | 70-76% | → 40-50% |
| Execution | 12% | Maintain |
| Editing | 12% | Maintain |

## Budget Thresholds

| Context % | Action |
|----------|--------|
| < 40% | Normal operations |
| 40-60% | Begin context hygiene: summarize completed work, start new session at milestones |
| 60-80% | Strongly suggest new session before new task |
| > 80% | Critical: wrap up current task, minimal responses |
| > 90% | Emergency: Only confirmations, no analysis |

## Proactive Practices

### 1. Selective File Reading
```
BAD:  cat entire_file.dart (500 lines)
GOOD: grep -n "relevant_function" file.dart (10 lines)
GOOD: read file.dart offset=150 limit=30 (specific section)
```

### 2. Goal-Directed Search
**Read less, think better.** Always specify WHAT you want to find, not just WHAT to search.

```
BAD: Search for "auth" in codebase
GOOD: Find auth middleware in src/middleware/. Need JWT validation flow for refresh token.
```

### 3. Conversation Summarization
After completing milestones, summarize and discard:
- Old exploration context
- Failed approaches
- Debug traces

## Compact Triggers

| Trigger Point | Compact? | Why |
|-------------|----------|-----|
| Research → Planning | YES | Research is bulky, plan is distilled |
| Planning → Implementation | YES | Plan is in Todo, free context for code |
| Debugging → Next Feature | YES | Debug traces pollute new context |
| Mid-implementation | NO | Preserve variable names, paths |
| After failed approach | YES | Clear dead-end reasoning |

## MCP Lazy Invocation (xem `lazy-mcp.md`)

**KHÔNG gọi tất cả 4 MCPs mỗi câu hỏi.**

| Question Type | MCPs Needed | Examples |
|---------------|-------------|----------|
| Trivial | NONE | "fix typo", "add comment", "rename variable" |
| Code Search | gitnexus | "where is X defined", "find auth pattern" |
| Library/Framework | context7 only | "how to use Provider in Flutter" |
| Complex Logic | gitnexus + sequentialthinking | "design auth system", "debug race condition" |
| External Research | + github if needed | "best practice for X", "compare A vs B" |

**ALWAYS search (don't skip):** Security ops, DB modifications, auth changes, production deployments.

**NEVER search (skip all):** User says "don't search", file path + line number provided, trivial edits, context already in recent messages.

## Cost-Aware Model Routing

| Task Complexity | Strategy |
|---------------|----------|
| Trivial (single file) | Current model, minimal context |
| Low (one component) | Current model |
| Medium (multi-file) | Current model, focused context |
| High (architecture) | Delegate to planner agent |

**Route complex tasks to specialized agents instead of burning context in main session.**
EOF

    # Lazy MCP Rules
    cat > "$OPENCODE_DIR/rules/common/lazy-mcp.md" << 'EOF'
---
name: "lazy-mcp"
description: "MCP-first invocation with fallback-only policy"
origin: "User override"
---

# MCP-First Invocation

## Core Rule
Use MCP tools first for all engineering tasks. Fallback to non-MCP tools only when MCP cannot provide enough context.

## Mandatory Order
1. **GitNexus** first to fetch code context.
   - Use `gitnexus` for: dependency analysis, impact assessment, structural queries, refactoring, semantic search
2. Add MCPs by need:
   - `context7` for library/framework/API behavior
   - `sequential-thinking` for complex reasoning
   - `playwright` for UI flow verification
3. Fallback to Grep/Glob/Bash search only after MCP attempts are insufficient.

## Codebase Search Gate
- Always call `gitnexus` before editing or reviewing code.
- Include a goal-directed query (what to find + why).
- If results are weak, retry with a narrower query before fallback.

## Fallback Policy
- MCP failure conditions:
  - empty/irrelevant results after retries
  - tool/runtime errors
  - missing coverage for non-code assets
- When falling back, state a brief reason.

## Practical Routing
- Code change/review/debug: `gitnexus` mandatory.
- API/framework uncertainty: `gitnexus` + `context7`.
- Complex design/debug: `gitnexus` + `sequential-thinking`.
- UI behavior validation: `gitnexus` + `playwright`.

## Do Not
- Do not skip codebase MCP for convenience.
- Do not start with plain grep/find when MCP can answer.
- Do not use fallback silently.
EOF

    # Goal Hint Search Rules
    cat > "$OPENCODE_DIR/rules/common/goal-hint-search.md" << 'EOF'
---
name: "goal-hint-search"
description: "Goal-directed code search - specify what to find, not just what to search"
origin: "SWE-Pruner research"
---

# Goal-Directed Code Search

## Core Insight (from SWE-Pruner)

**Problem:** Code agents spend 70%+ tokens on reading files, but most content is irrelevant to the task.

**Solution:** When searching, specify WHAT you want to find, not just WHAT to search.

## The Goal Hint Pattern

### Before (Wasteful)
```
User: How is authentication handled?
Agent: searches "auth" → finds 50 files → reads all of them → context explodes
```

### After (Efficient)
```
User: How is authentication handled?
Agent: searches "auth" with hint "find auth middleware, JWT handling, user validation"
→ reads only relevant sections → 70% fewer tokens
```

## How to Formulate Goal Hints

### Template
```
SEARCH FOR: [what you need]
GOAL HINT: [specific question being answered]

Example:
SEARCH: auth middleware
GOAL HINT: "Find JWT validation logic and user session handling"
```

### Goal Hint Components
1. **Specific function** you're looking for
2. **What you need to know** about it
3. **How it relates** to your task

## Implementation in OpenCode

### For codebase searches (gitnexus)
Always include:
- File/function you're looking for
- What question you need answered
- Relevant context about your task

```
Example:
❌ BAD: Find auth files
✅ GOOD: Find auth middleware in src/middleware/. Need to understand JWT validation flow for implementing refresh token.
```

### For file reading
Use line ranges when possible:
```
❌ BAD: cat src/auth/service.dart (entire 500-line file)
✅ GOOD: 
  - grep "validateRefreshToken" src/auth/service.dart
  - read src/auth/service.dart offset=150 limit=50
```

## Search → Read → Act Pipeline

```
1. SEARCH (coarse)
   gitnexus query "find auth middleware" with goal hint
   
2. READ (fine-grained)  
   grep/cat with specific pattern and line range
   
3. ACT (focused)
   Only relevant code in context
```

## Token Savings Target

| Operation | Without Goal Hint | With Goal Hint |
|-----------|-------------------|----------------|
| File search | Full file read | Relevant lines only |
| Code search | All matches | Context-filtered |
| Pattern match | 500 lines | 20 lines |

**Target: 50-70% reduction in read operation tokens**

## Quick Command Reference

```
# Instead of full file read:
grep -n "pattern" file.dart

# Instead of reading all matches:
grep -A5 -B5 "pattern" file.dart  # 5 lines context

# Instead of whole directory:
ls src/auth/ | grep -E "middleware|service"

# Always specify:
WHAT you're looking for + WHY you need it
```

## SWE-Pruner Principle
> "The agent that skims intelligently outperforms the agent that reads everything."

## When Goal Hints Matter Most

| Task | Goal Hint Impact |
|------|------------------|
| Debugging | HIGH - focus on error handling |
| Feature addition | HIGH - focus on existing patterns |
| Refactoring | MEDIUM - need context but selective |
| Reading code | HIGH - don't need all 500 lines |
| Understanding flow | MEDIUM - focus on key functions |
EOF

    # Mandatory Codebase Search Rules
    cat > "$OPENCODE_DIR/rules/common/mandatory-codebase-search.md" << 'EOF'
---
name: "mandatory-codebase-search"
description: "Bắt buộc sử dụng GitNexus MCP cho mọi thao tác tìm kiếm codebase"
---

# Mandatory Codebase Search

## Rule
Khi cần tìm kiếm, tra cứu, hoặc hiểu codebase — **LUÔN sử dụng `gitnexus` MCP** làm công cụ đầu tiên và bắt buộc.

## MCP Priority
1. **GitNexus** — Ưu tiên cho mọi tác vụ codebase: dependency graph, impact analysis, semantic search, structural queries (Cypher)

## Không được phép
- Dùng `grep`, `find`, `rg`, `cat` để tìm kiếm ngữ nghĩa trong codebase làm bước đầu tiên
- Dùng `Glob` hoặc `Grep` tool thay cho MCP khi chưa thử MCP
- Đọc toàn bộ file lớn mà không cần thiết

## Được phép (fallback)
- `grep`: Chỉ khi cần tìm pattern chính xác sau khi MCP đã xác định vị trí
- `read`: Đọc file cụ thể với offset/limit
- `Glob`: Tìm file theo tên khi MCP không khả dụng

## Ghi nhớ
- GitNexus dùng knowledge graph — tốt cho structural analysis, impact assessment, và semantic search
EOF

    log_success "Rules created (global + common)"
}

# ============================================
# 8. Create package.json
# ============================================
setup_package_json() {
    log_info "Creating package.json..."
    
    cat > "$OPENCODE_DIR/package.json" << 'EOF'
{
  "type": "module",
  "dependencies": {
    "@kilocode/plugin": "7.2.14",
    "@opencode-ai/plugin": "1.4.6",
    "opencode-mem": "^2.13.0"
  }
}
EOF

    log_success "package.json created"
}

# ============================================
# 9. Create Plugin
# ============================================
setup_plugin() {
    log_info "Creating auto-save-memory plugin..."
    
    cat > "$OPENCODE_DIR/plugins/auto-save-memory.ts" << 'EOF'
import type { Plugin } from "@opencode-ai/plugin"

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

  const filePath = path.join(MEMORY_DIR, `${state.project}.json`)
  await fs.writeFile(filePath, JSON.stringify(memory, null, 2))
}

function extractSessionId(event: any): string {
  return event.session_id || event.sessionID
}

function extractProjectName(event: any): string {
  const cwd = event.properties?.cwd || process.cwd()
  return cwd.split("/").pop() || "unknown"
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
    if (/git\s+commit/.test(cmd)) {
      state.decisions.push({
        what: `Committed: ${cmd.slice(0, 100)}`,
        why: "Code change committed to git",
      })
    }
  }
}

export const AutoSaveMemory: Plugin = async ({ client }) => {
  return {
    event: async ({ event }) => {
      const sessionId = extractSessionId(event)
      if (!sessionId) return

      const state = getState(sessionId)

      if (event.type === "session.created") {
        state.project = extractProjectName(event)
      }

      if (event.type === "tool.execute.after") {
        trackToolUsage(state, (event as any).tool, (event as any).args || {})
      }

      if (event.type === "session.idle" && state.filesModified.length > 0) {
        state.summary = `Modified ${state.filesModified.length} file(s): ${state.filesModified.slice(-3).join(", ")}`
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
EOF

    log_success "Plugin created"
}

# ============================================
# 10. Install MCP Servers
# ============================================
setup_mcp_servers() {
    log_info "Installing MCP servers..."

    # Install gitnexus globally
    if ! command -v gitnexus &> /dev/null; then
        log_info "Installing GitNexus MCP..."
        if command -v bun &> /dev/null; then
            bun install -g gitnexus
        else
            npm install -g gitnexus
        fi
        log_success "GitNexus installed"
    else
        log_success "GitNexus already installed"
    fi

    # Install Playwright MCP
    log_info "Installing Playwright MCP (via npx)..."
    npx -y @playwright/mcp --version &>/dev/null || true
    log_success "Playwright MCP ready"

    # Install Context7 MCP
    log_info "Installing Context7 MCP (via npx)..."
    npx -y @upstash/context7-mcp --version &>/dev/null || true
    log_success "Context7 MCP ready"

    # Install Sequential Thinking MCP
    log_info "Installing Sequential Thinking MCP (via npx)..."
    npx -y @modelcontextprotocol/server-sequential-thinking --version &>/dev/null || true
    log_success "Sequential Thinking MCP ready"
}

# ============================================
# 11. Install OpenCode Dependencies
# ============================================
install_opencode_deps() {
    log_info "Installing OpenCode dependencies..."
    
    cd "$OPENCODE_DIR"
    
    if command -v bun &> /dev/null; then
        bun install
    else
        npm install
    fi
    
    log_success "Dependencies installed"
}

# ============================================
# 12. Create .gitignore
# ============================================
setup_gitignore() {
    cat > "$OPENCODE_DIR/.gitignore" << 'EOF'
node_modules/
*.log
.DS_Store
EOF
    log_success ".gitignore created"
}

# ============================================
# 13. Final Instructions
# ============================================
print_final_instructions() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}✅ OpenCode Setup Complete!${NC}"
    echo "=========================================="
    echo ""
    echo "1. ${BLUE}Install Language-Specific Skills (Optional):${NC}"
    echo "   Run: opencode skills install <skill-name>"
    echo "   Example: opencode skills install flutter-patterns"
    echo ""
    echo "2. ${BLUE}Available MCP Servers:${NC}"
    echo "   ✓ gitnexus (code intelligence)"
    echo "   ✓ context7 (library docs)"
    echo "   ✓ playwright (browser automation)"
    echo "   ✓ sequential-thinking (complex reasoning)"
    echo ""
    echo "3. ${BLUE}Available Agents:${NC}"
    echo "   ✓ orchestrator (dispatcher)"
    echo "   ✓ coder (implementation)"
    echo "   ✓ review (code review)"
    echo "   ✓ commit (git commit)"
    echo ""
    echo "4. ${BLUE}Start using OpenCode:${NC}"
    echo "   cd your-project"
    echo "   opencode"
    echo ""
    echo "=========================================="
}

# ============================================
# MAIN
# ============================================
main() {
    echo "=========================================="
    echo "  OpenCode Full Setup Script"
    echo "  (Excludes zai-vision MCP)"
    echo "=========================================="
    echo ""

    install_bun
    install_nodejs
    install_opencode
    setup_directories
    setup_opencode_config
    setup_agents
    setup_rules
    setup_package_json
    setup_plugin
    setup_gitignore
    setup_mcp_servers
    install_opencode_deps
    print_final_instructions
}

main "$@"
