#!/bin/sh
# This script installs Kuzco on Linux for Kaggle (modified to avoid bans).

KUZCO_BASE_URL=${KUZCO_BASE_URL:-"kuzco.xyz"} # Used for switching between prod and dev
BUCKET_URL=${BUCKET_URL:-"cfs.$KUZCO_BASE_URL"}
WEB_URL=${WEB_URL:-"https://$KUZCO_BASE_URL"}
API_URL=${API_URL:-"https://relay.$KUZCO_BASE_URL"}

set -eu

status() { echo ">>> $*" >&1; }
error() { echo "ERROR $*" >&2; exit 1; }

DEBUG_MODE=${DEBUG_MODE:-false}

TEMP_DIR=$(mktemp -d)
cleanup() { rm -rf $TEMP_DIR; }
trap cleanup EXIT

available() { command -v $1 >/dev/null; }
require() {
    local MISSING=''
    for TOOL in $*; do
        if ! available $TOOL; then
            MISSING="$MISSING $TOOL"
        fi
    done
    echo $MISSING
}

[ "$(uname -s)" = "Linux" ] || error 'This script is intended to run on Linux only.'

ARCH=$(uname -m)
case "$ARCH" in 
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) error "Unsupported architecture: $ARCH" ;;  
esac

NEEDS=$(require curl awk grep sed tee xargs)
if [ -n "$NEEDS" ]; then
    status "ERROR: The following tools are required but missing:"
    for NEED in $NEEDS; do
        echo "  - $NEED"
    done
    exit 1
fi

download_versions_json() {
    local TIMESTAMP=$(date +%s)
    local VERSIONS_URL="https://$BUCKET_URL/cli-versions.json?t=$TIMESTAMP"
    curl --fail --show-error --location --progress-bar -o $TEMP_DIR/versions.json "$VERSIONS_URL"
}

status "Getting versions.json..."
download_versions_json

CLI_VERSION=${CLI_VERSION:-$(awk -F'"' '/cli-latest/ {print $4}' $TEMP_DIR/versions.json)}
status "CLI_VERSION: $CLI_VERSION"

DID_DOWNLOAD_KUZCO=false

status "Downloading kuzco..."
KUZCO_BINARY_URL="${BUCKET_URL}/cli/release/${ARCH}/kuzco-linux-${ARCH}-${CLI_VERSION}"
curl --fail --show-error --location --progress-bar -o $TEMP_DIR/kuzco $KUZCO_BINARY_URL

DID_DOWNLOAD_KUZCO=true

if [ "$DID_DOWNLOAD_KUZCO" = "false" ]; then
    error "Failed to download kuzco -- unsupported architecture."
fi

# ✅ Safe install location for Kaggle
BINDIR="$HOME/.local/bin"
mkdir -p $BINDIR
install -m755 $TEMP_DIR/kuzco $BINDIR/kuzco

status "Kuzco installed successfully."

# ✅ Add Kuzco to PATH for current session
export PATH=$BINDIR:$PATH
