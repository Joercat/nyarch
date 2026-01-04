#!/bin/bash
export DISPLAY=:1
export HOME=/config
export XDG_CONFIG_HOME=/config/.config
export XDG_DATA_HOME=/config/.local/share

# --- 1. START VNC ---
vncserver $DISPLAY -geometry 1280x720 -depth 24 -SecurityTypes None -localhost no &
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 7860 &

echo "--- STARTING AUTHENTIC NYARCH INSTALLATION ---"

# --- 2. DEFINE NYARCH VARIABLES ---
LATEST_TAG_VERSION=`curl -s https://api.github.com/repos/NyarchLinux/NyarchLinux/releases/latest | grep "tag_name" | awk -F'"' '/tag_name/ {print $4}'`
RELEASE_LINK="https://github.com/NyarchLinux/NyarchLinux/releases/download/$LATEST_TAG_VERSION/"
TAG_PATH="https://raw.githubusercontent.com/NyarchLinux/NyarchLinux/refs/tags/$LATEST_TAG_VERSION/Gnome/"

# --- 3. CORE FUNCTIONS (Automated from your script) ---

# Get Tarball
wget -q -O /tmp/NyarchLinux.tar.gz "${RELEASE_LINK}NyarchLinux.tar.gz"
cd /tmp && tar -xf NyarchLinux.tar.gz

# Install Extensions & Material You
mkdir -p /config/.local/share/gnome-shell/extensions
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/gnome-shell/extensions/* /config/.local/share/gnome-shell/extensions/
cd /tmp && git clone https://github.com/FrancescoCaracciolo/material-you-colors.git
cd material-you-colors && make build
npm install --prefix /config/.local/share/gnome-shell/extensions/material-you-colors@francescocaracciolo.github.io
# Icons & Themes
mkdir -p /config/.local/share/icons /config/.local/share/themes
wget -q -O /tmp/icons.tar.gz "${RELEASE_LINK}icons.tar.gz"
cd /tmp && tar -xf icons.tar.gz && cp -rf Tela-circle-MaterialYou /config/.local/share/icons/
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes/* /config/.local/share/themes/

# Wallpapers
cd /tmp && wget -q "${RELEASE_LINK}wallpaper.tar.gz" && tar -xf wallpaper.tar.gz
cd wallpaper && bash install.sh # Runs the Nyarch wallpaper installer

# Nyarch Exclusive Apps (Flatpak Bundles)
echo "Installing Nyarch Exclusive Bundles..."
for app in catgirldownloader wizard nyarchtour nyarchcustomize nyarchscript waifudownloader nyarchassistant; do
    wget -q -O "/tmp/$app.flatpak" "https://github.com/nyarchlinux/$app/releases/latest/download/$app.flatpak" || \
    wget -q -O "/tmp/$app.flatpak" "https://github.com/nyarchlinux/$app/releases/latest/download/$(echo $app | sed 's/nyarch//').flatpak"
    flatpak install --user -y "/tmp/$app.flatpak" 2>/dev/null
done

# Suggested Flatpaks
flatpak install --user -y flathub info.febvre.Komikku com.github.tchx84.Flatseal de.haeckerfelix.Shortwave org.gnome.Lollypop

# Final GSettings / Dconf Load
echo "Applying Nyarch GSettings..."
cd /tmp/NyarchLinux/Gnome/etc/dconf/db/local.d
for setting in 06-extensions 02-interface 04-wmpreferences 03-background; do
    dconf load / < "$setting" 2>/dev/null
done

# --- 4. FINALIZE ---
chmod -R 755 /config/.config /config/.local
cd /config
echo "--- NYARCH SUITE FULLY APPLIED ---"
wait
