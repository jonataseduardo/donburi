# shellcheck shell=bash
# ---------------------------------------------------------------------------
# Donburi - Personal shell configuration
# Sourced from ~/.zshrc via: source ~/.donburi.zsh
# ---------------------------------------------------------------------------

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

alias zconf='cd $HOME/c/donburi/zsh/ && $EDITOR zshrc'
alias tconf='cd $HOME/c/donburi/tmux/ && $EDITOR tmux.conf'
alias nconf='cd $HOME/c/donburi/nvim/ && $EDITOR init.lua'
alias aconf='cd $HOME/c/donburi/aerospace/ && $EDITOR aerospace.toml'
alias gconf='cd $HOME/c/donburi/ghostty/ && $EDITOR config'
alias sconf='cd $HOME/c/donburi/sketchybar/ && $EDITOR sketchybarrc'

alias akeys='$HOME/c/donburi/aerospace/scripts/aerospace-keys-helper.sh'
alias ipython="python -m IPython --no-autoindent"
alias c=clear

# GNU coreutils on macOS
[[ -x "$(command -v gsed)" ]] && alias sed=gsed
[[ -x "$(command -v gawk)" ]] && alias awk=gawk

# Shopify Hydrogen
alias h2='$(npm prefix -s)/node_modules/.bin/shopify hydrogen'

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
