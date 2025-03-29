#!/bin/sh

set -oue pipefail

RELEASE="$(rpm -E %fedora)"
PACKAGE_LIST="up"
FEDORA_MAJOR_VERSION=$RELEASE
PACKAGES_JSON="/tmp/packages.json"

# 🧩 Récupère les packages à inclure
INCLUDED_PACKAGES=($(jq -r "
  (
    try .all.include.\"$PACKAGE_LIST\" // [],
    try .\"$FEDORA_MAJOR_VERSION\".include.\"$PACKAGE_LIST\" // []
  ) | sort | unique[]" "$PACKAGES_JSON"))

# 🧩 Récupère les packages à exclure
EXCLUDED_PACKAGES=($(jq -r "
  (
    try .all.exclude.\"$PACKAGE_LIST\" // [],
    try .\"$FEDORA_MAJOR_VERSION\".exclude.\"$PACKAGE_LIST\" // []
  ) | sort | unique[]" "$PACKAGES_JSON"))

echo "✅ Packages à inclure : ${INCLUDED_PACKAGES[*]}"
echo "❌ Packages à exclure : ${EXCLUDED_PACKAGES[*]}"

# 🧼 Filtrer les paquets exclus déjà présents sur l'image
if [[ "${#EXCLUDED_PACKAGES[@]}" -gt 0 ]]; then
    INSTALLED_EXCLUDED=($(rpm -qa --queryformat='%{NAME} ' "${EXCLUDED_PACKAGES[@]}" | tr ' ' '\n' | sort -u))
else
    INSTALLED_EXCLUDED=()
fi

# ✅ Installation des paquets inclus (s'ils ne sont pas déjà installés)
if [[ "${#INCLUDED_PACKAGES[@]}" -gt 0 ]]; then
    echo "📦 Installation des paquets inclus..."
    dnf5 -y install "${INCLUDED_PACKAGES[@]}"
else
    echo "ℹ️ Aucun paquet à inclure."
fi

# ❌ Suppression des paquets exclus (présents)
if [[ "${#INSTALLED_EXCLUDED[@]}" -gt 0 ]]; then
    echo "🧹 Suppression des paquets exclus présents..."
    dnf5 -y remove "${INSTALLED_EXCLUDED[@]}"
else
    echo "✅ Aucun paquet exclu présent à supprimer."
fi

# 🔁 Vérification finale : des exclus pourraient être revenus via des dépendances
FINAL_INSTALLED_EXCLUDED=($(rpm -qa --queryformat='%{NAME} ' "${EXCLUDED_PACKAGES[@]}" | tr ' ' '\n' | sort -u))

if [[ "${#FINAL_INSTALLED_EXCLUDED[@]}" -gt 0 ]]; then
    echo "🚨 Nettoyage final : certains paquets exclus sont encore là : ${FINAL_INSTALLED_EXCLUDED[*]}"
    dnf5 -y remove "${FINAL_INSTALLED_EXCLUDED[@]}"
else
    echo "🎉 Aucun paquet exclu restant après vérification."
fi
