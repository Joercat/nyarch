FROM debian:13

# Avoid prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# 1. Update and install core dependencies
# Added 'gawk' (standard for debian) and cleared up gnome-core dependencies
RUN apt-get update --fix-missing && apt-get install -y \
    gnome-session \
    gnome-settings-daemon \
    gnome-terminal \
    nautilus \
    tigervnc-standalone-server \
    novnc \
    python3-pip \
    python3-websockify \
    git \
    make \
    nodejs \
    npm \
    curl \
    wget \
    dconf-cli \
    gettext \
    libglib2.0-dev-bin \
    flatpak \
    kitty \
    firefox-esr \
    sudo \
    gawk \
    grep \
    dbus-x11 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Setup Flatpak environment
RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# 3. Setup permissions for Hugging Face User 1000
RUN mkdir -p /config/.config /config/.local/share && \
    chmod -R 777 /config && \
    chown -R 1000:1000 /config

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

USER 1000
ENV HOME=/config
WORKDIR /config

ENTRYPOINT ["/usr/local/bin/start.sh"]
