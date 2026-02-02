#!/opt/homebrew/bin/bash
# Keybindings Display Library
# Shared utilities for rendering keybindings in a formatted table with Kanagawa colors

# Kanagawa-inspired colors
RESET='\033[0m'
BOLD='\033[1m'
# shellcheck disable=SC2034
DIM='\033[2m'

# Kanagawa palette
# shellcheck disable=SC2034
BLUE='\033[38;5;110m'      # waveBlue
CYAN='\033[38;5;73m'       # springGreen
# shellcheck disable=SC2034
GREEN='\033[38;5;114m'     # springGreen
YELLOW='\033[38;5;220m'    # carpYellow
# shellcheck disable=SC2034
ORANGE='\033[38;5;208m'    # surimiOrange
# shellcheck disable=SC2034
MAGENTA='\033[38;5;175m'   # sakuraPink
# shellcheck disable=SC2034
RED='\033[38;5;203m'       # peachRed
GRAY='\033[38;5;243m'      # fujiGray
WHITE='\033[38;5;223m'     # fujiWhite

# Box drawing characters
BOX_TL='┌'
BOX_TR='┐'
BOX_BL='└'
BOX_BR='┘'
BOX_H='─'
BOX_V='│'
BOX_ML='├'
BOX_MR='┤'
BOX_TM='┬'
BOX_BM='┴'
BOX_X='┼'

# Table dimensions
KEY_WIDTH=20
CMD_WIDTH=47
TOTAL_WIDTH=$((KEY_WIDTH + CMD_WIDTH + 1))  # +1 for middle separator only

# Helper: repeat a character n times
repeat_char() {
    local char="$1"
    local count="$2"
    printf '%*s' "$count" '' | tr ' ' "$char"
}

# Draw horizontal line
draw_line() {
    local left="$1"
    local mid="$2"
    local right="$3"
    printf "${GRAY}%s%s%s%s%s${RESET}\n" \
        "$left" \
        "$(repeat_char "$BOX_H" "$KEY_WIDTH")" \
        "$mid" \
        "$(repeat_char "$BOX_H" "$CMD_WIDTH")" \
        "$right"
}

# Draw header
draw_header() {
    local title="$1"
    local title_len=${#title}
    local padding=$(( (TOTAL_WIDTH - title_len) / 2 ))
    local padding_right=$(( TOTAL_WIDTH - title_len - padding ))

    # Top border
    printf "${GRAY}%s%s%s${RESET}\n" "$BOX_TL" "$(repeat_char "$BOX_H" "$TOTAL_WIDTH")" "$BOX_TR"

    # Title row
    printf "${GRAY}%s${RESET}%*s${BOLD}${CYAN}%s${RESET}%*s${GRAY}%s${RESET}\n" \
        "$BOX_V" "$padding" "" "$title" "$padding_right" "" "$BOX_V"

    # Separator
    draw_line "$BOX_ML" "$BOX_TM" "$BOX_MR"
}

# Draw category header
draw_category() {
    local category="$1"
    local color="$2"

    printf "${GRAY}%s${RESET} ${color}${BOLD}%-*s${RESET}${GRAY}%s${RESET}\n" \
        "$BOX_V" "$((TOTAL_WIDTH - 1))" "$category" "$BOX_V"
    draw_line "$BOX_ML" "$BOX_X" "$BOX_MR"
}

# Draw key-command row
draw_row() {
    local key="$1"
    local cmd="$2"

    # Truncate command if too long
    local max_cmd_len=$((CMD_WIDTH - 2))
    if [[ ${#cmd} -gt $max_cmd_len ]]; then
        cmd="${cmd:0:$((max_cmd_len - 3))}..."
    fi

    printf "${GRAY}%s${RESET} ${YELLOW}%-*s${RESET}${GRAY}%s${RESET} ${WHITE}%-*s${RESET}${GRAY}%s${RESET}\n" \
        "$BOX_V" "$((KEY_WIDTH - 1))" "$key" "$BOX_V" "$((CMD_WIDTH - 1))" "$cmd" "$BOX_V"
}

# Draw footer
draw_footer() {
    printf "${GRAY}%s%s%s%s%s${RESET}\n" \
        "$BOX_BL" \
        "$(repeat_char "$BOX_H" "$KEY_WIDTH")" \
        "$BOX_BM" \
        "$(repeat_char "$BOX_H" "$CMD_WIDTH")" \
        "$BOX_BR"
}

# Detect and configure pager
setup_pager() {
    local pager=""
    local pager_opts=""

    # Prefer bat if available, otherwise use less
    if command -v bat &>/dev/null; then
        pager="bat"
        # bat options: plain style (no line numbers), preserve colors, paging always
        pager_opts="--style=plain --color=always --paging=always"
    elif command -v less &>/dev/null; then
        pager="less"
        # less options: -R for ANSI colors, -S no wrap, -M verbose prompt, -i case-insensitive search
        pager_opts="-RSMi"
    else
        # No pager available, output directly
        return 1
    fi

    echo "$pager $pager_opts"
}
