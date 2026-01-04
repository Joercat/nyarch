#!/bin/bash

echo "--- STARTING NYARCH CONTAINER (GNOME) ---"

# Must run initial setup as root
if [ "$(id -u)" = "0" ]; then
    echo "Setting up system services..."
    
    # Create required runtime directories
    mkdir -p /run/dbus
    mkdir -p /run/user/1000
    mkdir -p /run/systemd/seats
    mkdir -p /run/systemd/users  
    mkdir -p /run/systemd/sessions
    mkdir -p /tmp/.X11-unix
    
    chmod 1777 /tmp/.X11-unix
    chmod 700 /run/user/1000
    chown nyarch:nyarch /run/user/1000
    
    # Create fake systemd/elogind session files
    cat > /run/systemd/seats/seat0 << 'EOF'
ACTIVE_SESSIONS=1
CAN_MULTI_SESSION=1
CAN_GRAPHICAL=1
EOF

    cat > /run/systemd/users/1000 << 'EOF'
NAME=nyarch
RUNTIME=/run/user/1000
SERVICE=user@1000.service
SLICE=user-1000.slice
STATE=active
SESSIONS=1
SEATS=seat0
ACTIVE_SESSIONS=1
EOF

    cat > /run/systemd/sessions/1 << 'EOF'
USER=1000
NAME=nyarch
SEAT=seat0
ACTIVE=1
IS_DISPLAY=1
STATE=active
TYPE=x11
CLASS=user
DESKTOP=gnome
DISPLAY=:1
EOF

    # Start system dbus
    if [ ! -S /run/dbus/system_bus_socket ]; then
        dbus-daemon --system --fork --nopidfile 2>/dev/null || true
    fi
    
    # Start required services as root
    echo "Starting colord..."
    /usr/libexec/colord &>/dev/null &
    
    echo "Starting accounts-daemon..."
    /usr/libexec/accounts-daemon &>/dev/null &
    
    echo "Starting upowerd..."
    /usr/libexec/upowerd &>/dev/null &
    
    echo "Starting udisksd..."
    /usr/libexec/udisks2/udisksd &>/dev/null &
    
    # Switch to nyarch user for the rest
    echo "Switching to nyarch user..."
    exec sudo -u nyarch -E env \
        HOME=/config \
        USER=nyarch \
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
        NO_AT_BRIDGE=1 \
        /usr/local/bin/start.sh
fi

# Now running as nyarch user
echo "Running as: $(whoami) (UID: $(id -u))"

export HOME=/config
export DISPLAY=:1
export XDG_RUNTIME_DIR=/run/user/1000
export XDG_CONFIG_HOME=/config/.config
export XDG_DATA_HOME=/config/.local/share
export XDG_CACHE_HOME=/config/.cache
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_DESKTOP=gnome
export DESKTOP_SESSION=gnome
export LIBGL_ALWAYS_SOFTWARE=1
export GSK_RENDERER=cairo
export NO_AT_BRIDGE=1
export SHELL=/bin/bash

# Clean stale locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

echo "--- STARTING SESSION DBUS ---"
eval $(dbus-launch --sh-syntax --exit-with-session)
export DBUS_SESSION_BUS_ADDRESS
echo "Session DBUS: $DBUS_SESSION_BUS_ADDRESS"

echo "--- STARTING GNOME KEYRING ---"
eval $(gnome-keyring-daemon --start --components=secrets,ssh,pkcs11 2>/dev/null) || true

echo "--- DOWNLOADING NYARCH FILES ---"
cd /tmp

