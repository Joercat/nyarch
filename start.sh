#!/bin/bash
export DISPLAY=:1
export HOME=/config
export USER=nyarch
export XDG_RUNTIME_DIR=/tmp/runtime-nyarch

# 1. FIX USER IDENTITY (Fixes "I do not know who you are")
export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libnss_wrapper.so
export NSS_WRAPPER_PASSWD=/tmp/passwd.nyarch
export NSS_WRAPPER_GROUP=/etc/group
cp /tmp/passwd.template /tmp/passwd.nyarch

# 2. START DBUS & VNC
mkdir -p $XDG_RUNTIME_DIR && chmod 700 $XDG_RUNTIME_DIR
dbus-daemon --session --address=unix:path=$XDG_RUNTIME_DIR/bus --fork --nopidfile
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

# Start VNC (SecurityTypes None for no pass)
vncserver $DISPLAY -geometry 1280x720 -depth 24 -SecurityTypes None -localhost no || vncserver -kill $DISPLAY
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 7860 &

echo "--- STARTING AUTHENTIC NYARCH INSTALLATION ---"

# 3. GET NYARCH ASSETS (Exact Script Logic)
LATEST_TAG_VERSION=$(curl -s https://api.github.com/repos/NyarchLinux/NyarchLinux/releases/latest | grep "tag_name" | awk -F'"' '{print $4}')
RELEASE_LINK="https://github.com/NyarchLinux/NyarchLinux/releases/download/$LATEST_TAG_VERSION/"

cd /tmp
wget -q -O NyarchLinux.tar.gz "${RELEASE_LINK}NyarchLinux.tar.gz"
# Extraction creates /tmp/NyarchLinux/...
tar -xf NyarchLinux.tar.gz 

# 4. INSTALL NYARCH COMPONENTS
mkdir -p $HOME/.config $HOME/.local/share/gnome-shell/extensions

# Sync Skel
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/* $HOME/.config/
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/* $HOME/.local/share/

# Material You Colors Build (Restored Fix)
git clone https://github.com/FrancescoCaracciolo/material-you-colors.git /tmp/myc
cd /tmp/myc && make build
# Copying to the path NPM expects
MY_EXT_DIR="$HOME/.local/share/gnome-shell/extensions/material-you-colors@francescocaracciolo.github.io"
mkdir -p "$MY_EXT_DIR"
cp -rf * "$MY_EXT_DIR/"
cd "$MY_EXT_DIR" && npm install --no-audit

# 5. DCONF (The Core Look)
cd /tmp/NyarchLinux/Gnome/etc/dconf/db/local.d
dconf load / < 06-extensions
dconf load / < 02-interface
dconf load / < 04-wmpreferences
dconf load / < 03-background

echo "--- NYARCH SUITE FULLY APPLIED ---"

# 6. START GNOME
exec gnome-session
