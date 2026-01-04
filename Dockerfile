FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/config
ENV DISPLAY=:1
ENV XDG_RUNTIME_DIR=/tmp/runtime-nyarch
ENV XDG_CONFIG_HOME=/config/.config
ENV XDG_DATA_HOME=/config/.local/share
ENV XDG_CACHE_HOME=/config/.cache
ENV XDG_SESSION_TYPE=x11
ENV XDG_CURRENT_DESKTOP=GNOME
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV NO_AT_BRIDGE=1

# Install packages - Fixed for Debian 13 (Trixie)
RUN apt-get update && apt-get install -y \
    gnome-session \
    gnome-shell \
    gnome-settings-daemon \
    gnome-terminal \
    gnome-tweaks \
    nautilus \
    mutter \
    tigervnc-standalone-server \
    novnc \
    python3-websockify \
    git \
    curl \
    wget \
    dconf-cli \
    dbus-x11 \
    xfonts-base \
    x11-xserver-utils \
    x11-utils \
    adwaita-icon-theme \
    gnome-backgrounds \
    firefox-esr \
    kitty \
    sudo \
    mesa-utils \
    libgl1 \
    libegl1 \
    xauth \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd -m -u 1000 -d /config -s /bin/bash nyarch && \
    echo "nyarch ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    usermod -aG sudo nyarch

# Setup directories
RUN mkdir -p /config/.config/dconf \
    /config/.config/tigervnc \
    /config/.local/share/gnome-shell/extensions \
    /config/.local/share/icons \
    /config/.local/share/themes \
    /config/.vnc \
    /config/.cache \
    /tmp/.X11-unix \
    ${XDG_RUNTIME_DIR} && \
    chmod 1777 /tmp/.X11-unix && \
    chmod 700 ${XDG_RUNTIME_DIR} && \
    chown -R nyarch:nyarch /config ${XDG_RUNTIME_DIR}

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

USER nyarch
WORKDIR /config

EXPOSE 7860


ENTRYPOINT ["/usr/local/bin/start.sh"]