LATEST_TAG_VERSION=$(curl -s --max-time 10 https://api.github.com/repos/NyarchLinux/NyarchLinux/releases/latest | grep "tag_name" | awk -F'"' '{print $4}' || echo "")
if [ -z "$LATEST_TAG_VERSION" ]; then
    LATEST_TAG_VERSION="25.04.3"
fi

RELEASE_LINK="https://github.com/NyarchLinux/NyarchLinux/releases/download/$LATEST_TAG_VERSION/"
echo "Using Nyarch version: $LATEST_TAG_VERSION"

if [ ! -d "/tmp/NyarchLinux" ]; then
    echo "Downloading NyarchLinux tarball..."
    if wget -q --timeout=60 -O /tmp/NyarchLinux.tar.gz "${RELEASE_LINK}NyarchLinux.tar.gz" 2>/dev/null; then
        tar -xzf NyarchLinux.tar.gz 2>/dev/null || true
        echo "Tarball extracted"
    else
        echo "Trying git clone..."
        git clone --depth 1 https://github.com/NyarchLinux/NyarchLinux.git /tmp/NyarchLinux 2>/dev/null || true
    fi
fi

echo "--- INSTALLING NYARCH CUSTOMIZATIONS ---"

# Copy extensions
if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.local/share/gnome-shell/extensions" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/gnome-shell/extensions/* \
        /config/.local/share/gnome-shell/extensions/ 2>/dev/null || true
    chmod -R 755 /config/.local/share/gnome-shell/extensions/
    echo "Copied GNOME extensions"
fi

# Copy themes
if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes/* \
        /config/.local/share/themes/ 2>/dev/null || true
    echo "Copied themes"
fi

# Copy icons
if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.local/share/icons" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/icons/* \
        /config/.local/share/icons/ 2>/dev/null || true
    echo "Copied icons"
fi

# Copy GTK configs
if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-3.0" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-3.0 /config/.config/ 2>/dev/null || true
fi
if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0 /config/.config/ 2>/dev/null || true
fi

echo "--- INSTALLING MATERIAL-YOU-COLORS ---"
cd /tmp
if [ ! -d "/tmp/material-you-colors" ]; then
    git clone https://github.com/FrancescoCaracciolo/material-you-colors.git 2>/dev/null || true
fi

if [ -d "/tmp/material-you-colors" ]; then
    cd /tmp/material-you-colors
    make build 2>/dev/null || true
    make install 2>/dev/null || true
    
    MYCOLORS_DIR="$HOME/.local/share/gnome-shell/extensions/material-you-colors@francescocaracciolo.github.io"
    if [ -d "$MYCOLORS_DIR" ] && [ -f "$MYCOLORS_DIR/package.json" ]; then
        cd "$MYCOLORS_DIR"
        npm install 2>/dev/null || true
        echo "Material-You-Colors installed"
    fi
fi

echo "--- APPLYING DCONF SETTINGS ---"
# Apply basic settings first
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true
dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'" 2>/dev/null || true
dconf write /org/gnome/desktop/wm/preferences/button-layout "'appmenu:minimize,maximize,close'" 2>/dev/null || true
dconf write /org/gnome/mutter/center-new-windows true 2>/dev/null || true

# Load Nyarch dconf settings
if [ -d "/tmp/NyarchLinux/Gnome/etc/dconf/db/local.d" ]; then
    cd /tmp/NyarchLinux/Gnome/etc/dconf/db/local.d
    for conf in 02-interface 03-background 04-wmpreferences 06-extensions; do
        if [ -f "$conf" ]; then
            dconf load / < "$conf" 2>/dev/null || true
            echo "Loaded dconf: $conf"
        fi
    done
fi

echo "--- STARTING VNC SERVER ---"

# Start Xtigervnc
echo "Starting Xtigervnc on display :1..."
Xtigervnc :1 \
    -geometry 1280x720 \
    -depth 24 \
    -SecurityTypes None \
    -desktop "Nyarch" \
    -ac \
    -pn \
    -rfbport 5901 \
    -AlwaysShared \
    2>&1 &

VNC_PID=$!

# Wait for X server
echo "Waiting for X server..."
timeout=30
while [ $timeout -gt 0 ]; do
    if xdpyinfo -display :1 >/dev/null 2>&1; then
        echo "X server is ready!"
        break
    fi
    sleep 1
    timeout=$((timeout - 1))
done

if ! xdpyinfo -display :1 >/dev/null 2>&1; then
    echo "ERROR: X server failed to start!"
    exit 1
fi

echo "--- STARTING GNOME COMPONENTS ---"

# Start at-spi (accessibility - GNOME needs this)
/usr/libexec/at-spi-bus-launcher --launch-immediately &>/dev/null &
/usr/libexec/at-spi2-registryd &>/dev/null &

# Start gvfsd (virtual filesystem)
/usr/libexec/gvfsd &>/dev/null &

# Start settings daemon components
for component in /usr/libexec/gsd-*; do
    if [ -x "$component" ]; then
        "$component" &>/dev/null &
    fi
done

sleep 2

echo "--- STARTING GNOME SHELL ---"

# Set session environment
export GNOME_SETUP_DISPLAY=:1

# Start GNOME Shell
gnome-shell --x11 --mode=gdm 2>&1 &
GNOME_PID=$!

sleep 5

# Check if GNOME started
if pgrep -x gnome-shell > /dev/null; then
    echo "GNOME Shell started successfully!"
else
    echo "GNOME Shell failed, trying alternative mode..."
    gnome-shell --x11 2>&1 &
    GNOME_PID=$!
    sleep 5
fi

# If still failing, try mutter standalone
if ! pgrep -x gnome-shell > /dev/null; then
    echo "Trying mutter as fallback..."
    mutter --x11 --replace 2>&1 &
    sleep 3
    
    # Start a basic panel/dock
    if command -v gnome-panel &> /dev/null; then
        gnome-panel &
    fi
fi

echo "--- STARTING NOVNC ---"
websockify --web=/usr/share/novnc 7860 localhost:5901 &

GNOME_VERSION=$(gnome-shell --version 2>/dev/null | awk '{print $3}' || echo "unknown")

echo ""
echo "=============================================="
echo "  NYARCH LINUX DESKTOP READY"
echo "  GNOME Version: $GNOME_VERSION"
echo "=============================================="
echo "  VNC Server: port 5901"
echo "  noVNC Web:  port 7860"
echo "=============================================="
echo ""

# Monitor and restart if needed
while true; do
    # Check VNC
    if ! kill -0 $VNC_PID 2>/dev/null; then
        echo "VNC died, restarting..."
        Xtigervnc :1 -geometry 1280x720 -depth 24 -SecurityTypes None -desktop "Nyarch" -ac -pn -rfbport 5901 -AlwaysShared 2>&1 &
        VNC_PID=$!
        sleep 3
    fi
    
    # Check GNOME Shell
    if ! pgrep -x gnome-shell > /dev/null && ! pgrep -x mutter > /dev/null; then
        echo "GNOME Shell died, restarting..."
        gnome-shell --x11 2>&1 &
        sleep 5
    fi
    
    sleep 10

done
