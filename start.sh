#!/bin/bash
set -e

echo "--- STARTING NYARCH CONTAINER (DEBIAN) ---"

# Environment setup
export HOME=/config
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-nyarch
export XDG_CONFIG_HOME=/config/.config
export XDG_DATA_HOME=/config/.local/share
export XDG_CACHE_HOME=/config/.cache
export XDG_SESSION_TYPE=x11
export XDG_SESSION_CLASS=user
export XDG_CURRENT_DESKTOP=GNOME
export SHELL=/bin/bash
export USER=nyarch
export NO_AT_BRIDGE=1
export LIBGL_ALWAYS_SOFTWARE=1
export MESA_GL_VERSION_OVERRIDE=3.3

# Create required directories
mkdir -p ${XDG_RUNTIME_DIR}
mkdir -p /config/.config/dconf
mkdir -p /config/.local/share/gnome-shell/extensions
mkdir -p /config/.local/share/icons
mkdir -p /config/.local/share/themes
mkdir -p /config/.cache
mkdir -p /config/.config/tigervnc
chmod 700 ${XDG_RUNTIME_DIR}

# Create X11 unix socket directory (needed for non-root)
sudo mkdir -p /tmp/.X11-unix
sudo chmod 1777 /tmp/.X11-unix
sudo chown root:root /tmp/.X11-unix

# Clean stale VNC locks
rm -f /tmp/.X1-lock 2>/dev/null || true
rm -f /tmp/.X11-unix/X1 2>/dev/null || true

echo "--- STARTING DBUS ---"
# Kill any existing dbus
pkill -f "dbus-daemon.*session" 2>/dev/null || true

# Start fresh dbus session
eval $(dbus-launch --sh-syntax)
export DBUS_SESSION_BUS_ADDRESS
echo "DBUS: $DBUS_SESSION_BUS_ADDRESS"

echo "--- CHECKING GNOME VERSION ---"
GNOME_VERSION=$(gnome-shell --version 2>/dev/null | awk '{print $3}' || echo "unknown")
echo "Detected GNOME version: $GNOME_VERSION"

echo "--- DOWNLOADING NYARCH FILES ---"
cd /tmp

