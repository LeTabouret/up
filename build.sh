#!/bin/sh

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"
PACKAGE_LIST="up"
FEDORA_MAJOR_VERSION=$RELEASE

# Build list of all packages requested for inclusion
INCLUDED_PACKAGES=($(jq -r "[(.all.include | (select(.\"$PACKAGE_LIST\" != null).\"$PACKAGE_LIST\")[]), \
                             (select(.\"$FEDORA_MAJOR_VERSION\" != null).\"$FEDORA_MAJOR_VERSION\".include | (select(.\"$PACKAGE_LIST\" != null).\"$PACKAGE_LIST\")[])] \
                             | sort | unique[]" /tmp/packages.json))

# Build list of all packages requested for override
CONFLICTED_PACKAGES=($(jq -r "[(.all.conflictedpackagesupdates | (select(.\"$PACKAGE_LIST\" != null).\"$PACKAGE_LIST\")[]), \
                             (select(.\"$FEDORA_MAJOR_VERSION\" != null).\"$FEDORA_MAJOR_VERSION\".conflictedpackagesupdates | (select(.\"$PACKAGE_LIST\" != null).\"$PACKAGE_LIST\")[])] \
                             | sort | unique[]" /tmp/packages.json))

 # Build list of all packages requested for override in base
CONFLICTED_PACKAGES_BASE=($(jq -r "[(.all.conflictedpackagesbase | (select(.\"$PACKAGE_LIST\" != null).\"$PACKAGE_LIST\")[]), \
                             (select(.\"$FEDORA_MAJOR_VERSION\" != null).\"$FEDORA_MAJOR_VERSION\".conflictedpackagesbase | (select(.\"$PACKAGE_LIST\" != null).\"$PACKAGE_LIST\")[])] \
                             | sort | unique[]" /tmp/packages.json))

# Build list of all packages requested for exclusion
EXCLUDED_PACKAGES=($(jq -r "[(.all.exclude | (select(.\"$PACKAGE_LIST\" != null).\"$PACKAGE_LIST\")[]), \
                             (select(.\"$FEDORA_MAJOR_VERSION\" != null).\"$FEDORA_MAJOR_VERSION\".exclude | (select(.\"$PACKAGE_LIST\" != null).\"$PACKAGE_LIST\")[])] \
                             | sort | unique[]" /tmp/packages.json))


# Install packages that are in base install and may generate conflicts
if [[ "${#CONFLICTED_PACKAGES_BASE[@]}" -gt 0 ]]; then
    rpm-ostree install \
        ${CONFLICTED_PACKAGES_BASE[@]}
fi

# Install conflicted packages to resolve dependencies
if [[ "${#CONFLICTED_PACKAGES[@]}" -gt 0 ]]; then
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        ${CONFLICTED_PACKAGES[@]} \
        || true
fi

# Ensure exclusion list only contains packages already present on image
if [[ "${#EXCLUDED_PACKAGES[@]}" -gt 0 ]]; then
    EXCLUDED_PACKAGES=($(rpm -qa --queryformat='%{NAME} ' ${EXCLUDED_PACKAGES[@]}))
fi

# Simple case to install where no packages need excluding
if [[ "${#INCLUDED_PACKAGES[@]}" -gt 0 && "${#EXCLUDED_PACKAGES[@]}" -eq 0 ]]; then
    rpm-ostree install \
        ${INCLUDED_PACKAGES[@]}

# Install/excluded packages both at same time
elif [[ "${#INCLUDED_PACKAGES[@]}" -gt 0 && "${#EXCLUDED_PACKAGES[@]}" -gt 0 ]]; then
    rpm-ostree override remove \
        ${EXCLUDED_PACKAGES[@]} \
        $(printf -- "--install=%s " ${INCLUDED_PACKAGES[@]})

else
    echo "No packages to install."
fi

# Check if any excluded packages are still present
# (this can happen if an included package pulls in a dependency)
EXCLUDED_PACKAGES=($(jq -r "[(.all.exclude | (select(.\"$PACKAGE_LIST\" != null).\"$PACKAGE_LIST\")[]), \
                             (select(.\"$FEDORA_MAJOR_VERSION\" != null).\"$FEDORA_MAJOR_VERSION\".exclude | (select(.\"$PACKAGE_LIST\" != null).\"$PACKAGE_LIST\")[])] \
                             | sort | unique[]" /tmp/packages.json))

if [[ "${#EXCLUDED_PACKAGES[@]}" -gt 0 ]]; then
    EXCLUDED_PACKAGES=($(rpm -qa --queryformat='%{NAME} ' ${EXCLUDED_PACKAGES[@]}))
fi

# Remove any excluded packages which are still present on image
if [[ "${#EXCLUDED_PACKAGES[@]}" -gt 0 ]]; then
    rpm-ostree override remove \
        ${EXCLUDED_PACKAGES[@]}
fi