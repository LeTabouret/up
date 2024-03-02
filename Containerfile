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


### 4. MODIFICATIONS
## make modifications desired in your image and install packages here, a few examples follow

# install and remove a package from standard fedora repo
RUN rpm-ostree install virt-manager qemu-kvm libvirt steam gnome-shell-extension-pop-shell
RUN rpm-ostree override remove firefox firefox-langpacks gnome-classic-session gnome-shell-extension-launch-new-instance gnome-shell-extension-places-menu gnome-shell-extension-window-list gnome-shell-extension-background-logo gnome-shell-extension-apps-menu toolbox


## Configure GNOME


### 5. POST-MODIFICATIONS
## these commands leave the image in a clean state after local modifications
RUN rm -rf /tmp/* /var/* && \
    ostree container commit && \
    mkdir -p /tmp /var/tmp && \
    chmod 1777 /tmp /var/tmp
