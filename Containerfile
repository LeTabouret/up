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
    steam \
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

# Adding VRR to Gnome
RUN wget https://copr.fedorainfracloud.org/coprs/kylegospo/gnome-vrr/repo/fedora-"${FEDORA_MAJOR_VERSION}"/kylegospo-gnome-vrr-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/_copr_kylegospo-gnome-vrr.repo && \
    rpm-ostree override replace --experimental --from repo=copr:copr.fedorainfracloud.org:kylegospo:gnome-vrr mutter mutter-common gnome-control-center gnome-control-center-filesystem && \
    rm -f /etc/yum.repos.d/_copr_kylegospo-gnome-vrr.repo

# Flatpaks
RUN mkdir -p /usr/etc/flatpak/remotes.d && \
    wget -q https://dl.flathub.org/repo/flathub.flatpakrepo -P /usr/etc/flatpak/remotes.d && \
    systemctl --global enable ublue-user-flatpak-manager.service

## TO-DO : Configure GNOME

## Clean up
RUN rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:phracek:PyCharm.repo && \
    rm -f /etc/yum.repos.d/fedora-cisco-openh264.repo && \
    rm -rf /tmp/* /var/* && \
    echo "Hidden=true" >> /usr/share/applications/htop.desktop && \
    echo "Hidden=true" >> /usr/share/applications/nvtop.desktop && \
    ostree container commit && \
    mkdir -p /var/tmp && \
    chmod -R 1777 /var/tmp
