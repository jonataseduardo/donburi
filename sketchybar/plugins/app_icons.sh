#!/bin/bash
# App name to Nerd Font icon mapping
# Usage: source this file, then call get_app_icon "App Name"

get_app_icon() {
    local app_name="$1"

    case "$app_name" in
        # Terminals
        "Ghostty"|"iTerm2"|"iTerm"|"Terminal"|"Alacritty"|"WezTerm"|"Kitty")
            echo "󰆍" ;;
        # Browsers
        "Google Chrome"|"Chrome")
            echo "󰊯" ;;
        "Safari")
            echo "󰀹" ;;
        "Firefox"|"Firefox Developer Edition")
            printf '\xEE\x80\x87\n' ;;
        "Arc")
            echo "󰊯" ;;
        "Brave Browser"|"Brave")
            echo "󰖟" ;;
        # Communication
        "Slack")
            echo "󰒱" ;;
        "Discord")
            echo "󰙯" ;;
        "WhatsApp"|"‎WhatsApp")
            echo "󰖣" ;;
        "Telegram")
            echo "󰔁" ;;
        "Messages")
            echo "󰍡" ;;
        "Zoom"|"zoom.us")
            echo "󰐿" ;;
        "Microsoft Teams"|"Teams")
            echo "󰊻" ;;
        # Email
        "Mail"|"Apple Mail")
            echo "󰇮" ;;
        "Outlook"|"Outlook (PWA)"|"Microsoft Outlook")
            echo "󰇮" ;;
        # Music / Media
        "Spotify")
            printf '\xEF\x86\xBC\n' ;;
        "Music"|"Apple Music")
            echo "󰎆" ;;
        "Podcasts")
            echo "󰦔" ;;
        "VLC")
            echo "󰕼" ;;
        # Code / Dev
        "Code"|"Visual Studio Code"|"VSCodium")
            echo "󰨞" ;;
        "Xcode")
            echo "󰀺" ;;
        "Cursor")
            echo "󰨞" ;;
        "Zed")
            echo "󰬛" ;;
        "Neovim"|"nvim"|"MacVim"|"Vim")
            printf '\xEE\x98\xAB\n' ;;
        "RubyMine"|"PyCharm"|"IntelliJ IDEA"|"WebStorm"|"GoLand"|"CLion"|"DataGrip")
            echo "󰫰" ;;
        "Sublime Text")
            printf '\xEE\x9E\xAA\n' ;;
        "TablePlus"|"Sequel Pro"|"DBngin")
            echo "󰆼" ;;
        "Insomnia"|"Paw")
            echo "󰖟" ;;
        "Postman")
            echo "󰖟" ;;
        "Docker"|"Docker Desktop")
            echo "󰡨" ;;
        # Files / System
        "Finder")
            echo "󰝰" ;;
        "Archive Utility"|"The Unarchiver")
            echo "󰏖" ;;
        "Activity Monitor")
            echo "󰓅" ;;
        "System Preferences"|"System Settings")
            echo "󰒓" ;;
        "Disk Utility")
            echo "󰋊" ;;
        # Productivity
        "Notion")
            echo "󰘚" ;;
        "Obsidian")
            echo "󰷊" ;;
        "Bear")
            echo "󰇮" ;;
        "Things 3"|"Things")
            echo "󰄲" ;;
        "Figma")
            echo "󰕙" ;;
        "Sketch")
            echo "󰎙" ;;
        "Affinity Designer"|"Affinity Photo"|"Affinity Publisher")
            echo "󰎙" ;;
        "Preview")
            echo "󰋩" ;;
        "PDF Expert")
            echo "󰈦" ;;
        "1Password"|"1Password 7")
            echo "󰌋" ;;
        "Bitwarden")
            echo "󰌋" ;;
        "Raycast"|"Alfred")
            echo "󰀼" ;;
        # Fallback: first 2 characters of the app name
        *)
            echo "${app_name:0:2}" ;;
    esac
}
