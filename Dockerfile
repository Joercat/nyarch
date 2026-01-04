FROM debian:trixie

# Install system dependencies required by the Nyarch script
RUN apt-get update && apt-get install -y \
    gnome-core tigervnc-standalone-server novnc python3-pip \
    python3-websockify git make nodejs npm curl wget dconf-cli \
    gettext libglib2.0-dev-bin flatpak kitty firefox-esr sudo \
    awk grep && \
    rm -rf /var/lib/apt/lists/*

# Pre-setup the Flatpak environment (needed for the 'install_flatpaks' section)
RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Create the user config area
RUN mkdir -p /config/.config /config/.local/share && \
    chmod -R 777 /config && \
    chown -R 1000:1000 /config

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

USER 1000
ENV HOME=/config
WORKDIR /config

ENTRYPOINT ["/usr/local/bin/start.sh"]
