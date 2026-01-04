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
ENV XDG_SESSION_DESKTOP=gnome
ENV DESKTOP_SESSION=gnome
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV NO_AT_BRIDGE=1
ENV GNOME_SHELL_SESSION_MODE=ubuntu
ENV GSK_RENDERER=cairo

# Install GNOME and required services
RUN apt-get update && apt-get install -y \
    gnome-session \
    gnome-shell \
    gnome-settings-daemon \
    gnome-control-center \
    gnome-terminal \
    gnome-tweaks \
    gnome-shell-extensions \
    gnome-shell-extension-prefs \
    nautilus \
    mutter \
    gjs \
    tigervnc-standalone-server \
    novnc \
    python3-websockify \
    git \
    curl \
    wget \
    dconf-cli \
    dbus-x11 \
    dbus-user-session \
    xfonts-base \
    x11-xserver-utils \
    x11-utils \
    xauth \
    adwaita-icon-theme \
    gnome-backgrounds \
    firefox-esr \
    kitty \
    sudo \
    mesa-utils \
    libgl1 \
    libegl1 \
    # Services that GNOME needs
    colord \
    policykit-1 \
    libpam-systemd \
    systemd \
    systemd-sysv \
    elogind \
    libelogind0 \
    libpam-elogind \
    at-spi2-core \
    accountsservice \
    udisks2 \
    upower \
    gvfs \
    gvfs-backends \
    gvfs-daemons \
    gnome-keyring \
    gcr \
    make \
    nodejs \
    npm \
    gettext \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create user BEFORE setting up elogind
RUN useradd -m -u 1000 -d /config -s /bin/bash nyarch && \
    echo "nyarch ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    usermod -aG sudo,video,render nyarch

# Setup directories
RUN mkdir -p /config/.config/dconf \
    /config/.config/tigervnc \
    /config/.config/gnome-shell \
    /config/.local/share/gnome-shell/extensions \
    /config/.local/share/icons \
    /config/.local/share/themes \
    /config/.local/share/applications \
    /config/.vnc \
    /config/.cache \
    /tmp/.X11-unix \
    /run/user/1000 \
    /run/dbus \
    ${XDG_RUNTIME_DIR} && \
    chmod 1777 /tmp/.X11-unix && \
    chmod 700 ${XDG_RUNTIME_DIR} /run/user/1000 && \
    chown -R nyarch:nyarch /config ${XDG_RUNTIME_DIR} /run/user/1000

# Create stub services for container environment
RUN mkdir -p /run/systemd/seats /run/systemd/users /run/systemd/sessions && \
    echo "ACTIVE=1" > /run/systemd/seats/seat0 && \
    echo "LEADER=1" > /run/systemd/users/1000 && \
    echo "ACTIVE=1\nIS_DISPLAY=1\nSTATE=active\nTYPE=x11" > /run/systemd/sessions/1

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Don't switch to user yet - start.sh will handle permissions
WORKDIR /config

EXPOSE 7860


ENTRYPOINT ["/usr/local/bin/start.sh"]
