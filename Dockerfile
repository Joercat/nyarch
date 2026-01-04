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
ENV GSK_RENDERER=cairo

# Install packages in stages to identify issues
# Stage 1: Core GNOME
RUN apt-get update && apt-get install -y \
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

# Stage 2: VNC and display
RUN apt-get update && apt-get install -y \
    tigervnc-standalone-server \
    novnc \
    python3-websockify \
    xfonts-base \
    x11-xserver-utils \
    x11-utils \
    xauth \
    && rm -rf /var/lib/apt/lists/*

# Stage 3: Utilities
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    dconf-cli \
    dbus-x11 \
    dbus-user-session \
    sudo \
    mesa-utils \
    libgl1 \
    libegl1 \
    make \
    nodejs \
    npm \
    gettext \
    && rm -rf /var/lib/apt/lists/*

# Stage 4: GNOME services (NO systemd/elogind - they conflict)
RUN apt-get update && apt-get install -y \
    colord \
    policykit-1 \
    at-spi2-core \
    accountsservice \
    udisks2 \
    upower \
    gvfs \
    gvfs-backends \
    gvfs-daemons \
    gnome-keyring \
    libsecret-1-0 \
    && rm -rf /var/lib/apt/lists/*

# Stage 5: Apps and themes
RUN apt-get update && apt-get install -y \
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
    /run/systemd/seats \
    /run/systemd/users \
    /run/systemd/sessions \
    && chmod 1777 /tmp/.X11-unix \
    && chmod 700 /run/user/1000 \
    && chown -R nyarch:nyarch /config /run/user/1000

# Create fake systemd session files (for loginctl emulation)
RUN echo -e "ACTIVE_SESSIONS=1\nCAN_GRAPHICAL=1" > /run/systemd/seats/seat0 && \
    echo -e "NAME=nyarch\nSTATE=active\nSESSIONS=1" > /run/systemd/users/1000 && \
    echo -e "USER=1000\nSEAT=seat0\nACTIVE=1\nTYPE=x11\nDESKTOP=gnome\nDISPLAY=:1" > /run/systemd/sessions/1

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

WORKDIR /config

EXPOSE 7860


ENTRYPOINT ["/usr/local/bin/start.sh"]FROM debian:13
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
ENV GSK_RENDERER=cairo

# Install packages in stages to identify issues
# Stage 1: Core GNOME
RUN apt-get update && apt-get install -y \
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

# Stage 2: VNC and display
RUN apt-get update && apt-get install -y \
    tigervnc-standalone-server \
    novnc \
    python3-websockify \
    xfonts-base \
    x11-xserver-utils \
    x11-utils \
    xauth \
    && rm -rf /var/lib/apt/lists/*

# Stage 3: Utilities
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    dconf-cli \
    dbus-x11 \
    dbus-user-session \
    sudo \
    mesa-utils \
    libgl1 \
    libegl1 \
    make \
    nodejs \
    npm \
    gettext \
    && rm -rf /var/lib/apt/lists/*

# Stage 4: GNOME services (NO systemd/elogind - they conflict)
RUN apt-get update && apt-get install -y \
    colord \
    policykit-1 \
    at-spi2-core \
    accountsservice \
    udisks2 \
    upower \
    gvfs \
    gvfs-backends \
    gvfs-daemons \
    gnome-keyring \
    libsecret-1-0 \
    && rm -rf /var/lib/apt/lists/*

# Stage 5: Apps and themes
RUN apt-get update && apt-get install -y \
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
    /run/systemd/seats \
    /run/systemd/users \
    /run/systemd/sessions \
    && chmod 1777 /tmp/.X11-unix \
    && chmod 700 /run/user/1000 \
    && chown -R nyarch:nyarch /config /run/user/1000

# Create fake systemd session files (for loginctl emulation)
RUN echo -e "ACTIVE_SESSIONS=1\nCAN_GRAPHICAL=1" > /run/systemd/seats/seat0 && \
    echo -e "NAME=nyarch\nSTATE=active\nSESSIONS=1" > /run/systemd/users/1000 && \
    echo -e "USER=1000\nSEAT=seat0\nACTIVE=1\nTYPE=x11\nDESKTOP=gnome\nDISPLAY=:1" > /run/systemd/sessions/1

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

WORKDIR /config

EXPOSE 7860

ENTRYPOINT ["/usr/local/bin/start.sh"]
