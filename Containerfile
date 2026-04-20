FROM quay.io/toolbx/arch-toolbox:latest

RUN pacman -Syu --noconfirm \
        base-devel \
        xorg-xinit \
        xf86-video-intel \
        xfce4 \
        xfce4-goodies \
        xterm \
        sudo \
        mesa \
        vulkan-intel \
        vulkan-tools \
        vulkan-icd-loader \
        libva-intel-driver \
        libva-utils \
        pipewire \
        pipewire-pulse \
        pavucontrol \
        firefox \
        htop \
        micro \
        screen \
        vlc \
        jq \
        zed \
        ttf-hack \
        ttf-hack-nerd \
        git \
        rustup \
    && pacman -Scc --noconfirm

# xrdp and GLAMOR-enabled xorgxrdp come from the AUR. makepkg refuses to run as
# root, so spin up a throwaway builder user with passwordless pacman access.
RUN useradd -m -s /bin/bash builder \
    && echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder \
    && chmod 0440 /etc/sudoers.d/builder

USER builder
WORKDIR /home/builder
RUN git clone https://aur.archlinux.org/xrdp.git \
    && cd xrdp \
    && makepkg -si --noconfirm --nocheck --skippgpcheck \
    && cd .. \
    && git clone https://aur.archlinux.org/xorgxrdp-glamor.git \
    && cd xorgxrdp-glamor \
    && makepkg -si --noconfirm --nocheck --skippgpcheck

USER root
RUN rm -rf /home/builder /etc/sudoers.d/builder \
    && userdel builder 2>/dev/null || true

RUN useradd -m -u 1000 -s /bin/bash -G wheel,video,render user \
    && echo 'user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/user \
    && chmod 0440 /etc/sudoers.d/user

RUN printf '%s\n' \
        '#!/bin/sh' \
        'export XDG_SESSION_TYPE=x11' \
        'export GDK_BACKEND=x11' \
        'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' \
        'if [ -r "$HOME/.profile" ]; then . "$HOME/.profile"; fi' \
        'exec dbus-run-session -- startxfce4' \
        > /etc/xrdp/startwm.sh \
    && chmod 0755 /etc/xrdp/startwm.sh

RUN install -d -m 0755 /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
COPY xfce4-terminal.xml /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml

COPY entrypoint.sh /usr/local/bin/rdesktop-entrypoint
RUN chmod 0755 /usr/local/bin/rdesktop-entrypoint

EXPOSE 3389

ENTRYPOINT ["/usr/local/bin/rdesktop-entrypoint"]
