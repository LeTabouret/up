ARG SOURCE_IMAGE="silverblue"
ARG SOURCE_SUFFIX="main"
ARG FEDORA_VERSION="39"
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}-${SOURCE_SUFFIX}:${FEDORA_VERSION}

# User files
COPY usr /usr

# install and remove a package
RUN rpm-ostree install \
    virt-manager \
    qemu-kvm \
    libvirt \
    mesa-vulkan-drivers \
    vulkan-loader \
    pipewire-alsa \
    pipewire-libs \
    steam \
    systemd-libs \
    gnome-shell-extension-pop-shell \
    langpacks-en

RUN rpm-ostree override remove \
    firefox \
    firefox-langpacks \
    gnome-classic-session \
    gnome-shell-extension-launch-new-instance \
    gnome-shell-extension-places-menu \
    gnome-shell-extension-window-list \
    gnome-shell-extension-background-logo \
    gnome-shell-extension-apps-menu \
    toolbox

# Flatpaks
RUN mkdir -p /usr/etc/flatpak/remotes.d && \
    wget -q https://dl.flathub.org/repo/flathub.flatpakrepo -P /usr/etc/flatpak/remotes.d && \
    systemctl --global enable ublue-user-flatpak-manager.service

# Configure GNOME
RUN systemctl enable dconf-update.service && \
    fc-cache -f /usr/share/fonts/Inter && \
    fc-cache -f /usr/share/fonts/JetBrains

# Clean up
RUN rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:phracek:PyCharm.repo && \
    rm -f /etc/yum.repos.d/fedora-cisco-openh264.repo && \
    rm -rf /tmp/* /var/* && \
    echo "Hidden=true" >> /usr/share/applications/htop.desktop && \
    echo "Hidden=true" >> /usr/share/applications/nvtop.desktop && \
    ostree container commit && \
    mkdir -p /var/tmp && \
    chmod -R 1777 /var/tmp
