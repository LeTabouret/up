# renovate: datasource=docker depName=ghcr.io/ublue-os/bazzite-gnome versioning=docker
FROM ghcr.io/ublue-os/bazzite-gnome:stable@sha256:629fed5385623270d6356a33a483b5a69010be0f5b84a11b91f27b58558a32b6 AS base

FROM scratch AS context
COPY build.sh customize.sh packages.json /
COPY cosign.pub /up.pub
COPY etc /etc
COPY usr /usr

FROM base

ARG IMAGE_REPOSITORY="ghcr.io/letabouret/up"
ARG IMAGE_VERSION="44-dev"
ARG IMAGE_REVISION="local"
ARG IMAGE_CREATED="1970-01-01T00:00:00Z"
LABEL org.opencontainers.image.title="Up" \
      org.opencontainers.image.description="Personal GNOME desktop on the Bazzite gaming foundation" \
      org.opencontainers.image.source="https://github.com/LeTabouret/up" \
      org.opencontainers.image.url="https://github.com/LeTabouret/up" \
      org.opencontainers.image.vendor="Up" \
      org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.base.name="ghcr.io/ublue-os/bazzite-gnome:stable"

ARG TELA_VERSION="2026-07-07"
ARG TELA_SHA256="6b8c28f637067a15551459ab90e6720c5aba1215b777b6f1f506fea188a1ddf9"
ARG FLATHUB_REPO_SHA256="3371dd250e61d9e1633630073fefda153cd4426f72f4afa0c3373ae2e8fea03a"

RUN --mount=type=bind,from=context,source=/,target=/ctx,ro \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    cp -a /ctx/etc/. /etc/ && \
    cp -a /ctx/usr/. /usr/ && \
    cp /ctx/packages.json /tmp/packages.json && \
    /ctx/build.sh && \
    /ctx/customize.sh && \
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
    dnf5 clean all

RUN --mount=type=tmpfs,target=/run \
    --mount=type=tmpfs,target=/tmp \
    systemctl mask dmemcg-booster-system.service && \
    systemctl --global mask dmemcg-booster-user.service && \
    dconf update && \
    systemd-analyze verify /usr/lib/systemd/system/dconf-update.service && \
    mkdir -p /tmp/up-user-runtime && \
    XDG_RUNTIME_DIR=/tmp/up-user-runtime systemd-analyze --user verify \
      /usr/lib/systemd/user/ublue-user-flatpak-manager.service && \
    /usr/libexec/up-verify-image && \
    systemd-tmpfiles --create /usr/lib/tmpfiles.d/up-virtualization.conf && \
    rm -rf /var/lib/dnf /var/lib/flatpak /var/roothome && \
    rm -f /var/log/dnf5.log && \
    bootc container lint --fatal-warnings
