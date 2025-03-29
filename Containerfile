ARG SOURCE_IMAGE="silverblue"
ARG SOURCE_SUFFIX="main"
ARG FEDORA_VERSION="42"
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}-${SOURCE_SUFFIX}:${FEDORA_VERSION}

# User files
COPY usr /usr
COPY packages.json /tmp/packages.json
COPY build.sh /tmp/build.sh
RUN chmod +x /tmp/build.sh

# Clone the Tela icon theme repository and run the installation script
RUN git clone https://github.com/vinceliuice/Tela-icon-theme.git /tmp/Tela-icon-theme && \
    cd /tmp/Tela-icon-theme && \
    chmod +x install.sh && \
    ./install.sh -d /usr/share/icons

# Handle packages via packages.json
RUN /tmp/build.sh

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
