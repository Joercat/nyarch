FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/config
ENV DISPLAY=:1
ENV XDG_RUNTIME_DIR=/tmp/runtime-nyarch
ENV XDG_CONFIG_HOME=/config/.config
ENV XDG_DATA_HOME=/config/.local/share
ENV DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-session-bus

# Install packages
RUN apt-get update && apt-get install -y \
    gnome-session gnome-settings-daemon gnome-terminal nautilus \
    gnome-shell gnome-tweaks gnome-shell-extensions \
    tigervnc-standalone-server novnc python3-websockify \
    git make nodejs npm curl wget dconf-cli gettext libglib2.0-dev-bin \
    flatpak kitty firefox-esr sudo gawk dbus-x11 \
    xfonts-base xfonts-75dpi xfonts-100dpi x11-xserver-utils \
    libcanberra-gtk3-module packagekit-gtk3-module \
    adwaita-icon-theme-full gnome-backgrounds \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create actual user instead of using nss_wrapper
RUN useradd -m -u 1000 -d /config -s /bin/bash nyarch && \
    echo "nyarch ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Setup directory structure
RUN mkdir -p /config/.config /config/.local/share/gnome-shell/extensions \
    /config/.local/share/icons /config/.local/share/themes \
    /config/.vnc /config/.cache ${XDG_RUNTIME_DIR} && \
    chmod 700 ${XDG_RUNTIME_DIR}

# VNC config - no password
RUN echo "session=gnome" > /config/.vnc/config && \
    echo "geometry=1280x720" >> /config/.vnc/config && \
    echo "localhost=no" >> /config/.vnc/config && \
    echo "SecurityTypes=None" >> /config/.vnc/config

# Fix ownership
RUN chown -R nyarch:nyarch /config ${XDG_RUNTIME_DIR}

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

USER nyarch
WORKDIR /config

EXPOSE 7860

ENTRYPOINT ["/usr/local/bin/start.sh"] 
