#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
REPO_URL="https://github.com/randomboi404/eww"
REPO_DIR="$HOME/.local/share/eww-rice"
CONFIG_DIR="$HOME/.config"
ENV_DIR="$HOME/.env"
ENV_FILE="$ENV_DIR/env.json"
HYPR_CONF="$CONFIG_DIR/hypr/hyprland.conf"
ENDRS_REPO="https://github.com/Dr-42/end-rs"
ENDRS_DIR="$HOME/.local/share/end-rs"
BIN_DIR="$CONFIG_DIR/eww/bin"

# === HELPERS ===
download_file() {
  local url="$1"
  local output="$2"

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$output" "$url"
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
  else
    echo "❌ Neither wget nor curl is installed. Please install one and re-run."
    exit 1
  fi
}

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ]; then
    local backup="${target}.bak.$(date +%s)"
    echo "⚠️  Backing up existing $target -> $backup"
    mv "$target" "$backup"
  fi
}

install_packages() {
  if command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
  elif command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
  else
    echo "❌ No AUR helper (yay/paru) found. Install one and re-run."
    exit 1
  fi

  echo "📦 Installing dependencies with $AUR_HELPER..."
  $AUR_HELPER -Syu --needed --noconfirm jq python-pywal matugen-git swayosd hyprlock eww-git rust
}

# === SCRIPT START ===
echo "🚀 Starting cautious install of EWW rice..."

# Install deps
install_packages

# Clone rice repo
echo "📥 Cloning rice repo..."
rm -rf "$REPO_DIR"
git clone --depth 1 "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"

# Install extra deps if listed
if [ -f dependencies.lst ]; then
  echo "📦 Installing extra rice dependencies..."
  $AUR_HELPER -Syu --needed --noconfirm $(cat dependencies.lst)
fi

# Copy configs
echo "⚙️  Copying configs to $CONFIG_DIR..."
for dir in eww hypr scripts; do
  if [ -d "$REPO_DIR/$dir" ]; then
    backup_if_exists "$CONFIG_DIR/$dir"
    cp -r "$REPO_DIR/$dir" "$CONFIG_DIR/"
    echo "✅ Installed $dir config"
  fi
done

# Setup env.json
mkdir -p "$ENV_DIR"
if [ ! -f "$ENV_FILE" ]; then
  cat > "$ENV_FILE" <<EOF
{
  "WEATHER_API_KEY": "PUT-YOUR-API-KEY-HERE",
  "LOCATION": "Your city name"
}
EOF
  echo "⚠️  Created $ENV_FILE — please edit it to set your WEATHER_API_KEY and LOCATION."
else
  echo "ℹ️  $ENV_FILE already exists, not overwriting."
fi

# === Install end-rs notification daemon ===
echo "🔔 Installing end-rs notification daemon..."
rm -rf "$ENDRS_DIR"
git clone --depth 1 "$ENDRS_REPO" "$ENDRS_DIR"

(cd "$ENDRS_DIR" && cargo build --release)

mkdir -p "$BIN_DIR"
cp "$ENDRS_DIR/target/release/end-rs" "$BIN_DIR/"
echo "✅ Installed end-rs → $BIN_DIR/end-rs"

# === Add to hyprland.conf ===
if [ -f "$HYPR_CONF" ]; then
  backup_if_exists "$HYPR_CONF"

  cp "$HYPR_CONF.bak."* "$HYPR_CONF" # start from backup copy

  if ! grep -q "eww daemon" "$HYPR_CONF"; then
    echo "exec-once = eww daemon &" >> "$HYPR_CONF"
    echo "✅ Added 'eww daemon' to hyprland.conf"
  fi
  if ! grep -q "end-rs" "$HYPR_CONF"; then
    echo "exec-once = $BIN_DIR/end-rs &" >> "$HYPR_CONF"
    echo "✅ Added 'end-rs' autostart to hyprland.conf"
  fi
else
  echo "⚠️ No $HYPR_CONF found. Skipping autostart injection."
fi

# === Done ===
echo
echo "🎨 Generate colors based on wallpaper with:"
echo "   wal -i /path/to/wallpaper"
echo "   matugen image /path/to/wallpaper"
echo
echo "▶️ To test manually (without restart):"
echo "   eww daemon &"
echo "   eww open eww-bar"
echo "   eww open bg-panel"
echo "   eww open activate-linux"
echo "   $BIN_DIR/end-rs &"
echo
echo "✅ Install finished! Restart Hyprland to see everything in action."
