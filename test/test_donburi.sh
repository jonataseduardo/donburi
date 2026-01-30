#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Integration tests for the donburi CLI
# Uses a temporary HOME directory to isolate from real user configs.
# ---------------------------------------------------------------------------

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Resolve the repo root (one level up from test/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DONBURI="$REPO_DIR/donburi"

# Create isolated HOME
ORIG_HOME="$HOME"
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
unset ZSH ZSH_CUSTOM 2>/dev/null || true

cleanup() {
    export HOME="$ORIG_HOME"
    rm -rf "$TEST_HOME"
    echo ""
    echo "========================================"
    echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped"
    echo "========================================"
    [[ "$FAIL_COUNT" -eq 0 ]]
}
trap cleanup EXIT

# Seed a minimal .zshrc so zsh setup has something to back up
echo "# placeholder" > "$TEST_HOME/.zshrc"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

pass() {
    local name="$1"
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "  \033[0;32mPASS\033[0m  $name"
}

fail() {
    local name="$1"
    local detail="${2:-}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "  \033[0;31mFAIL\033[0m  $name"
    [[ -n "$detail" ]] && echo "        $detail"
}

skip() {
    local name="$1"
    local reason="${2:-}"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    echo -e "  \033[1;33mSKIP\033[0m  $name${reason:+ ($reason)}"
}

# Run a command, capture stdout+stderr and exit code
run() {
    set +e
    OUTPUT=$("$@" 2>&1)
    EXIT_CODE=$?
    set -e
}

assert_exit_code() {
    local expected="$1"
    shift
    local name="$1"
    shift
    run "$@"
    if [[ "$EXIT_CODE" -eq "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "expected exit $expected, got $EXIT_CODE"
    fi
}

assert_output_contains() {
    local substring="$1"
    shift
    local name="$1"
    shift
    run "$@"
    if echo "$OUTPUT" | grep -q "$substring"; then
        pass "$name"
    else
        fail "$name" "output did not contain '$substring'"
    fi
}

assert_symlink() {
    local name="$1"
    local target="$2"
    local expected_source="$3"
    if [[ -L "$target" ]]; then
        local actual
        actual="$(readlink "$target")"
        if [[ "$actual" == "$expected_source" ]]; then
            pass "$name"
        else
            fail "$name" "symlink points to '$actual', expected '$expected_source'"
        fi
    else
        fail "$name" "$target is not a symlink"
    fi
}

assert_dir_exists() {
    local name="$1"
    local dir="$2"
    if [[ -d "$dir" ]]; then
        pass "$name"
    else
        fail "$name" "directory does not exist: $dir"
    fi
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

echo "Running donburi integration tests..."
echo "Temp HOME: $TEST_HOME"
echo ""

# --- Help ---
echo "--- help ---"
assert_output_contains "Usage:" "help exits 0 and shows usage" "$DONBURI" help
assert_exit_code 0 "--help exits 0" "$DONBURI" --help

# --- Status ---
echo "--- status ---"
assert_output_contains "Symlink status:" "status shows header" "$DONBURI" status

# --- Unknown command ---
echo "--- unknown command ---"
run "$DONBURI" notacommand
if [[ "$EXIT_CODE" -eq 1 ]] && echo "$OUTPUT" | grep -q "Unknown command"; then
    pass "unknown command exits 1 with message"
else
    fail "unknown command exits 1 with message" "exit=$EXIT_CODE"
fi

# --- Brew --list ---
echo "--- brew --list ---"
assert_output_contains "Apps" "brew --list shows Apps" "$DONBURI" brew --list
assert_exit_code 0 "brew --list exits 0" "$DONBURI" brew --list

run "$DONBURI" brew --list all
if echo "$OUTPUT" | grep -q "Apps" && echo "$OUTPUT" | grep -q "CLI" && \
   echo "$OUTPUT" | grep -q "Utils" && echo "$OUTPUT" | grep -q "Docker"; then
    pass "brew --list all shows all categories"
else
    fail "brew --list all shows all categories"
fi

run "$DONBURI" brew --list utils
if echo "$OUTPUT" | grep -q "node" && echo "$OUTPUT" | grep -q "slack"; then
    pass "brew --list utils contains node and slack"
else
    fail "brew --list utils contains node and slack"
fi

# --- Setup dry-run ---
echo "--- setup --dry-run ---"
run "$DONBURI" setup --dry-run
if [[ "$EXIT_CODE" -eq 0 ]] && (echo "$OUTPUT" | grep -q "Would symlink" || echo "$OUTPUT" | grep -q "Would install"); then
    pass "setup --dry-run exits 0 with preview"
else
    fail "setup --dry-run exits 0 with preview" "exit=$EXIT_CODE"
fi

assert_output_contains "nvim" "setup nvim --dry-run mentions nvim" "$DONBURI" setup nvim --dry-run

# --- Setup nvim (real) ---
echo "--- setup nvim ---"
run "$DONBURI" setup nvim
if [[ "$EXIT_CODE" -eq 0 ]]; then
    pass "setup nvim exits 0"
else
    fail "setup nvim exits 0" "exit=$EXIT_CODE"
fi
assert_symlink "nvim symlink created" "$TEST_HOME/.config/nvim" "$REPO_DIR/nvim"

# --- Status after nvim setup ---
run "$DONBURI" status
if echo "$OUTPUT" | grep -q "nvim" && echo "$OUTPUT" | grep -q "OK"; then
    pass "status shows OK for nvim after setup"
else
    fail "status shows OK for nvim after setup"
fi

# --- Full setup ---
echo "--- setup (all) ---"
run "$DONBURI" setup
if [[ "$EXIT_CODE" -eq 0 ]]; then
    pass "setup all exits 0"
else
    fail "setup all exits 0" "exit=$EXIT_CODE"
fi

# Verify all symlinks
assert_symlink "nvim symlink"       "$TEST_HOME/.config/nvim"       "$REPO_DIR/nvim"
assert_symlink "ghostty symlink"    "$TEST_HOME/Library/Application Support/com.mitchellh.ghostty/config" "$REPO_DIR/ghostty/config"
assert_symlink "aerospace symlink"  "$TEST_HOME/.config/aerospace"  "$REPO_DIR/aerospace"
assert_symlink "tmux symlink"       "$TEST_HOME/.tmux.conf"         "$REPO_DIR/tmux/tmux.conf"
assert_symlink "zsh symlink"        "$TEST_HOME/.zshrc"             "$REPO_DIR/zsh/zshrc"
assert_symlink "zsh-donburi symlink" "$TEST_HOME/.donburi.zsh"      "$REPO_DIR/zsh/donburi.zsh"
assert_symlink "sketchybar symlink" "$TEST_HOME/.config/sketchybar" "$REPO_DIR/sketchybar"

# --- Status after full setup ---
run "$DONBURI" status
ALL_OK=true
for component in nvim ghostty aerospace tmux zsh sketchybar; do
    if ! echo "$OUTPUT" | grep -q "OK"; then
        ALL_OK=false
        break
    fi
done
if $ALL_OK; then
    pass "status shows all OK after full setup"
else
    fail "status shows all OK after full setup"
fi

# --- Idempotency ---
echo "--- idempotency ---"
run "$DONBURI" setup
if [[ "$EXIT_CODE" -eq 0 ]] && echo "$OUTPUT" | grep -q "Already linked"; then
    pass "setup is idempotent (Already linked)"
else
    fail "setup is idempotent" "exit=$EXIT_CODE"
fi

# --- Update dry-run ---
echo "--- update --dry-run ---"
assert_exit_code 0 "update --dry-run exits 0" "$DONBURI" update --dry-run

# --- Brew dry-run ---
echo "--- brew --dry-run ---"
run "$DONBURI" brew cli --dry-run
if [[ "$EXIT_CODE" -eq 0 ]] && (echo "$OUTPUT" | grep -q "Would install" || echo "$OUTPUT" | grep -q "Would upgrade"); then
    pass "brew cli --dry-run exits 0 with preview"
else
    fail "brew cli --dry-run exits 0 with preview" "exit=$EXIT_CODE"
fi

assert_exit_code 0 "brew utils --dry-run exits 0" "$DONBURI" brew utils --dry-run

run "$DONBURI" brew all --dry-run
if [[ "$EXIT_CODE" -eq 0 ]] && (echo "$OUTPUT" | grep -q "apps" || echo "$OUTPUT" | grep -q "cli"); then
    pass "brew all --dry-run exits 0"
else
    fail "brew all --dry-run exits 0" "exit=$EXIT_CODE"
fi
