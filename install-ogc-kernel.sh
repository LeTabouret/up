#!/usr/bin/bash

set -euo pipefail

readonly KERNEL_RPM_DIR="${KERNEL_RPM_DIR:-/tmp/kernel-rpms}"
readonly KERNEL_INSTALL_DIR="${KERNEL_INSTALL_DIR:-/usr/lib/kernel/install.d}"
readonly MODULES_DIR="${MODULES_DIR:-/usr/lib/modules}"
readonly OGC_PACKAGE_MANIFEST="${OGC_PACKAGE_MANIFEST:-/usr/share/up/ogc-kernel-packages}"
readonly FEDORA_RELEASE="${FEDORA_RELEASE:-$(rpm -E '%fedora')}"

readonly -a KERNEL_HOOKS=(05-rpmostree.install 50-dracut.install)
readonly -a STOCK_KERNEL_PACKAGES=(
    kernel
    kernel-core
    kernel-modules
    kernel-modules-core
    kernel-modules-extra
    kernel-tools-libs
    kernel-tools
)
readonly -a REQUIRED_OGC_PACKAGES=(
    kernel
    kernel-core
    kernel-modules
    kernel-devel
    kernel-devel-matched
)

restore_kernel_hooks() {
    local hook backup
    for hook in "${KERNEL_HOOKS[@]}"; do
        backup="${KERNEL_INSTALL_DIR}/${hook}.ogc-backup"
        if [[ -e "$backup" ]]; then
            rm -f -- "${KERNEL_INSTALL_DIR}/${hook}"
            mv -- "$backup" "${KERNEL_INSTALL_DIR}/${hook}"
        fi
    done
}

disable_kernel_hooks() {
    local hook path backup
    for hook in "${KERNEL_HOOKS[@]}"; do
        path="${KERNEL_INSTALL_DIR}/${hook}"
        backup="${path}.ogc-backup"
        [[ -f "$path" ]] || {
            printf 'Required kernel-install hook is missing: %s\n' "$path" >&2
            return 1
        }
        [[ ! -e "$backup" ]] || {
            printf 'Refusing to overwrite existing hook backup: %s\n' "$backup" >&2
            return 1
        }
        mv -- "$path" "$backup"
        printf '%s\n' '#!/bin/sh' 'exit 0' > "$path"
        chmod 0755 "$path"
    done
}

