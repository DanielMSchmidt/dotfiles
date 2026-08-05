#!/usr/bin/env bash
# Build /Applications/Rustcast.app from the pinned checkout in vendor/rustcast.
#
# rustcast is not installed from the Homebrew cask. The cask build arms its CGEventTap
# once and never again, so when macOS switches the tap off (it does that whenever the
# callback is slow to return) every hotkey dies silently until the app is restarted.
# patches/rustcast-reenable-event-tap.patch fixes that; the submodule itself is kept
# pristine so it can be fast-forwarded without fighting local edits.
#
# Keep `auto_update = false` in dot_config/rustcast/config.toml.tmpl, or rustcast will
# replace this build with an upstream release and reintroduce the bug.
#
# Normally run for you by run_onchange_after_build-rustcast.sh.tmpl during
# `chezmoi apply`. Run it by hand after changing the patch or the submodule pointer.
#
# Usage: ./.build-rustcast.sh [--no-install]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/vendor/rustcast"
PATCH_DIR="$REPO_DIR/patches"
APP_NAME="Rustcast.app"
APP_TEMPLATE="$SRC_DIR/assets/macos/RustCast.app"
BUILD_DIR="$SRC_DIR/target/release/macos"
INSTALL_PATH="/Applications/$APP_NAME"

install_app=true
[ "${1:-}" = "--no-install" ] && install_app=false

export PATH="/opt/homebrew/opt/rustup/bin:$PATH"
# Matches LSMinimumSystemVersion in the bundle template.
export MACOSX_DEPLOYMENT_TARGET="13.0"

if [ ! -f "$SRC_DIR/Cargo.toml" ]; then
  echo "error: $SRC_DIR is empty -- run: git -C '$REPO_DIR' submodule update --init" >&2
  exit 1
fi

if ! command -v rustup >/dev/null 2>&1; then
  echo "error: rustup not found; it is declared in .chezmoidata/packages.yaml" >&2
  exit 1
fi

# rustup installs the toolchain pinned by vendor/rustcast/rust-toolchain.toml on first
# use, but only if it is allowed to; make that explicit so a cold machine is not a
# surprise mid-build.
echo "==> Ensuring pinned Rust toolchain"
(cd "$SRC_DIR" && rustup show active-toolchain >/dev/null)

echo "==> Applying local patches"
shopt -s nullglob
for patch in "$PATCH_DIR"/rustcast-*.patch; do
  name="$(basename "$patch")"
  if git -C "$SRC_DIR" apply --reverse --check "$patch" 2>/dev/null; then
    echo "    already applied: $name"
  elif git -C "$SRC_DIR" apply "$patch" 2>/dev/null; then
    echo "    applied: $name"
  else
    echo "error: $name does not apply to $(git -C "$SRC_DIR" rev-parse --short HEAD)." >&2
    echo "       The submodule probably moved; refresh the patch and rebuild." >&2
    exit 1
  fi
done
shopt -u nullglob

echo "==> Building rustcast (release, native arch)"
cd "$SRC_DIR"
cargo build --release --locked

echo "==> Assembling $APP_NAME"
rm -rf "${BUILD_DIR:?}/$APP_NAME"
mkdir -p "$BUILD_DIR"
cp -fRp "$APP_TEMPLATE" "$BUILD_DIR/$APP_NAME"
mkdir -p "$BUILD_DIR/$APP_NAME/Contents/MacOS"
cp -fp "$SRC_DIR/target/release/rustcast" "$BUILD_DIR/$APP_NAME/Contents/MacOS/"

# Ad-hoc signature. This is not the upstream developer's identity, so macOS treats the
# app as a different binary than the cask build did: expect to grant Accessibility on
# each new machine, and again after any rebuild that changes the signature.
echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$BUILD_DIR/$APP_NAME"

if [ "$install_app" = true ]; then
  echo "==> Installing to $INSTALL_PATH"
  pkill -x rustcast || true
  # Wait for the old instance to exit so LaunchServices starts the new binary.
  for _ in $(seq 50); do pgrep -x rustcast >/dev/null || break; sleep 0.2; done
  rm -rf "$INSTALL_PATH"
  cp -R "$BUILD_DIR/$APP_NAME" "$INSTALL_PATH"
  open -a "$INSTALL_PATH"
  echo "==> Installed. If the hotkey does nothing, grant Accessibility:"
  echo "    System Settings > Privacy & Security > Accessibility > Rustcast"
else
  echo "==> Built at $BUILD_DIR/$APP_NAME (not installed)"
fi
