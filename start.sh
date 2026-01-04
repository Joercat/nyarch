#!/bin/bash
export DISPLAY=:1
export HOME=/config
export XDG_CONFIG_HOME=/config/.config
export XDG_DATA_HOME=/config/.local/share

# Start DBUS (Required for dconf and GNOME settings)
if [ ! -d "/var/run/dbus" ]; then
  dbus-daemon --session --address=unix:path=/tmp/dbus-session --fork --nopidfile
  export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-session
fi

# 1. START VNC
vncserver $DISPLAY -geometry 1280x720 -depth 24 -SecurityTypes None -localhost no &
sleep 2 # Wait for VNC to initialize
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 7860 &

echo "--- STARTING AUTHENTIC NYARCH INSTALLATION ---"

# 2. FETCH NYARCH METADATA
LATEST_TAG_VERSION=$(curl -s https://api.github.com/repos/NyarchLinux/NyarchLinux/releases/latest | grep "tag_name" | awk -F'"' '{print $4}')
RELEASE_LINK="https://github.com/NyarchLinux/NyarchLinux/releases/download/$LATEST_TAG_VERSION/"

# 3. RUN THE NYARCH INSTALL LOGIC (Automated)
cd /tmp
wget -q -O NyarchLinux.tar.gz "${RELEASE_LINK}NyarchLinux.tar.gz"
tar -xf NyarchLinux.tar.gz

# Sync Skel (Configs, Kitty, etc)
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/* /config/.config/ 2>/dev/null
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/* /config/.local/share/ 2>/dev/null

# Build Material You Colors
git clone https://github.com/FrancescoCaracciolo/material-you-colors.git /tmp/myc
cd /tmp/myc && make build
npm install --prefix /config/.local/share/gnome-shell/extensions/material-you-colors@francescocaracciolo.github.io

# Install Icons (Tela Circle)
wget -q -O /tmp/icons.tar.gz "${RELEASE_LINK}icons.tar.gz"
cd /tmp && tar -xf icons.tar.gz && mkdir -p /config/.local/share/icons
cp -rf Tela-circle-MaterialYou /config/.local/share/icons/

# 4. FLATPAK APPS (Silent Install)
echo "Installing Flatpaks..."
flatpak install --user -y flathub info.febvre.Komikku com.github.tchx84.Flatseal

# 5. DCONF OVERRIDES (Applying the look)
cd /tmp/NyarchLinux/Gnome/etc/dconf/db/local.d
for setting in 06-extensions 02-interface 04-wmpreferences 03-background; do
    dconf load / < "$setting" 2>/dev/null
done

echo "--- NYARCH SUITE FULLY APPLIED ---"
# Launch GNOME Session
exec gnome-session