collect_ogc_rpms() {
    local rpm_result_name="$1"
    local package_result_name="$2"
    local release_result_name="$3"
    local rpm_file package package_release release_key
    local -n rpm_result="$rpm_result_name"
    local -n package_result="$package_result_name"
    local -n release_result="$release_result_name"
    local -A selected=()
    local -A releases=()

    [[ -d "$KERNEL_RPM_DIR" ]] || {
        printf 'OGC kernel RPM directory is missing: %s\n' "$KERNEL_RPM_DIR" >&2
        return 1
    }
    rpm_result=()
    package_result=()
    release_result=''
    while IFS= read -r -d '' rpm_file; do
        package="$(rpm -qp --queryformat '%{NAME}' "$rpm_file")"
        case "$package" in
            kernel | kernel-core | kernel-modules | kernel-modules-* | kernel-devel | kernel-devel-*) ;;
            *) continue ;;
        esac
        [[ -z "${selected[$package]:-}" ]] || {
            printf 'Multiple OGC RPMs found for package %s.\n' "$package" >&2
            return 1
        }
        package_release="$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' "$rpm_file")"
        [[ "$package_release" == *-ogc*".fc${FEDORA_RELEASE}"* ]] || {
            printf 'RPM does not identify as an OGC Fedora %s kernel: %s (%s)\n' \
                "$FEDORA_RELEASE" "$rpm_file" "$package_release" >&2
            return 1
        }
        selected["$package"]="$rpm_file"
        releases["$package_release"]=1
        rpm_result+=("$rpm_file")
        package_result+=("$package")
    done < <(find "$KERNEL_RPM_DIR" -maxdepth 1 -type f -name '*.rpm' -print0 | sort -z)

    for package in "${REQUIRED_OGC_PACKAGES[@]}"; do
        [[ -n "${selected[$package]:-}" ]] || {
            printf 'Required OGC kernel package is missing: %s\n' "$package" >&2
            return 1
        }
    done

    ((${#releases[@]} == 1)) || {
        printf 'Expected exactly one OGC kernel release, found %d.\n' "${#releases[@]}" >&2
        return 1
    }
    for release_key in "${!releases[@]}"; do
        release_result="$release_key"
    done

    printf 'Selected OGC kernel RPMs (%s):\n' "$release_result"
    printf '  %s\n' "${rpm_result[@]}"
}

remove_stock_kernel() {
    local package
    local -a installed=()

    rpm -q --quiet kernel-core || {
        echo 'Refusing kernel replacement: kernel-core is not installed.' >&2
        return 1
    }
    for package in "${STOCK_KERNEL_PACKAGES[@]}"; do
        if rpm -q --quiet "$package"; then
            installed+=("$package")
        fi
    done
    ((${#installed[@]} > 0)) || {
        echo 'Refusing kernel replacement: no stock kernel packages were found.' >&2
        return 1
    }

    printf 'Removing stock Fedora kernel packages: %s\n' "${installed[*]}"
    rpm --erase --nodeps -- "${installed[@]}"

    [[ "$MODULES_DIR" == /usr/lib/modules && -d "$MODULES_DIR" && ! -L "$MODULES_DIR" ]] || {
        printf 'Refusing to clean unexpected kernel modules path: %s\n' "$MODULES_DIR" >&2
        return 1
    }
    rm -rf -- "$MODULES_DIR"
}

verify_ogc_kernel() {
    local expected_release="$1"
    shift
    local package installed_name installed_release
    local -a installed_releases=()
    local -A expected=()

    for package in "$@"; do
        expected["$package"]=1
        mapfile -t installed_releases < <(
            rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' "$package"
        )
        ((${#installed_releases[@]} == 1)) || {
            printf 'Expected exactly one installed %s package, found %d.\n' \
                "$package" "${#installed_releases[@]}" >&2
            return 1
        }
        [[ "${installed_releases[0]}" == "$expected_release" ]] || {
            printf 'Kernel release mismatch for %s: expected %s, found %s.\n' \
                "$package" "$expected_release" "${installed_releases[0]}" >&2
            return 1
        }
    done

    while read -r installed_name installed_release; do
        case "$installed_name" in
            kernel | kernel-core | kernel-modules | kernel-modules-* | kernel-devel | kernel-devel-*) ;;
            *) continue ;;
        esac
        [[ -n "${expected[$installed_name]:-}" ]] || {
            printf 'Kernel package was not supplied by the pinned OGC artifact: %s\n' \
                "$installed_name" >&2
            return 1
        }
        [[ "$installed_release" == "$expected_release" ]] || {
            printf 'Installed kernel packages do not share one release: %s %s.\n' \
                "$installed_name" "$installed_release" >&2
            return 1
        }
    done < <(rpm -qa --queryformat '%{NAME} %{VERSION}-%{RELEASE}.%{ARCH}\n')

    echo 'Installed OGC kernel:'
    rpm -q "$@"
}

write_package_manifest() {
    install -d "$(dirname "$OGC_PACKAGE_MANIFEST")"
    printf '%s\n' "$@" | sort -u > "$OGC_PACKAGE_MANIFEST"
}

build_initramfs() {
    local kernel_release="$1"
    local initramfs="${MODULES_DIR}/${kernel_release}/initramfs.img"

    # Match Bazzite's final image lifecycle: kernel RPM scriptlets run with the
    # transactional hooks disabled, then a generic image-owned initramfs is
    # generated explicitly after the real hooks have been restored.
    DRACUT_NO_XATTR=1 /usr/bin/dracut \
        --no-hostonly \
        --kver "$kernel_release" \
        --reproducible \
        --zstd \
        --add ostree \
        --add fido2 \
        --force "$initramfs"
    chmod 0600 "$initramfs"
}

main() {
    local -a ogc_rpms=()
    local -a ogc_packages=()
    local ogc_release=''

    collect_ogc_rpms ogc_rpms ogc_packages ogc_release
    trap restore_kernel_hooks EXIT
    disable_kernel_hooks
    remove_stock_kernel
    dnf5 -y install "${ogc_rpms[@]}"
    # Preserve the kernel-tools functionality inherited from Silverblue.
    dnf5 -y install kernel-tools
    dnf5 versionlock add "${ogc_packages[@]}"
    restore_kernel_hooks
    trap - EXIT
    verify_ogc_kernel "$ogc_release" "${ogc_packages[@]}"
    build_initramfs "$ogc_release"
    /ctx/usr/libexec/ublue-verify-ogc-boot "$ogc_release"
    write_package_manifest "${ogc_packages[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
