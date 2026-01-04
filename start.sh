#!/bin/bash
set -e

echo "--- STARTING NYARCH CONTAINER (DEBIAN) ---"

# Environment setup
export HOME=/config
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-nyarch
export XDG_CONFIG_HOME=/config/.config
export XDG_DATA_HOME=/config/.local/share
export SHELL=/bin/bash
export USER=nyarch

# Ensure directories exist
mkdir -p ${XDG_RUNTIME_DIR}
mkdir -p /config/.config/dconf
mkdir -p /config/.local/share/gnome-shell/extensions
mkdir -p /config/.local/share/icons
mkdir -p /config/.local/share/themes
chmod 700 ${XDG_RUNTIME_DIR}

# Clean stale VNC locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

echo "--- STARTING DBUS ---"
if [ ! -S /tmp/dbus-session-bus ]; then
    dbus-daemon --session --address="unix:path=/tmp/dbus-session-bus" --fork --print-pid || true
fi
export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-session-bus

echo "--- CHECKING GNOME VERSION ---"
GNOME_VERSION=$(gnome-shell --version 2>/dev/null | awk '{print $3}' || echo "unknown")
GNOME_MAJOR=$(echo $GNOME_VERSION | cut -d. -f1)
echo "Detected GNOME version: $GNOME_VERSION"

if [ "$GNOME_MAJOR" -lt 45 ] 2>/dev/null; then
    echo "WARNING: GNOME $GNOME_VERSION may have compatibility issues with Nyarch extensions"
fi

echo "--- DOWNLOADING NYARCH FILES ---"
cd /tmp

# Get latest release info (with error handling)
LATEST_TAG_VERSION=$(curl -s --max-time 10 https://api.github.com/repos/NyarchLinux/NyarchLinux/releases/latest | grep "tag_name" | awk -F'"' '{print $4}' || echo "")

if [ -z "$LATEST_TAG_VERSION" ]; then
    echo "Could not fetch latest version, using fallback..."
    LATEST_TAG_VERSION="v2.1"  # Fallback version
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
        git clone --depth 1 https://github.com/NyarchLinux/NyarchLinux.git /tmp/NyarchLinux 2>/dev/null || {
            echo "WARNING: Could not download Nyarch files. Continuing with defaults..."
        }
    fi
fi

echo "--- INSTALLING SAFE CUSTOMIZATIONS ---"

# Only copy if source exists - don't overwrite critical system files
safe_copy() {
    src="$1"
    dest="$2"
    if [ -e "$src" ]; then
        cp -rf "$src" "$dest" 2>/dev/null && echo "Copied: $src" || echo "Skip: $src"
    fi
}

