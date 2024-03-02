ARG SOURCE_IMAGE="silverblue"
ARG SOURCE_SUFFIX="main"
ARG FEDORA_VERSION="39"
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}-${SOURCE_SUFFIX}:${FEDORA_VERSION}

## install and remove a package
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

# Flatpak packages
RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo --user
RUN flatpak install -y --user flathub com.discordapp.Discord com.github.tchx84.Flatseal com.heroicgameslauncher.hgl com.usebottles.bottles org.mozilla.firefox io.github.celluloid_player.Celluloid

## TO-DO : Configure GNOME

## Clean up
RUN rm -rf /tmp/* /var/* && \
    ostree container commit && \
    mkdir -p /tmp /var/tmp && \
    chmod 1777 /tmp /var/tmp
