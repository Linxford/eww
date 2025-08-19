#!/usr/bin/env bash
set -euo pipefail

# ────────────── Functions ──────────────
error_exit() { echo -e "\e[31m[x] $1\e[0m"; exit 1; }
warn() { echo -e "\e[33m[!] $1\e[0m"; }

check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            case "$1" in
                git) sudo pacman -S --needed git -y ;;
                paru) error_exit "paru (AUR helper) not installed. Please install it manually." ;;
                wal) sudo pacman -S --needed pywal -y ;;
                matugen) warn "matugen not installed, colors may not apply" ;;
            esac
        else
            error_exit "$1 not found, please install it manually."
        fi
    fi
}

# ────────────── Detect Installer Type ──────────────
choose_installer() {
    if command -v zenity >/dev/null 2>&1; then
        INSTALLER="zenity"
    elif command -v whiptail >/dev/null 2>&1; then
        INSTALLER="whiptail"
    else
        error_exit "Neither zenity nor whiptail is available. Please install one."
    fi
    echo "Using installer: $INSTALLER"
}

# ────────────── Progress Functions ──────────────
progress_whiptail() { STEP=$((STEP+1)); PERCENT=$(( STEP * 100 / TOTAL )); whiptail --title "EWW Rice Installer" --gauge "$1" 6 60 $PERCENT; }
progress_zenity() { echo "$((STEP * 100 / TOTAL))"; echo "# $1"; STEP=$((STEP+1)); }

# ────────────── Universal Installer ──────────────
TOTAL=6
STEP=0

# 1. Check prerequisites
echo "Checking and installing prerequisites..."
check_command git
check_command paru
check_command wal
check_command matugen

# 2. Choose installer type
choose_installer

# 3. Define steps
STEPS=(
"Checking requirements..."
"Cloning repo..."
"Installing dependencies..."
"Copying configs..."
"Creating env.json..."
"Installation complete!"
)

# 4. Run installer logic
if [ "$INSTALLER" == "whiptail" ]; then
    whiptail --title "EWW Rice Installer" --msgbox "Press Enter to start installation." 10 60
    for msg in "${STEPS[@]}"; do
        progress_whiptail "$msg"
        case "$msg" in
            "Cloning repo...") [ -d "$HOME/eww" ] || git clone https://github.com/randomboi404/eww --depth 1 "$HOME/eww"; cd "$HOME/eww" ;;
            "Installing dependencies...") [ -f dependencies.lst ] && paru -Syu --needed --noconfirm $(cat dependencies.lst) ;;
            "Copying configs...") mkdir -p "$HOME/.config"; for dir in eww hypr; do [ -d "$HOME/.config/$dir" ] || cp -r "$dir" "$HOME/.config/"; done ;;
            "Creating env.json...") mkdir -p "$HOME/.env"; [ -f "$HOME/.env/env.json" ] || cat > "$HOME/.env/env.json" <<EOF
{
  "WEATHER_API_KEY": "Your weather api key",
  "LOCATION": "Your city name"
}
EOF
            ;;
        esac
    done
    whiptail --msgbox "Installation complete! Run 'eww daemon' and open widgets." 10 60

elif [ "$INSTALLER" == "zenity" ]; then
    zenity --info --text="Press OK to start installation." --width=400 --height=150
    LOGFILE=$(mktemp)
    (
    STEP=0
    for msg in "${STEPS[@]}"; do
        progress_zenity "$msg"
        sleep 0.5
        case "$msg" in
            "Cloning repo...")
                if [ -d "$HOME/eww" ]; then echo "Repo exists, skipping..." >>"$LOGFILE"; cd "$HOME/eww"; else git clone https://github.com/randomboi404/eww --depth 1 "$HOME/eww" &>>"$LOGFILE"; cd "$HOME/eww"; fi
            ;;
            "Installing dependencies...") [ -f dependencies.lst ] && paru -Syu --needed --noconfirm $(cat dependencies.lst) &>>"$LOGFILE" || echo "dependencies.lst missing" >>"$LOGFILE";;
            "Copying configs...")
                mkdir -p "$HOME/.config"
                for dir in eww hypr; do
                    [ -d "$HOME/.config/$dir" ] && echo "$dir exists, skipping..." >>"$LOGFILE" || cp -r "$dir" "$HOME/.config/" &>>"$LOGFILE"
                done
            ;;
            "Creating env.json...")
                mkdir -p "$HOME/.env"
                [ -f "$HOME/.env/env.json" ] && echo "env.json exists, skipping..." >>"$LOGFILE" || cat > "$HOME/.env/env.json" <<EOF
{
  "WEATHER_API_KEY": "Your weather api key",
  "LOCATION": "Your city name"
}
EOF
            ;;
        esac
    done
    ) | zenity --progress --title="EWW Rice Installer" --text="Starting..." --percentage=0 --auto-close --pulsate --no-cancel

    zenity --text-info --title="Installer Log" --filename="$LOGFILE" --width=800 --height=500
    zenity --info --text="Installation complete! Run 'eww daemon' and open widgets."
    rm -f "$LOGFILE"
fi

# ────────────── Final Instructions ──────────────
echo
echo "Next steps:"
echo "  1. Generate colors: wal -i /path/to/wallpaper && matugen image /path/to/wallpaper"
echo "  2. Start eww daemon: eww daemon"
echo "  3. Open widgets:"
echo "       eww open eww-bar"
echo "       eww open bg-panel"
echo "       eww open activate-linux"
echo
echo "⚠️  Don’t forget to check Hyprland keybinds and dock.sh setup."
