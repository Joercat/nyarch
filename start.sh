#!/bin/bash

# 1. RUNTIME STABILITY
export XDG_RUNTIME_DIR=/tmp/runtime-abc
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1

# 2. VNC BOOTSTRAP
echo '#!/bin/sh
export XDG_CURRENT_DESKTOP=GNOME
export LIBGL_ALWAYS_SOFTWARE=1
dbus-run-session -- gnome-session' > /config/xstartup
chmod +x /config/xstartup

# Launch VNC without password
tigervncserver :1 -geometry 1280x720 -depth 24 -xstartup /config/xstartup -SecurityTypes None -localhost no
websockify --web /usr/share/novnc 7860 localhost:5901 &

# 3. FULL NYARCH INSTALLATION SEQUENCE
(
    echo "Applying Full Nyarch Suite..."
    sleep 45 # Wait for GNOME session to be ready for dconf
    
    LATEST_TAG=$(curl -s https://api.github.com/repos/NyarchLinux/NyarchLinux/releases/latest | grep "tag_name" | awk -F'"' '/tag_name/ {print $4}')
    RELEASE_URL="https://github.com/NyarchLinux/NyarchLinux/releases/download/$LATEST_TAG"
    RAW_REPO="https://raw.githubusercontent.com/NyarchLinux/NyarchLinux/refs/tags/$LATEST_TAG/Gnome"

    # A. FETCH ASSETS
    cd /tmp
    wget -q "${RELEASE_URL}/NyarchLinux.tar.gz" && tar -xf NyarchLinux.tar.gz
    wget -q "${RELEASE_URL}/wallpaper.tar.gz" && tar -xf wallpaper.tar.gz
    wget -q "${RELEASE_URL}/icons.tar.gz" && tar -xf icons.tar.gz

    # B. INSTALL THEMES & ICONS
    mkdir -p $HOME/.local/share/icons $HOME/.local/share/themes $HOME/.config
    cp -rf /tmp/Tela-circle-MaterialYou $HOME/.local/share/icons/
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes/* $HOME/.local/share/themes/
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/nyarch $HOME/.config/
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-3.0 $HOME/.config/
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0 $HOME/.config/
    
    # C. EXTENSIONS & MATERIAL YOU ENGINE
    mkdir -p $HOME/.local/share/gnome-shell/extensions
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/gnome-shell/extensions/* $HOME/.local/share/gnome-shell/extensions/
    
    git clone https://github.com/FrancescoCaracciolo/material-you-colors.git /tmp/myc
    cd /tmp/myc && make build && make install
    npm install --prefix $HOME/.local/share/gnome-shell/extensions/material-you-colors@francescocaracciolo.github.io

    # D. NYAOFETCH & BINARIES
    sudo wget -q -O /usr/local/bin/nekofetch "${RAW_REPO}/usr/local/bin/nekofetch"
    sudo wget -q -O /usr/local/bin/nyaofetch "${RAW_REPO}/usr/local/bin/nyaofetch"
    sudo chmod +x /usr/local/bin/nekofetch /usr/local/bin/nyaofetch

    # E. KITTY CONFIG
    mkdir -p $HOME/.config/kitty
    wget -q -O $HOME/.config/kitty/kitty.conf "${RAW_REPO}/etc/skel/.config/kitty/kitty.conf"

    # F. APPLY DCONF (THE LOOK)
    cd /tmp/NyarchLinux/Gnome/etc/dconf/db/local.d
    dconf load / < 06-extensions
    dconf load / < 02-interface
    dconf load / < 04-wmpreferences
    dconf load / < 03-background

    # G. FLATPAK APPS
    for app in nyarchwizard nyarchtour nyarchcustomize nyarchscript; do
        wget -q "https://github.com/nyarchlinux/$app/releases/latest/download/${app}.flatpak"
        flatpak install --user -y ./${app}.flatpak && rm ./${app}.flatpak
    done

    echo "--- FULL NYARCH INSTALLATION COMPLETE ---"
) &

tail -f /config/display.log 2>/dev/null || tail -f /dev/null
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
