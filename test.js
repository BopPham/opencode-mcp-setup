#!/usr/bin/env node
/**
 * Test Suite for OpenCode MCP Setup
 * Tests run in temp directory to avoid affecting real config
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const assert = require('assert');
const { execSync } = require('child_process');

// Test configuration
const TEST_DIR = path.join(os.tmpdir(), `opencode-test-${Date.now()}`);
const TEST_OPENCODE_DIR = path.join(TEST_DIR, '.opencode');

// Mock HOME for testing
process.env.HOME = TEST_DIR;
process.env.USERPROFILE = TEST_DIR; // Windows

// Import the setup script (mock version)
const setupScript = path.join(__dirname, 'index.js');

// Test utilities
function setup() {
    fs.mkdirSync(TEST_DIR, { recursive: true });
}

function cleanup() {
    if (fs.existsSync(TEST_DIR)) {
        fs.rmSync(TEST_DIR, { recursive: true, force: true });
    }
}

function runScript() {
    execSync(`node ${setupScript}`, { 
        cwd: __dirname,
        env: { ...process.env, HOME: TEST_DIR, USERPROFILE: TEST_DIR }
    });
}

// ============================================
// TESTS
// ============================================

console.log('🧪 Running OpenCode MCP Setup Tests...\n');

let passCount = 0;
let failCount = 0;

function test(name, fn) {
    try {
        fn();
        console.log(`✅ ${name}`);
        passCount++;
    } catch (e) {
        console.log(`❌ ${name}`);
        console.log(`   Error: ${e.message}`);
        failCount++;
    }
}

// Test 1: Fresh install creates directories
test('Fresh install: creates .opencode directory', () => {
    cleanup();
    setup();
    runScript();
    assert(fs.existsSync(TEST_OPENCODE_DIR), '.opencode dir should exist');
});

// Test 2: Creates opencode.json
test('Fresh install: creates opencode.json with 4 MCPs', () => {
    const configPath = path.join(TEST_OPENCODE_DIR, 'opencode.json');
    assert(fs.existsSync(configPath), 'opencode.json should exist');
    
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    assert(config.mcp.gitnexus, 'gitnexus MCP should exist');
    assert(config.mcp.context7, 'context7 MCP should exist');
    assert(config.mcp.playwright, 'playwright MCP should exist');
    assert(config.mcp['sequential-thinking'], 'sequential-thinking MCP should exist');
});

// Test 3: No providers configured
test('Fresh install: no providers configured', () => {
    const configPath = path.join(TEST_OPENCODE_DIR, 'opencode.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    assert.deepStrictEqual(config.provider, {}, 'provider should be empty object');
});

// Test 4: Creates agents
test('Fresh install: creates 4 agents', () => {
    const agentsDir = path.join(TEST_OPENCODE_DIR, 'agents');
    const agents = fs.readdirSync(agentsDir).filter(f => f.endsWith('.md'));
    assert.strictEqual(agents.length, 4, 'should have 4 agents');
    assert(agents.includes('orchestrator.md'), 'orchestrator agent should exist');
    assert(agents.includes('coder.md'), 'coder agent should exist');
    assert(agents.includes('review.md'), 'review agent should exist');
    assert(agents.includes('commit.md'), 'commit agent should exist');
});

// Test 5: Creates rules
test('Fresh install: creates rules', () => {
    const globalPath = path.join(TEST_OPENCODE_DIR, 'rules', 'global.md');
    const tokenBudgetPath = path.join(TEST_OPENCODE_DIR, 'rules', 'common', 'token-budget.md');
    
    assert(fs.existsSync(globalPath), 'global.md should exist');
    assert(fs.existsSync(tokenBudgetPath), 'token-budget.md should exist');
});

// Test 6: Creates plugin
test('Fresh install: creates auto-save-memory plugin', () => {
    const pluginPath = path.join(TEST_OPENCODE_DIR, 'plugins', 'auto-save-memory.ts');
    assert(fs.existsSync(pluginPath), 'auto-save-memory.ts should exist');
});

// Test 7: Existing config is backed up
test('Existing config: backup is created', () => {
    cleanup();
    setup();
    
    // Create fake existing config
    fs.mkdirSync(TEST_OPENCODE_DIR, { recursive: true });
    fs.writeFileSync(path.join(TEST_OPENCODE_DIR, 'opencode.json'), '{"existing": true}');
    fs.writeFileSync(path.join(TEST_OPENCODE_DIR, 'my-custom-file.txt'), 'custom');
    
    runScript();
    
    // Check backup exists
    const backupDirs = fs.readdirSync(TEST_DIR).filter(d => d.startsWith('.opencode-backup-'));
    assert(backupDirs.length > 0, 'backup directory should exist');
    
    const backupPath = path.join(TEST_DIR, backupDirs[0]);
    const backupContent = fs.readFileSync(path.join(backupPath, 'opencode.json'), 'utf8');
    assert(backupContent.includes('"existing": true'), 'backup should contain original config');
});

// Test 8: Existing config is preserved
test('Existing config: preserves existing files', () => {
    const customFile = path.join(TEST_OPENCODE_DIR, 'my-custom-file.txt');
    assert(fs.existsSync(customFile), 'custom file should still exist after setup');
    assert.strictEqual(fs.readFileSync(customFile, 'utf8'), 'custom', 'custom file content preserved');
});

// Test 9: Existing opencode.json not overwritten
test('Existing config: opencode.json not overwritten', () => {
    const configPath = path.join(TEST_OPENCODE_DIR, 'opencode.json');
    const content = fs.readFileSync(configPath, 'utf8');
    assert(content.includes('"existing": true'), 'original opencode.json should be preserved');
});

// Test 10: package.json is created
test('Fresh install: creates package.json', () => {
    cleanup();
    setup();
    runScript();
    
    const pkgPath = path.join(TEST_OPENCODE_DIR, 'package.json');
    assert(fs.existsSync(pkgPath), 'package.json should exist');
    
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    assert(pkg.dependencies['@opencode-ai/plugin'], 'should have @opencode-ai/plugin');
    assert(pkg.dependencies['opencode-mem'], 'should have opencode-mem');
});

// Test 11: Cross-platform path handling
test('Cross-platform: handles paths correctly', () => {
    const configPath = path.join(TEST_OPENCODE_DIR, 'opencode.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    
    // Instructions use tilde paths (cross-platform)
    config.instructions.forEach(instr => {
        assert(instr.startsWith('~/.opencode/'), `instruction should use tilde path: ${instr}`);
    });
});

// Test 12: .gitignore is created
test('Fresh install: creates .gitignore', () => {
    const gitignorePath = path.join(TEST_OPENCODE_DIR, '.gitignore');
    assert(fs.existsSync(gitignorePath), '.gitignore should exist');
});

// ============================================
// SUMMARY
// ============================================

console.log('\n==========================================');
console.log(`Results: ${passCount} passed, ${failCount} failed`);
console.log('==========================================');

// Cleanup
cleanup();

if (failCount > 0) {
    process.exit(1);
} else {
    console.log('\n🎉 All tests passed!');
}