# Get latest release info
LATEST_TAG_VERSION=$(curl -s --max-time 10 https://api.github.com/repos/NyarchLinux/NyarchLinux/releases/latest | grep "tag_name" | awk -F'"' '{print $4}' || echo "")

if [ -z "$LATEST_TAG_VERSION" ]; then
    LATEST_TAG_VERSION="v2.1"
fi

RELEASE_LINK="https://github.com/NyarchLinux/NyarchLinux/releases/download/$LATEST_TAG_VERSION/"
echo "Using version: $LATEST_TAG_VERSION"

# Download tarball
if [ ! -d "/tmp/NyarchLinux" ]; then
    echo "Downloading NyarchLinux tarball..."
    if wget -q --timeout=30 -O /tmp/NyarchLinux.tar.gz "${RELEASE_LINK}NyarchLinux.tar.gz"; then
        tar -xzf NyarchLinux.tar.gz 2>/dev/null || true
    else
        echo "Tarball download failed, trying git..."
        git clone --depth 1 https://github.com/NyarchLinux/NyarchLinux.git /tmp/NyarchLinux 2>/dev/null || true
    fi
fi

echo "--- INSTALLING CUSTOMIZATIONS ---"

# Copy configs if they exist
if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes/* /config/.local/share/themes/ 2>/dev/null || true
fi

if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.local/share/icons" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/icons/* /config/.local/share/icons/ 2>/dev/null || true
fi

if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.local/share/gnome-shell/extensions" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/gnome-shell/extensions/* \
        /config/.local/share/gnome-shell/extensions/ 2>/dev/null || true
fi

if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-3.0" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-3.0 /config/.config/ 2>/dev/null || true
fi

if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0" ]; then
    cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0 /config/.config/ 2>/dev/null || true
fi

echo "--- APPLYING DCONF SETTINGS ---"
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true
dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'" 2>/dev/null || true
dconf write /org/gnome/desktop/wm/preferences/button-layout "'appmenu:minimize,maximize,close'" 2>/dev/null || true

if [ -d "/tmp/NyarchLinux/Gnome/etc/dconf/db/local.d" ]; then
    cd /tmp/NyarchLinux/Gnome/etc/dconf/db/local.d
    for conf_file in 02-interface 03-background 04-wmpreferences 06-extensions; do
        if [ -f "$conf_file" ]; then
            dconf load / < "$conf_file" 2>/dev/null || true
        fi
    done
fi

echo "--- STARTING VNC SERVER ---"

# Create xstartup script that actually launches GNOME
cat > /config/.vnc/xstartup << 'XSTARTUP'
#!/bin/bash

# Environment
export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR=/tmp/runtime-nyarch
export XDG_CONFIG_HOME=/config/.config
export XDG_DATA_HOME=/config/.local/share
export XDG_CACHE_HOME=/config/.cache
export XDG_CURRENT_DESKTOP=GNOME
export DISPLAY=:1
export HOME=/config
export LIBGL_ALWAYS_SOFTWARE=1
export NO_AT_BRIDGE=1

# Start dbus if not running
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Start gnome-settings-daemon components
/usr/libexec/gsd-xsettings &

# Try different ways to start GNOME
if command -v gnome-shell &> /dev/null; then
    echo "Starting gnome-shell..."
    gnome-shell --x11 2>&1 &
    sleep 2
fi

# If gnome-shell fails, try gnome-session
if ! pgrep -x gnome-shell > /dev/null; then
    echo "Trying gnome-session..."
    gnome-session --session=gnome 2>&1 &
fi

# Keep xstartup alive
wait
XSTARTUP

chmod +x /config/.vnc/xstartup

# Create tigervnc config
mkdir -p /config/.config/tigervnc
cat > /config/.config/tigervnc/vncserver-config-defaults << 'VNCCONF'
$geometry = "1280x720";
$depth = 24;
$SecurityTypes = "None";
$localhost = "no";
$desktopName = "Nyarch";
VNCCONF

# Start Xtigervnc directly (more control than vncserver wrapper)
echo "Starting Xtigervnc..."
Xtigervnc :1 \
    -geometry 1280x720 \
    -depth 24 \
    -SecurityTypes None \
    -desktop "Nyarch" \
    -ac \
    -pn \
    -rfbport 5901 \
    2>&1 &

XVNC_PID=$!

# Wait for X server to be ready
echo "Waiting for X server..."
for i in {1..30}; do
    if xdpyinfo -display :1 >/dev/null 2>&1; then
        echo "X server is ready!"
        break
    fi
    sleep 1
done

if ! xdpyinfo -display :1 >/dev/null 2>&1; then
    echo "ERROR: X server failed to start"
    exit 1
fi

echo "--- STARTING GNOME DESKTOP ---"

# Start GNOME shell directly on the display
export DISPLAY=:1

# Start dbus components needed by GNOME
dbus-launch --exit-with-session &

# Start gnome-shell in X11 mode
echo "Launching gnome-shell..."
gnome-shell --x11 2>&1 &
GNOME_PID=$!

# Wait a moment and check if it started
sleep 5

if pgrep -x gnome-shell > /dev/null; then
    echo "GNOME Shell started successfully!"
else
    echo "gnome-shell failed, trying fallback..."
    # Fallback: try basic window manager
    if command -v mutter &> /dev/null; then
        mutter --replace --x11 2>&1 &
    elif command -v metacity &> /dev/null; then
        metacity --replace 2>&1 &
    else
        echo "No window manager available!"
    fi
fi

echo "--- STARTING NOVNC WEB INTERFACE ---"
websockify --web=/usr/share/novnc 7860 localhost:5901 &

echo ""
echo "=============================================="
echo "  NYARCH DESKTOP READY"
echo "  GNOME Version: $GNOME_VERSION"
echo "=============================================="
echo "  VNC Server: :1 (port 5901)"
echo "  noVNC Web: port 7860"
echo "=============================================="
echo ""

# Keep container alive and monitor
while true; do
    # Restart gnome-shell if it dies
    if ! pgrep -x gnome-shell > /dev/null; then
        echo "gnome-shell died, restarting..."
        DISPLAY=:1 gnome-shell --x11 2>&1 &
    fi
    
    # Restart Xtigervnc if it dies
    if ! kill -0 $XVNC_PID 2>/dev/null; then
        echo "Xtigervnc died, restarting..."
        Xtigervnc :1 -geometry 1280x720 -depth 24 -SecurityTypes None -desktop "Nyarch" -ac -pn -rfbport 5901 2>&1 &
        XVNC_PID=$!
    fi
    
    sleep 10

done
