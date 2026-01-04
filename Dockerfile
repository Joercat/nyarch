FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/config
ENV DISPLAY=:1
ENV XDG_RUNTIME_DIR=/run/user/1000
ENV XDG_CONFIG_HOME=/config/.config
ENV XDG_DATA_HOME=/config/.local/share
ENV XDG_CACHE_HOME=/config/.cache
ENV XDG_SESSION_TYPE=x11
ENV XDG_CURRENT_DESKTOP=GNOME
ENV XDG_SESSION_DESKTOP=gnome
ENV DESKTOP_SESSION=gnome
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV NO_AT_BRIDGE=1
ENV GSK_RENDERER=cairo

# Stage 1: Install elogind FIRST before anything else
RUN apt-get update && apt-get install -y --no-install-recommends \
    elogind \
    dbus \
    dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Core GNOME (will use elogind)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnome-session \
    gnome-shell \
    gnome-settings-daemon \
    gnome-control-center \
    gnome-terminal \
    gnome-tweaks \
    gnome-shell-extensions \
    nautilus \
    mutter \
    gjs \
    && rm -rf /var/lib/apt/lists/*

# Stage 3: VNC and display
RUN apt-get update && apt-get install -y --no-install-recommends \
    tigervnc-standalone-server \
    novnc \
    python3-websockify \
    xfonts-base \
    x11-xserver-utils \
    x11-utils \
    xauth \
    && rm -rf /var/lib/apt/lists/*

# Stage 4: Utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    dconf-cli \
    dbus-user-session \
    sudo \
    mesa-utils \
    libgl1 \
    libegl1 \
    make \
    nodejs \
    npm \
    gettext \
    ca-certificates \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Stage 5: GNOME services (minimal - avoid conflicts)
RUN apt-get update && apt-get install -y --no-install-recommends \
    at-spi2-core \
    gvfs \
    gvfs-daemons \
    gnome-keyring \
    libsecret-1-0 \
    && rm -rf /var/lib/apt/lists/*

# Stage 6: Optional services (may fail, that's ok)
RUN apt-get update && apt-get install -y --no-install-recommends \
    colord \
    polkitd \
    accountsservice \
    upower \
    udisks2 \
    || true \
    && rm -rf /var/lib/apt/lists/*

# Stage 7: Apps and themes
RUN apt-get update && apt-get install -y --no-install-recommends \
    adwaita-icon-theme \
    gnome-backgrounds \
    firefox-esr \
    kitty \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd -m -u 1000 -d /config -s /bin/bash nyarch && \
    echo "nyarch ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    usermod -aG sudo,video nyarch

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
    /run/elogind \
    && chmod 1777 /tmp/.X11-unix \
    && chmod 700 /run/user/1000 \
    && chown -R nyarch:nyarch /config /run/user/1000

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

WORKDIR /config

EXPOSE 7860


ENTRYPOINT ["/usr/local/bin/start.sh"]
