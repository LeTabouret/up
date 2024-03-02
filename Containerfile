### 1. BUILD ARGS
## These enable the produced image to be different by passing different build args.
## They are provided on the commandline when building in a terminal, but the github
## workflow provides them when building in Github Actions. Changes to the workflow
## build.xml will override changes here.

## SOURCE_IMAGE arg can be anything from ublue upstream: silverblue, kinoite, sericea, vauxite, mate, lxqt, base
ARG SOURCE_IMAGE="silverblue"
## SOURCE_SUFFIX arg should be "main", nvidia users should use "nvidia"
ARG SOURCE_SUFFIX="main"
## FEDORA_VERSION arg must be a version built by ublue
ARG FEDORA_VERSION="39"
## NVIDIA_VERSION should only be changed if the user needs a specific nvidia driver version
##   if needing driver 535, this should be set to "-535". It is important to include the hyphen
ARG NVIDIA_VERSION=""


### 2. SOURCE IMAGE
## this is a standard Containerfile FROM using the build ARGs above to select the right upstream image
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}-${SOURCE_SUFFIX}:${FEDORA_VERSION}${NVIDIA_VERSION}


### 3. PRE-MODIFICATIONS
## this directory is needed to prevent failure with some RPM installs
RUN mkdir -p /var/lib/alternatives


### 4. MODIFICATIONS
## make modifications desired in your image and install packages here, a few examples follow

# install and remove a package from standard fedora repo
RUN rpm-ostree install virt-manager qemu-kvm libvirt steam gnome-shell-extension-pop-shell
RUN rpm-ostree override remove firefox firefox-langpacks gnome-classic-session gnome-shell-extension-launch-new-instance gnome-shell-extension-places-menu gnome-shell-extension-window-list gnome-shell-extension-background-logo gnome-shell-extension-apps-menu toolbox


## Configure GNOME
RUN local user_home \
    && user_home=$(getent passwd "$USER" | cut -d: -f6) \
    && mkdir -p "$user_home/.background" \
    && sudo cp ./background/gooff5.jpg "$user_home/.background" \
    && sudo chown -R "$USER:$USER" "$user_home/.background" \
    && mkdir -p "$user_home/.local/share/fonts" \
    && cp -r ./.themes "$user_home" && sudo chown -R "$USER:$USER" "$user_home/.themes" \
    && cp -r ./.icons "$user_home" && sudo chown -R "$USER:$USER" "$user_home/.icons" \
    && cp -r ./Fonts/Inter/* "$user_home/.local/share/fonts/" \
    && cp -r ./Fonts/JetBrains/* "$user_home/.local/share/fonts/" \
    && sudo chown -R "$USER:$USER" "$user_home/.local/share/fonts/" \
    && rm -rf "$user_home/.mozilla" \
    && gsettings set org.gnome.desktop.background picture-uri "file://$user_home/.background/gooff5.jpg" \
    && gsettings set org.gnome.desktop.screensaver picture-uri "file://$user_home/.background/gooff5.jpg" \
    && gsettings set org.gnome.desktop.background picture-uri-dark "file://$user_home/.background/gooff5.jpg" \
    && gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat' \
    && gsettings set org.gnome.desktop.session idle-delay 0 \
    && gsettings set org.gnome.desktop.interface icon-theme 'Tela-dark' \
    && gsettings set org.gnome.desktop.interface font-name 'Inter 10' \
    && gsettings set org.gnome.desktop.interface document-font-name 'Sans 10' \
    && gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 10' \
    && gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Inter Bold 10' \
    && gsettings set org.gnome.shell disable-extension-version-validation true \
    && gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark \
    && gsettings set org.gnome.desktop.interface color-scheme prefer-dark \
    && gsettings set org.gnome.shell favorite-apps "['org.mozilla.firefox.desktop', 'org.gnome.Nautilus.desktop', 'steam.desktop', 'com.discordapp.Discord.desktop', 'org.gnome.Terminal.desktop', 'com.heroicgameslauncher.hgl.desktop', 'com.usebottles.bottles.desktop', 'virt-manager.desktop', 'com.github.tchx84.Flatseal.desktop']"
    && fc-cache -rv

# static binaries can sometimes by added using a COPY directive like these below. 
COPY --from=cgr.dev/chainguard/kubectl:latest /usr/bin/kubectl /usr/bin/kubectl
#COPY --from=docker.io/docker/compose-bin:latest /docker-compose /usr/bin/docker-compose

# modify default timeouts on system to prevent slow reboots from services that won't stop
RUN sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/user.conf && \
    sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/system.conf


### 5. POST-MODIFICATIONS
## these commands leave the image in a clean state after local modifications
RUN rm -rf /tmp/* /var/* && \
    ostree container commit && \
    mkdir -p /tmp /var/tmp && \
    chmod 1777 /tmp /var/tmp
