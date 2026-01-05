#!/bin/bash

echo "=== NYARCH CONTAINER STARTING ==="

if [ "$(id -u)" = "0" ]; then
    echo "[ROOT] Setting up system..."
    
    # Create directories
    mkdir -p /run/dbus /run/user/1000 /tmp/.X11-unix /tmp/.ICE-unix
    chmod 1777 /tmp/.X11-unix /tmp/.ICE-unix
    chmod 700 /run/user/1000
    chown nyarch:nyarch /run/user/1000
    
    # Start system dbus
    echo "[ROOT] Starting system dbus..."
    dbus-daemon --system --fork --nopidfile
    sleep 2
    
    # Start elogind using init script
    echo "[ROOT] Starting elogind via init script..."
    if [ -x /etc/init.d/elogind ]; then
        /etc/init.d/elogind start
        sleep 3
    fi
    
    # Verify login1 is available
    if busctl --system list 2>/dev/null | grep -q login1; then
        echo "[ROOT] SUCCESS: login1 service available!"
    else
        echo "[ROOT] WARNING: login1 not available, checking..."
        busctl --system list 2>/dev/null | head -10
    fi
    
    # Start other services
    for svc in /usr/libexec/colord /usr/lib/colord/colord \
               /usr/libexec/accounts-daemon /usr/lib/accountsservice/accounts-daemon \
               /usr/libexec/upowerd /usr/lib/upower/upowerd \
               /usr/libexec/polkitd /usr/lib/polkit-1/polkitd; do
        [ -x "$svc" ] && "$svc" &>/dev/null &
    done
    
    sleep 2
    
    # Switch to user
    echo "[ROOT] Switching to nyarch..."
    exec sudo -u nyarch env \
        HOME=/config \
        USER=nyarch \
        SHELL=/bin/bash \
        DISPLAY=:1 \
        XDG_RUNTIME_DIR=/run/user/1000 \
        XDG_CONFIG_HOME=/config/.config \
        XDG_DATA_HOME=/config/.local/share \
        XDG_CACHE_HOME=/config/.cache \
        XDG_SESSION_TYPE=x11 \
        XDG_CURRENT_DESKTOP=GNOME \
        XDG_SESSION_DESKTOP=gnome \
        DESKTOP_SESSION=gnome \
        LIBGL_ALWAYS_SOFTWARE=1 \
        GSK_RENDERER=cairo \
        /usr/local/bin/start.sh
fi

# === RUNNING AS NYARCH ===
echo "[USER] Running as $(whoami)"

export HOME=/config
export DISPLAY=:1
export XDG_RUNTIME_DIR=/run/user/1000
export XDG_CONFIG_HOME=/config/.config
export XDG_DATA_HOME=/config/.local/share
export XDG_CACHE_HOME=/config/.cache
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=GNOME
export LIBGL_ALWAYS_SOFTWARE=1
export GSK_RENDERER=cairo

# Clean old locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null

# Session dbus
echo "[USER] Starting session dbus..."
dbus-daemon --session --address="unix:path=/run/user/1000/bus" --fork
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

# Keyring
gnome-keyring-daemon --start --components=secrets,ssh 2>/dev/null &

# Download Nyarch
echo "[USER] Downloading Nyarch..."
cd /tmp
VERSION=$(curl -s --max-time 10 https://api.github.com/repos/NyarchLinux/NyarchLinux/releases/latest | grep tag_name | cut -d'"' -f4 || echo "25.04.3")
wget -q -O nyarch.tar.gz "https://github.com/NyarchLinux/NyarchLinux/releases/download/$VERSION/NyarchLinux.tar.gz" 2>/dev/null
tar -xzf nyarch.tar.gz 2>/dev/null

# Install themes/icons ONLY (no extensions yet)
echo "[USER] Installing themes..."
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes/* /config/.local/share/themes/ 2>/dev/null || true
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/icons/* /config/.local/share/icons/ 2>/dev/null || true
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-3.0 /config/.config/ 2>/dev/null || true
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0 /config/.config/ 2>/dev/null || true

# Basic dconf
echo "[USER] Setting dconf..."
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"
dconf write /org/gnome/desktop/wm/preferences/button-layout "'appmenu:minimize,maximize,close'"
dconf write /org/gnome/shell/disable-user-extensions true

# Start VNC
echo "[USER] Starting VNC..."
Xtigervnc :1 -geometry 1280x720 -depth 24 -SecurityTypes None -ac -pn -rfbport 5901 -AlwaysShared 2>&1 &
VNC_PID=$!

sleep 5

if ! xdpyinfo -display :1 >/dev/null 2>&1; then
    echo "[USER] ERROR: VNC failed!"
    exit 1
fi
echo "[USER] VNC ready!"

# Start gnome-shell directly
echo "[USER] Starting GNOME Shell..."
DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
DISPLAY=:1 \
gnome-shell --x11 2>&1 &

sleep 8

if pgrep -x gnome-shell >/dev/null; then
    echo "[USER] GNOME Shell running!"
else
    echo "[USER] Shell failed, using mutter..."
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" DISPLAY=:1 mutter --x11 2>&1 &
    sleep 2
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" DISPLAY=:1 nautilus /config &
fi

# noVNC
echo "[USER] Starting noVNC..."
websockify --web=/usr/share/novnc 7860 localhost:5901 &

echo ""
echo "=============================="
echo " NYARCH READY - port 7860"
echo "=============================="

# Monitor
while true; do
    kill -0 $VNC_PID 2>/dev/null || {
        Xtigervnc :1 -geometry 1280x720 -depth 24 -SecurityTypes None -ac -pn -rfbport 5901 -AlwaysShared &
        VNC_PID=$!
    }
    pgrep -x "gnome-shell\|mutter" >/dev/null || {
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" DISPLAY=:1 gnome-shell --x11 &
    }
    sleep 10

done
