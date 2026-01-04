#!/bin/bash

echo "--- STARTING NYARCH CONTAINER (GNOME) ---"

# Run setup as root first
if [ "$(id -u)" = "0" ]; then
    echo "Running initial setup as root..."
    
    # Create runtime directories
    mkdir -p /run/dbus
    mkdir -p /run/user/1000
    mkdir -p /run/elogind
    mkdir -p /tmp/.X11-unix
    
    chmod 1777 /tmp/.X11-unix
    chmod 700 /run/user/1000
    chown nyarch:nyarch /run/user/1000
    
    # Start system dbus FIRST
    if [ ! -S /run/dbus/system_bus_socket ]; then
        echo "Starting system dbus..."
        dbus-daemon --system --fork --nopidfile
        sleep 2
    fi
    
    # Start elogind (provides org.freedesktop.login1)
    echo "Starting elogind..."
    /usr/libexec/elogind/elogind &
    sleep 2
    
    # Verify elogind is running
    if busctl status org.freedesktop.login1 &>/dev/null; then
        echo "elogind is running!"
    else
        echo "WARNING: elogind may not be fully running"
        # Try alternative path
        /lib/elogind/elogind &>/dev/null &
        sleep 2
    fi
    
    # Start other system services
    echo "Starting colord..."
    /usr/libexec/colord &>/dev/null &
    
    echo "Starting accounts-daemon..."
    /usr/libexec/accounts-daemon &>/dev/null &
    
    echo "Starting upowerd..."
    /usr/libexec/upowerd &>/dev/null &
    
    echo "Starting udisksd..."
    /usr/libexec/udisks2/udisksd &>/dev/null &
    
    echo "Starting polkitd..."
    /usr/libexec/polkitd &>/dev/null &
    
    sleep 2
    
    # Register a session with elogind
    echo "Registering elogind session..."
    loginctl enable-linger nyarch 2>/dev/null || true
    
    # Switch to nyarch user
    echo "Switching to nyarch user..."
    exec sudo -u nyarch -E env \
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
        XDG_SESSION_CLASS=user \
        DESKTOP_SESSION=gnome \
        LIBGL_ALWAYS_SOFTWARE=1 \
        GSK_RENDERER=cairo \
        NO_AT_BRIDGE=1 \
        /usr/local/bin/start.sh
fi

# --- Now running as nyarch ---
echo "Running as: $(whoami) (UID: $(id -u))"

# Export environment
export HOME=/config
export DISPLAY=:1
export XDG_RUNTIME_DIR=/run/user/1000
export XDG_CONFIG_HOME=/config/.config
export XDG_DATA_HOME=/config/.local/share
export XDG_CACHE_HOME=/config/.cache
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_DESKTOP=gnome
export XDG_SESSION_CLASS=user
export DESKTOP_SESSION=gnome
export LIBGL_ALWAYS_SOFTWARE=1
export GSK_RENDERER=cairo
export NO_AT_BRIDGE=1
export SHELL=/bin/bash

# Clean stale X locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

echo "--- STARTING SESSION DBUS ---"
DBUS_SOCKET="/run/user/1000/bus"
rm -f "$DBUS_SOCKET" 2>/dev/null || true

dbus-daemon --session --address="unix:path=$DBUS_SOCKET" --fork --print-pid
export DBUS_SESSION_BUS_ADDRESS="unix:path=$DBUS_SOCKET"
echo "Session DBUS: $DBUS_SESSION_BUS_ADDRESS"

# Save for other processes
echo "export DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS" > /run/user/1000/dbus-env
chmod 644 /run/user/1000/dbus-env

echo "--- STARTING GNOME KEYRING ---"
eval $(gnome-keyring-daemon --start --components=secrets,ssh,pkcs11 2>/dev/null) || true
export GNOME_KEYRING_CONTROL
export SSH_AUTH_SOCK

echo "--- DOWNLOADING NYARCH FILES ---"
cd /tmp