# Copy user-level configs only (safe for Debian)
if [ -d "/tmp/NyarchLinux/Gnome/etc/skel" ]; then
    # Copy themes/icons (cosmetic only)
    safe_copy "/tmp/NyarchLinux/Gnome/etc/skel/.local/share/themes" "/config/.local/share/"
    safe_copy "/tmp/NyarchLinux/Gnome/etc/skel/.local/share/icons" "/config/.local/share/"
    
    # Copy extensions (may not all work on GNOME 46)
    if [ -d "/tmp/NyarchLinux/Gnome/etc/skel/.local/share/gnome-shell/extensions" ]; then
        cp -rf /tmp/NyarchLinux/Gnome/etc/skel/.local/share/gnome-shell/extensions/* \
            /config/.local/share/gnome-shell/extensions/ 2>/dev/null || true
        echo "Copied extensions (some may not be GNOME $GNOME_MAJOR compatible)"
    fi
    
    # Copy GTK themes (safe)
    safe_copy "/tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-3.0" "/config/.config/"
    safe_copy "/tmp/NyarchLinux/Gnome/etc/skel/.config/gtk-4.0" "/config/.config/"
fi

echo "--- SKIPPING MATERIAL-YOU-COLORS (GNOME 47+ ONLY) ---"
# The material-you-colors extension requires GNOME 47+
# Uncommment below if you want to try anyway:

# if [ "$GNOME_MAJOR" -ge 47 ] 2>/dev/null; then
#     echo "Installing material-you-colors..."
#     cd /tmp
#     git clone https://github.com/FrancescoCaracciolo/material-you-colors.git 2>/dev/null || true
#     if [ -d "/tmp/material-you-colors" ]; then
#         cd /tmp/material-you-colors
#         make build 2>/dev/null || true
#         make install 2>/dev/null || true
#     fi
# else
#     echo "Skipped: material-you-colors requires GNOME 47+"
# fi

echo "--- APPLYING SAFE DCONF SETTINGS ---"
# Only apply settings that are likely compatible with GNOME 45/46

# Set some basic safe preferences
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true
dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'" 2>/dev/null || true
dconf write /org/gnome/desktop/wm/preferences/button-layout "'appmenu:minimize,maximize,close'" 2>/dev/null || true

# Try loading Nyarch dconf if available (may have warnings)
if [ -d "/tmp/NyarchLinux/Gnome/etc/dconf/db/local.d" ]; then
    echo "Attempting to load Nyarch dconf settings..."
    cd /tmp/NyarchLinux/Gnome/etc/dconf/db/local.d
    
    # Only load interface and background (safest)
    for conf_file in 02-interface 03-background; do
        if [ -f "$conf_file" ]; then
            dconf load / < "$conf_file" 2>/dev/null || echo "Note: Some settings in $conf_file may not apply"
        fi
    done
    
    # Skip extension settings if GNOME < 47 (they reference incompatible extensions)
    if [ "$GNOME_MAJOR" -ge 47 ] 2>/dev/null; then
        [ -f "06-extensions" ] && dconf load / < "06-extensions" 2>/dev/null || true
    else
        echo "Skipped extension dconf settings (GNOME $GNOME_MAJOR < 47)"
    fi
fi

echo "--- STARTING VNC SERVER ---"
# Create xstartup for GNOME
mkdir -p /config/.vnc
cat > /config/.vnc/xstartup << 'EOF'
#!/bin/bash
export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR=/tmp/runtime-nyarch
export DISPLAY=:1

# Start dbus if needed
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
fi

# Start GNOME session
exec gnome-session --session=gnome 2>&1 || exec gnome-shell 2>&1 || exec startx
EOF
chmod +x /config/.vnc/xstartup

# Start VNC
vncserver :1 \
    -geometry 1280x720 \
    -depth 24 \
    -SecurityTypes None \
    --I-KNOW-THIS-IS-INSECURE \
    -xstartup /config/.vnc/xstartup 2>&1 &

# Wait for VNC
echo "Waiting for VNC server..."
for i in {1..30}; do
    if [ -S /tmp/.X11-unix/X1 ]; then
        echo "VNC server started on display :1"
        break
    fi
    sleep 1
done

# Fallback if VNC didn't start
if [ ! -S /tmp/.X11-unix/X1 ]; then
    echo "VNC failed, trying direct Xtigervnc..."
    Xtigervnc :1 -geometry 1280x720 -depth 24 -SecurityTypes None -desktop "Nyarch" &
    sleep 5
fi

echo "--- STARTING NOVNC WEB INTERFACE ---"
websockify --web=/usr/share/novnc 7860 localhost:5901 &

echo ""
echo "=============================================="
echo "  NYARCH DESKTOP READY (Debian Edition)"
echo "  GNOME Version: $GNOME_VERSION"
echo "=============================================="
echo "  Open: https://YOUR-SPACE.hf.space/vnc.html"
echo "=============================================="
echo ""
echo "NOTE: Some Nyarch features require GNOME 47+"
echo "      Running on GNOME $GNOME_VERSION - some extensions disabled"
echo ""

# Keep container alive
tail -f /dev/null
