FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive \
    PUID=1000 \
    PGID=1000 \
    HOME=/config \
    DISPLAY=:1 \
    LIBGL_ALWAYS_SOFTWARE=1

# Install System Core + Build Essentials + Desktop
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo wget curl git procps build-essential libglib2.0-dev \
    python3-full python3-pip python3-dev nodejs npm \
    tigervnc-standalone-server tigervnc-common novnc websockify \
    gnome-core gnome-shell-extensions dbus-x11 xauth x11-xserver-utils \
    dconf-cli unzip fastfetch kitty imagemagick \
    flatpak mesa-utils libgl1-mesa-dri ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Pre-setup Flatpak & Pywal
RUN pip3 install pywal --break-system-packages --no-cache-dir && \
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Setup User 'abc'
RUN groupadd -g 1000 abc && \
    useradd -u 1000 -g abc -d /config -m -s /bin/bash abc && \
    echo "abc ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# VNC and Nyarch Config Directories
RUN mkdir -p /config/.vnc /config/.local/share/icons /config/.local/share/themes /config/.config/nyarch && \
    echo "nyarch" | vncpasswd -f > /config/.vnc/passwd && \
    chmod 600 /config/.vnc/passwd && \
    chown -R abc:abc /config

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

USER abc
WORKDIR /config
EXPOSE 7860

CMD ["/usr/local/bin/start.sh"]
