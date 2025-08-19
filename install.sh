#!/usr/bin/env bash
set -euo pipefail

LOGFILE=$(mktemp)
TOTAL_SUBSTEPS=12
STEP=0

update_progress() {
    STEP=$((STEP+1))
    PERCENT=$(( STEP * 100 / TOTAL_SUBSTEPS ))
    whiptail --title "EWW Rice Installer" --gauge "$1" 6 60 $PERCENT
}

# Show starting message
whiptail --title "EWW Rice Installer" --msgbox "Press Enter to start installation." 10 60

# Step 1: Update package databases
update_progress "Updating package databases..."
sudo pacman -Syu --noconfirm &>>"$LOGFILE"

# Step 2: Install git
update_progress "Installing git..."
sudo pacman -S --needed git --noconfirm &>>"$LOGFILE"

# Step 3: Install pywal
update_progress "Installing pywal..."
sudo pacman -S --needed pywal --noconfirm &>>"$LOGFILE"

# Step 4: Install paru (AUR)
update_progress "Installing paru..."
git clone https://aur.archlinux.org/paru.git /tmp/paru &>>"$LOGFILE"
cd /tmp/paru
makepkg -si --noconfirm &>>"$LOGFILE"

# Step 5: Clone EWW repo
update_progress "Cloning EWW repo..."
git clone https://github.com/randomboi404/eww --depth 1 "$HOME/eww" &>>"$LOGFILE"

# Step 6: Install dependencies
update_progress "Installing dependencies..."
cd "$HOME/eww"
[ -f dependencies.lst ] && paru -Syu --needed --noconfirm $(cat dependencies.lst) &>>"$LOGFILE"

# Step 7: Copy configs
update_progress "Copying configs..."
mkdir -p "$HOME/.config"
for dir in eww hypr; do
    [ -d "$HOME/.config/$dir" ] && echo "$dir exists" >>"$LOGFILE" || cp -r "$dir" "$HOME/.config/" &>>"$LOGFILE"
done

# Step 8: Create env.json
update_progress "Creating env.json..."
mkdir -p "$HOME/.env"
[ -f "$HOME/.env/env.json" ] || cat > "$HOME/.env/env.json" <<EOF
{
  "WEATHER_API_KEY": "Your weather api key",
  "LOCATION": "Your city name"
}
EOF

# Step 9: Generate colors
update_progress "Generating colors..."
wal -i /path/to/wallpaper &>>"$LOGFILE"
matugen image /path/to/wallpaper &>>"$LOGFILE"

# Step 10: Almost done
update_progress "Finalizing..."
cd ~

# Step 11: Cleanup
update_progress "Cleaning up..."
rm -rf /tmp/paru

# Step 12: Done
update_progress "Installation complete!"

# Optional: show live log after install
whiptail --title "Installer Log" --textbox "$LOGFILE" 30 100

rm -f "$LOGFILE"

# Next steps instructions
whiptail --title "Next Steps" --msgbox "Run 'eww daemon' and open widgets:\n\neww open eww-bar\neww open bg-panel\neww open activate-linux" 15 60
