FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    gnome-session gnome-settings-daemon gnome-terminal nautilus \
    tigervnc-standalone-server novnc python3-websockify \
    git make nodejs npm curl wget dconf-cli gettext libglib2.0-dev-bin \
    flatpak kitty firefox-esr sudo gawk dbus-x11 libnss-wrapper \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Pre-setup the folder structure
RUN mkdir -p /config/.config /config/.local/share /config/.vnc && \
    chmod -R 777 /config

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# This is critical for VNC to know 'who you are'
RUN echo "nyarch:x:1000:1000:Nyarch,,,:/config:/bin/bash" > /tmp/passwd.template

USER 1000
ENV HOME=/config
WORKDIR /config

ENTRYPOINT ["/usr/local/bin/start.sh"]