LATEST_TAG_VERSION=$(curl -s --max-time 10 https://api.github.com/repos/NyarchLinux/NyarchLinux/releases/latest | grep "tag_name" | awk -F'"' '{print $4}' || echo "25.04.3")
RELEASE_LINK="https://github.com/NyarchLinux/NyarchLinux/releases/download/$LATEST_TAG_VERSION/"
echo "Using Nyarch version: $LATEST_TAG_VERSION"

if [ ! -d "/tmp/NyarchLinux" ]; then
    echo "Downloading NyarchLinux tarball..."
    if wget -q --timeout=60 -O /tmp/NyarchLinux.tar.gz "${RELEASE_LINK}NyarchLinux.tar.gz" 2>/dev/null; then
        tar -xzf NyarchLinux.tar.gz 2>/dev/null || true
        echo "Extracted tarball"
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
    echo "Installed GNOME extensions"
fi

# Copy themes
if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes/* \
        /config/.local/share/themes/ 2>/dev/null || true
    echo "Installed themes"
fi

# Copy icons
if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.local/share/icons" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/icons/* \
        /config/.local/share/icons/ 2>/dev/null || true
    echo "Installed icons"
fi

# Copy GTK configs
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-3.0 /config/.config/ 2>/dev/null || true
cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0 /config/.config/ 2>/dev/null || true

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
        echo "Installed Material-You-Colors"
    fi
fi

echo "--- APPLYING DCONF SETTINGS ---"
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true
dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'" 2>/dev/null || true
dconf write /org/gnome/desktop/wm/preferences/button-layout "'appmenu:minimize,maximize,close'" 2>/dev/null || true

if [ -d "/tmp/NyarchLinux/Gnome/etc/dconf/db/local.d" ]; then
    cd /tmp/NyarchLinux/Gnome/etc/dconf/db/local.d
    for conf in 02-interface 03-background 04-wmpreferences 06-extensions; do
        [ -f "$conf" ] && dconf load / < "$conf" 2>/dev/null || true
    done
    echo "Applied dconf settings"
fi

echo "--- STARTING VNC SERVER ---"
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

echo "Waiting for X server..."
for i in $(seq 1 30); do
    if xdpyinfo -display :1 >/dev/null 2>&1; then
        echo "X server ready!"
        break
    fi
    sleep 1
done

if ! xdpyinfo -display :1 >/dev/null 2>&1; then
    echo "ERROR: X server failed!"
    exit 1
fi

echo "--- STARTING GNOME SERVICES ---"

# Start accessibility
DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" /usr/libexec/at-spi-bus-launcher --launch-immediately &>/dev/null &
DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" /usr/libexec/at-spi2-registryd &>/dev/null &

# Start gvfs
DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" /usr/libexec/gvfsd &>/dev/null &

# Start settings daemons
echo "Starting GNOME settings daemons..."
for gsd in /usr/libexec/gsd-*; do
    if [ -x "$gsd" ]; then
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        DISPLAY=:1 \
        XDG_CURRENT_DESKTOP=GNOME \
        "$gsd" &>/dev/null &
    fi
done

sleep 3

echo "--- STARTING GNOME SHELL ---"
echo "DBUS: $DBUS_SESSION_BUS_ADDRESS"

# Use gnome-session to properly start the shell
DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
DISPLAY=:1 \
XDG_RUNTIME_DIR=/run/user/1000 \
XDG_CURRENT_DESKTOP=GNOME \
XDG_SESSION_TYPE=x11 \
XDG_SESSION_DESKTOP=gnome \
LIBGL_ALWAYS_SOFTWARE=1 \
GSK_RENDERER=cairo \
gnome-session --session=gnome 2>&1 &

GNOME_PID=$!

sleep 8

if pgrep -x gnome-shell > /dev/null; then
    echo "GNOME Shell running!"
else
    echo "Trying direct gnome-shell..."
    
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    DISPLAY=:1 \
    XDG_RUNTIME_DIR=/run/user/1000 \
    gnome-shell --x11 2>&1 &
    
    sleep 5
fi

if ! pgrep -x gnome-shell > /dev/null; then
    echo "Starting mutter + nautilus fallback..."
    
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    DISPLAY=:1 \
    mutter --x11 --replace 2>&1 &
    
    sleep 2
    
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    DISPLAY=:1 \
    nautilus --new-window /config &>/dev/null &
    
    # Add a panel alternative
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    DISPLAY=:1 \
    gnome-control-center &>/dev/null &
fi

echo "--- STARTING NOVNC ---"
websockify --web=/usr/share/novnc 7860 localhost:5901 &

GNOME_VER=$(gnome-shell --version 2>/dev/null | awk '{print $3}' || echo "unknown")

echo ""
echo "=============================================="
echo "  NYARCH LINUX READY"
echo "  GNOME: $GNOME_VER"
echo "  DBUS: $DBUS_SESSION_BUS_ADDRESS"
echo "=============================================="
echo "  Web Access: port 7860"
echo "=============================================="
echo ""

# Monitor loop
while true; do
    source /run/user/1000/dbus-env 2>/dev/null || true
    
    if ! kill -0 $VNC_PID 2>/dev/null; then
        echo "Restarting VNC..."
        Xtigervnc :1 -geometry 1280x720 -depth 24 -SecurityTypes None -desktop "Nyarch" -ac -pn -rfbport 5901 -AlwaysShared 2>&1 &
        VNC_PID=$!
        sleep 3
    fi
    
    if ! pgrep -x gnome-shell > /dev/null && ! pgrep -x mutter > /dev/null; then
        echo "Restarting desktop..."
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        DISPLAY=:1 \
        gnome-shell --x11 2>&1 &
        sleep 5
    fi
    
    sleep 10

done
