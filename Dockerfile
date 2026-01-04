FROM archlinux:latest

# 1. Install System Dependencies
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm gnome gnome-extra tigervnc novnc python-websockify \
    git base-devel sudo xorg-server-xvfb mesa-utils npm

# 2. Setup User (UID 1000 is standard for most cloud containers)
RUN useradd -m -u 1000 archuser && \
    echo "archuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# 3. Pre-cloning Nyarch assets to avoid "cannot stat" errors
WORKDIR /tmp
RUN git clone https://github.com/NyarchLinux/Nyarcher.git NyarchLinux

USER archuser
WORKDIR /home/archuser

# 4. Environment Variables for GNOME and VNC
ENV DISPLAY=:1
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV XDG_RUNTIME_DIR=/tmp/runtime-archuser

COPY --chown=archuser:archuser start.sh /home/archuser/start.sh
RUN chmod +x /home/archuser/start.sh

CMD ["/home/archuser/start.sh"]
