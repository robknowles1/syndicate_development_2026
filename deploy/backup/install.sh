#!/usr/bin/env bash
#
# Installs the SPEC-017 Phase 2 backup system on the box. Idempotent: re-running
# refreshes scripts and units and never overwrites a populated credential file.
#
#   scp -r deploy/backup ubuntu@<box>:/tmp/syndicate-backup-install
#   ssh ubuntu@<box> 'sudo bash /tmp/syndicate-backup-install/install.sh'
set -euo pipefail

RCLONE_VERSION="v1.75.1"
RCLONE_SHA256="982b5aa772841168f8e380f139e9e787b2a105403e32b94da8676a0e1c0a13ab"

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="/etc/syndicate-backup"
BIN_DIR="/usr/local/bin"
UNIT_DIR="/etc/systemd/system"

[[ "$EUID" -eq 0 ]] || { echo "install.sh must run as root" >&2; exit 1; }

install_rclone() {
  if [[ -x "${BIN_DIR}/rclone" ]] && "${BIN_DIR}/rclone" version | grep -q "$RCLONE_VERSION"; then
    echo "==> rclone ${RCLONE_VERSION} already installed"
    return
  fi

  echo "==> installing rclone ${RCLONE_VERSION}"
  local tmp zip
  tmp="$(mktemp -d)"
  zip="${tmp}/rclone.zip"
  curl -fsSL -o "$zip" \
    "https://downloads.rclone.org/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip"
  echo "${RCLONE_SHA256}  ${zip}" | sha256sum --check --status \
    || { echo "rclone download failed its checksum — not installing" >&2; rm -rf "$tmp"; exit 1; }
  unzip -q -j "$zip" "*/rclone" -d "$tmp"
  install -m 0755 -o root -g root "${tmp}/rclone" "${BIN_DIR}/rclone"
  rm -rf "$tmp"
}

command -v unzip >/dev/null || { echo "==> installing unzip"; apt-get update -qq && apt-get install -y -qq unzip; }
install_rclone

echo "==> installing scripts"
for script in syndicate-backup syndicate-backup-verify syndicate-backup-alert syndicate-backup-drill; do
  install -m 0700 -o root -g root "${SOURCE_DIR}/${script}" "${BIN_DIR}/${script}"
done

echo "==> installing units"
install -d -m 0755 "$UNIT_DIR"
for unit in "${SOURCE_DIR}"/systemd/*; do
  install -m 0644 -o root -g root "$unit" "${UNIT_DIR}/$(basename "$unit")"
done

echo "==> preparing ${CONF_DIR}"
install -d -m 0700 -o root -g root "$CONF_DIR"
install -m 0644 -o root -g root "${SOURCE_DIR}/README" "${CONF_DIR}/README"

if [[ -f "${CONF_DIR}/backup.env" ]]; then
  echo "    backup.env exists — left alone (edit it to repoint the destination)"
else
  install -m 0600 -o root -g root "${SOURCE_DIR}/backup.env.example" "${CONF_DIR}/backup.env"
  echo "    backup.env seeded from the example"
fi

if [[ -f "${CONF_DIR}/alert.env" ]]; then
  echo "    alert.env exists — left alone"
else
  install -m 0600 -o root -g root "${SOURCE_DIR}/alert.env.example" "${CONF_DIR}/alert.env"
  echo "    alert.env seeded with a PLACEHOLDER key — populate it before trusting alerts"
fi

if [[ ! -f "${CONF_DIR}/rclone.conf" ]]; then
  echo "    rclone.conf is ABSENT — install it by hand, see ${CONF_DIR}/README" >&2
fi

ARCHIVE_IMAGE="$(grep -E '^ARCHIVE_IMAGE=' "${CONF_DIR}/backup.env" | cut -d= -f2-)"
echo "==> pre-pulling ${ARCHIVE_IMAGE}"
docker pull --quiet "$ARCHIVE_IMAGE"

echo "==> enabling timers"
systemctl daemon-reload
systemctl enable --now syndicate-backup.timer syndicate-backup-verify.timer
systemctl list-timers --no-pager 'syndicate-backup*'
