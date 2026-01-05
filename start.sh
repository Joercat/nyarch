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
    
    # Start elogind via init script
    echo "[ROOT] Starting elogind..."
    /etc/init.d/elogind start 2>/dev/null
    sleep 3
    
    # Verify login1
    if busctl --system list 2>/dev/null | grep -q login1; then
        echo "[ROOT] SUCCESS: login1 available on system bus!"
        
        # Create a seat for the user
        echo "[ROOT] Creating session..."
        mkdir -p /run/systemd/sessions /run/systemd/users /run/systemd/seats
        
        # Create session file that elogind expects
        cat > /run/systemd/sessions/1 << 'EOF'
USER=1000
NAME=nyarch
SEAT=seat0
ACTIVE=1
STATE=active
TYPE=x11
CLASS=user
DISPLAY=:1
EOF
        
        cat > /run/systemd/seats/seat0 << 'EOF'
ACTIVE_SESSIONS=1
CAN_GRAPHICAL=1
EOF
        
        cat > /run/systemd/users/1000 << 'EOF'
NAME=nyarch
STATE=active
SESSIONS=1
EOF
        
    else
        echo "[ROOT] WARNING: login1 not available!"
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
        XDG_SESSION_ID=1 \
        XDG_SEAT=seat0 \
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
export XDG_SESSION_ID=1
export XDG_SEAT=seat0
export LIBGL_ALWAYS_SOFTWARE=1
export GSK_RENDERER=cairo

# Clean old locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null

# Session dbus with system bus connection
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

# Install themes/icons
echo "[USER] Installing themes..."
mkdir -p /config/.local/share/themes /config/.local/share/icons /config/.config/gtk-3.0 /config/.config/gtk-4.0
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes/* /config/.local/share/themes/ 2>/dev/null || true
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/icons/* /config/.local/share/icons/ 2>/dev/null || true
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-3.0/* /config/.config/gtk-3.0/ 2>/dev/null || true
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0/* /config/.config/gtk-4.0/ 2>/dev/null || true

# Create bookmarks file to prevent warning
touch /config/.config/gtk-3.0/bookmarks

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

# Try gnome-shell first
echo "[USER] Starting GNOME Shell..."
DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
XDG_SESSION_ID=1 \
DISPLAY=:1 \
gnome-shell --x11 2>&1 &

SHELL_PID=$!
sleep 10

# Check if gnome-shell is running
if kill -0 $SHELL_PID 2>/dev/null && pgrep -x gnome-shell >/dev/null; then
    echo "[USER] GNOME Shell running!"
    DESKTOP_RUNNING="gnome-shell"
else
    echo "[USER] GNOME Shell failed, starting mutter..."
    
    # Kill any zombie gnome-shell
    pkill -9 gnome-shell 2>/dev/null || true
    sleep 2
    
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    DISPLAY=:1 \
    mutter --x11 2>&1 &
    
    MUTTER_PID=$!
    sleep 3
    
    # Start nautilus for file management
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    DISPLAY=:1 \
    nautilus /config 2>&1 &
    
    # Start gnome-panel or similar if available
    if command -v gnome-panel &>/dev/null; then
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" DISPLAY=:1 gnome-panel &
    fi
    
    DESKTOP_RUNNING="mutter"
fi

# noVNC
echo "[USER] Starting noVNC..."
websockify --web=/usr/share/novnc 7860 localhost:5901 &

echo ""
echo "=============================="
echo " NYARCH READY - port 7860"
echo " Desktop: $DESKTOP_RUNNING"
echo "=============================="

# Smarter monitor loop - don't restart if already running
while true; do
    # Check VNC
    if ! kill -0 $VNC_PID 2>/dev/null; then
        echo "[MONITOR] Restarting VNC..."
        Xtigervnc :1 -geometry 1280x720 -depth 24 -SecurityTypes None -ac -pn -rfbport 5901 -AlwaysShared 2>&1 &
        VNC_PID=$!
        sleep 3
    fi
    
    # Only restart desktop if NOTHING is running
    if ! pgrep -x "gnome-shell" >/dev/null && ! pgrep -x "mutter" >/dev/null; then
        echo "[MONITOR] No desktop running, starting mutter..."
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" DISPLAY=:1 mutter --x11 2>&1 &
        sleep 3
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" DISPLAY=:1 nautilus /config 2>&1 &
    fi
    
    sleep 15

done
