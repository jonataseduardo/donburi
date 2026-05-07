# shellcheck shell=bash disable=SC2296,SC2298
# ---------------------------------------------------------------------------
# Donburi - Personal shell configuration
# Sourced from ~/.zshrc via: source ~/.donburi.zsh
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Donburi Directory
# ---------------------------------------------------------------------------
# Dynamically resolve donburi directory (handles symlinks)
# shellcheck disable=SC2296,SC2298
DONBURI_DIR="${${(%):-%x}:A:h:h}"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
if [ -x "$(command -v lsd)" ]; then
  alias ls='lsd'
  alias l='ls -lrt'
  alias la='ls -art'
  alias lla='ls -la'
  alias tree='ls --tree'
fi

alias zconf='cd $DONBURI_DIR/zsh/ && $EDITOR zshrc'
alias tconf='cd $DONBURI_DIR/tmux/ && $EDITOR tmux.conf'
alias nconf='cd $DONBURI_DIR/nvim/ && $EDITOR init.lua'
alias aconf='cd $DONBURI_DIR/aerospace/ && $EDITOR aerospace.toml'
alias gconf='cd $DONBURI_DIR/ghostty/ && $EDITOR config'
alias sconf='cd $DONBURI_DIR/sketchybar/ && $EDITOR sketchybarrc'
alias dconf='cd $DONBURI_DIR && $EDITOR .'

# shellcheck disable=SC2139
alias akeys="$DONBURI_DIR/keybinds/bin/aerospace-keys"
# shellcheck disable=SC2139
alias skeys="$DONBURI_DIR/keybinds/bin/slack-keys"
# shellcheck disable=SC2139
alias ckeys="$DONBURI_DIR/keybinds/bin/chrome-keys"
# shellcheck disable=SC2139
alias gkeys="$DONBURI_DIR/keybinds/bin/ghostty-keys"
# shellcheck disable=SC2139
alias mkeys="$DONBURI_DIR/keybinds/bin/macos-keys"
# shellcheck disable=SC2139
alias nkeys="$DONBURI_DIR/keybinds/bin/navigation-keys"
alias ipython="python -m IPython --no-autoindent"
alias c=clear
alias v=nvim
alias oc=opencode

# GNU coreutils on macOS
[[ -x "$(command -v gsed)" ]] && alias sed=gsed
[[ -x "$(command -v gawk)" ]] && alias awk=gawk

# Shopify Hydrogen
alias h2='$(npm prefix -s)/node_modules/.bin/shopify hydrogen'

# GitHub CLI
alias hl="gh auth login -p ssh"
alias hs="gh auth status"
alias hp="gh pr list"
# shellcheck disable=SC2139
alias hm="$DONBURI_DIR/zsh/bin/github-review-requests"
alias ha="gh pr list --author jcesar"
alias hv="gh pr view"
alias hw="gh pr view --web"
alias hd="gh pr diff"
alias hr="gh repo view --web"
alias hn="gh api notifications --jq '.[].subject.title'"

# ---------------------------------------------------------------------------
# Secrets
# ---------------------------------------------------------------------------
[[ -f "$HOME/.secrets" ]] && source "$HOME/.secrets"

# ---------------------------------------------------------------------------
# Bun
# ---------------------------------------------------------------------------
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ---------------------------------------------------------------------------
# Opencode
# ---------------------------------------------------------------------------
export PATH="$HOME/.opencode/bin:$PATH"
