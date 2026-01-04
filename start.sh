#!/bin/bash

# --- 1. ENVIRONMENT STABILITY ---
export XDG_RUNTIME_DIR=/tmp/runtime-abc
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1

# --- 2. VNC SETUP ---
echo '#!/bin/sh
export XDG_CURRENT_DESKTOP=GNOME
export LIBGL_ALWAYS_SOFTWARE=1
dbus-run-session -- gnome-session' > /config/.vnc/xstartup
chmod +x /config/.vnc/xstartup

tigervncserver :1 -geometry 1280x720 -depth 24 -rfbauth /config/.vnc/passwd -localhost no
websockify --web /usr/share/novnc 7860 localhost:5901 &

# --- 3. NYARCH CUSTOMIZATION SUITE ---
(
    echo "Applying Nyarch Overlays..."
    sleep 40 # Wait for GNOME to register dconf
    
    LATEST_TAG=$(curl -s https://api.github.com/repos/NyarchLinux/NyarchLinux/releases/latest | grep "tag_name" | awk -F'"' '/tag_name/ {print $4}')
    RELEASE_URL="https://github.com/NyarchLinux/NyarchLinux/releases/download/$LATEST_TAG"
    RAW_REPO="https://raw.githubusercontent.com/NyarchLinux/NyarchLinux/refs/tags/$LATEST_TAG/Gnome"

    # A. FETCH AND UNPACK ASSETS
    cd /tmp
    wget -q "${RELEASE_URL}/NyarchLinux.tar.gz" && tar -xf NyarchLinux.tar.gz
    wget -q "${RELEASE_URL}/wallpaper.tar.gz" && tar -xf wallpaper.tar.gz
    wget -q "${RELEASE_URL}/icons.tar.gz" && tar -xf icons.tar.gz

    # B. INSTALL THEMES & ICONS
    cp -rf /tmp/Tela-circle-MaterialYou $HOME/.local/share/icons/
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes/* $HOME/.local/share/themes/
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/nyarch $HOME/.config/
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0 $HOME/.config/

    # C. MATERIAL YOU ENGINE (NYARCH CORE)
    git clone https://github.com/FrancescoCaracciolo/material-you-colors.git /tmp/myc
    cd /tmp/myc && make build && make install
    npm install --prefix $HOME/.local/share/gnome-shell/extensions/material-you-colors@francescocaracciolo.github.io

    # D. NYAOFETCH & UTILS
    sudo wget -q -O /usr/local/bin/nyaofetch "${RAW_REPO}/usr/local/bin/nyaofetch"
    sudo chmod +x /usr/local/bin/nyaofetch

    # E. APPLY DCONF SETTINGS (The "Look")
    cd /tmp/NyarchLinux/Gnome/etc/dconf/db/local.d
    dconf load / < 06-extensions
    dconf load / < 02-interface
    dconf load / < 03-background

    # F. FLATPAK APPS (NYARCH EXCLUSIVES)
    # Using --user to avoid sudo permission issues in container
    for app in nyarchwizard nyarchtour nyarchcustomize nyarchscript; do
        wget -q "https://github.com/nyarchlinux/$app/releases/latest/download/${app}.flatpak"
        flatpak install --user -y ./${app}.flatpak && rm ./${app}.flatpak
    done

    echo "--- NYARCH INITIALIZATION COMPLETE ---"
) &

tail -f /config/.vnc/*.log
