# renovate: datasource=docker depName=ghcr.io/ublue-os/silverblue-main versioning=docker
FROM ghcr.io/ublue-os/silverblue-main:44@sha256:1f05de28fc4ce8b004e524b1b5e1e0ce5f828b696c07a352bdb6d776b9242903 AS base

FROM scratch AS context
COPY build.sh packages.json /
COPY etc /etc
COPY usr /usr

FROM base

ARG TELA_VERSION="2026-07-07"
ARG TELA_SHA256="6b8c28f637067a15551459ab90e6720c5aba1215b777b6f1f506fea188a1ddf9"
ARG FLATHUB_REPO_SHA256="3371dd250e61d9e1633630073fefda153cd4426f72f4afa0c3373ae2e8fea03a"

RUN --mount=type=bind,from=context,source=/,target=/ctx \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    cp -a /ctx/etc/. /etc/ && \
    cp -a /ctx/usr/. /usr/ && \
    if [ -d /usr/etc ]; then \
      find /usr/etc -depth -type d -empty -delete; \
    fi && \
    cp /ctx/packages.json /tmp/packages.json && \
    /ctx/build.sh && \
    curl --fail --location --silent --show-error \
      "https://github.com/vinceliuice/Tela-icon-theme/archive/refs/tags/${TELA_VERSION}.tar.gz" \
      --output /tmp/tela.tar.gz && \
    echo "${TELA_SHA256}  /tmp/tela.tar.gz" | sha256sum --check --strict && \
    tar --extract --gzip --file=/tmp/tela.tar.gz --directory=/tmp && \
    "/tmp/Tela-icon-theme-${TELA_VERSION}/install.sh" -d /usr/share/icons && \
    install -Dm0644 "/tmp/Tela-icon-theme-${TELA_VERSION}/COPYING" \
      /usr/share/licenses/up/Tela-icon-theme-COPYING && \
    install -d /etc/flatpak/remotes.d && \
    curl --fail --location --silent --show-error \
      https://dl.flathub.org/repo/flathub.flatpakrepo \
      --output /etc/flatpak/remotes.d/flathub.flatpakrepo && \
    echo "${FLATHUB_REPO_SHA256}  /etc/flatpak/remotes.d/flathub.flatpakrepo" | \
      sha256sum --check --strict && \
    systemctl enable dconf-update.service && \
    systemctl --global enable ublue-user-flatpak-manager.service && \
    fc-cache --force && \
    for desktop in htop.desktop nvtop.desktop; do \
      desktop_file="/usr/share/applications/${desktop}"; \
      if [ -f "${desktop_file}" ]; then \
        sed -i '/^Hidden=/d' "${desktop_file}"; \
        printf '\nHidden=true\n' >>"${desktop_file}"; \
      fi; \
    done && \
    rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:phracek:PyCharm.repo \
      /etc/yum.repos.d/fedora-cisco-openh264.repo

RUN --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    dconf update && \
    systemd-analyze verify \
      /usr/lib/systemd/system/dconf-update.service \
      /usr/lib/systemd/user/ublue-user-flatpak-manager.service && \
    bootc container lint
