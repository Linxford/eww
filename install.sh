#!/usr/bin/env bash
set -euo pipefail

# ────────────── Functions ──────────────
error_exit() { echo -e "\e[31m[x] $1\e[0m"; exit 1; }
warn() { echo -e "\e[33m[!] $1\e[0m"; }

# ────────────── Installer Type Selection ──────────────
choose_installer() {
    if command -v zenity >/dev/null 2>&1; then
        INSTALLER=$(zenity --list --radiolist \
            --title="EWW Rice Installer" \
            --text="Choose installer type:" \
            --column="" --column="Option" \
            TRUE "GUI (zenity)" FALSE "TUI (whiptail)" \
            --height=200 --width=400) || INSTALLER="whiptail"
    else
        INSTALLER=$(whiptail --title "EWW Rice Installer" --menu "Choose installer type:" 15 50 2 \
            1 "TUI (whiptail)" 2 "GUI (zenity)" 3>&1 1>&2 2>&3) || INSTALLER="whiptail"
        [ "$INSTALLER" == "2" ] && INSTALLER="zenity"
        [ "$INSTALLER" == "1" ] && INSTALLER="whiptail"
    fi
    echo "Using installer: $INSTALLER"
}

# ────────────── Progress Functions ──────────────
progress_whiptail() {
    STEP=$((STEP+1))
    PERCENT=$(( STEP * 100 / TOTAL ))
    whiptail --title "EWW Rice Installer" --gauge "$1" 6 60 $PERCENT
}

progress_zenity() {
    echo "$((STEP * 100 / TOTAL))"
    echo "# $1"
    STEP=$((STEP+1))
}

# ────────────── Main Installer ──────────────
TOTAL=6
STEP=0
choose_installer

# Check core requirements
command -v git >/dev/null 2>&1 || error_exit "git is required but not installed."
command -v paru >/dev/null 2>&1 || error_exit "paru (AUR helper) is required but not installed."

STEPS=(
"Checking requirements..."
"Cloning repo..."
"Installing dependencies..."
"Copying configs..."
"Creating env.json..."
"Installation complete!"
)

# ────────────── Installer Logic ──────────────
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
                if [ -d "$HOME/eww" ]; then
                    echo "Repo exists, skipping clone..." >>"$LOGFILE"
                    cd "$HOME/eww"
                else
                    git clone https://github.com/randomboi404/eww --depth 1 "$HOME/eww" &>>"$LOGFILE"
                    cd "$HOME/eww"
                fi
            ;;
            "Installing dependencies...")
                if [ -f dependencies.lst ]; then
                    paru -Syu --needed --noconfirm $(cat dependencies.lst) &>>"$LOGFILE"
                else
                    echo "dependencies.lst not found, skipping..." >>"$LOGFILE"
                fi
            ;;
            "Copying configs...")
                mkdir -p "$HOME/.config"
                for dir in eww hypr; do
                    if [ -d "$HOME/.config/$dir" ]; then
                        echo "$dir exists, skipping..." >>"$LOGFILE"
                    else
                        cp -r "$dir" "$HOME/.config/" &>>"$LOGFILE"
                    fi
                done
            ;;
            "Creating env.json...")
                mkdir -p "$HOME/.env"
                if [ -f "$HOME/.env/env.json" ]; then
                    echo "env.json exists, skipping..." >>"$LOGFILE"
                else
                    cat > "$HOME/.env/env.json" <<EOF
{
  "WEATHER_API_KEY": "Your weather api key",
  "LOCATION": "Your city name"
}
EOF
                    echo "env.json created." >>"$LOGFILE"
                fi
            ;;
        esac
    done
    ) | zenity --progress --title="EWW Rice Installer" --text="Starting..." --percentage=0 --auto-close --pulsate --no-cancel

    # Show live log window
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
