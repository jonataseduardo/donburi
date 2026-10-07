#!/bin/bash
# Build herdr from source with donburi's local patches and install it to ~/.local/bin.
#
# Currently patches/focus-follows-mouse.patch: adds `ui.focus_follows_mouse`
# (focus the pane under the mouse, like tmux's focus-follows-mouse). Upstream
# herdr only accepts PRs from approved contributors, so this stays local until
# herdr ships the feature (see github.com/herdrdev/herdr/discussions/1195).
#
# Note: `herdr update` replaces the binary with the unpatched release; re-run
# this script afterwards.
#
# Usage: herdr/build-patched.sh [version]   (default: the installed herdr version)

set -euo pipefail

DONBURI_HERDR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${HERDR_SRC_DIR:-$HOME/.local/src/herdr}"
BIN_DIR="$HOME/.local/bin"
ZIG_VERSION="0.16.0"
ZIG_DIR="$HOME/.local/share/zig/zig-aarch64-macos-$ZIG_VERSION"
ZIG_SHA256="b23d70deaa879b5c2d486ed3316f7eaa53e84acf6fc9cc747de152450d401489"
export PATH="$HOME/.cargo/bin:$BIN_DIR:$PATH"

log() { echo "[herdr-patched] $*"; }

version="${1:-}"
if [[ -z "$version" ]]; then
	command -v herdr >/dev/null || {
		log "herdr not installed; pass a version, e.g. build-patched.sh 0.9.3"
		exit 1
	}
	version="$(herdr --version | awk '{print $2}')"
fi
log "building herdr v$version with donburi patches"

command -v cargo >/dev/null || {
	log "cargo not found — run: donburi setup (installs Rust via rustup)"
	exit 1
}
[[ "$(uname -sm)" == "Darwin arm64" ]] || {
	log "only macOS arm64 is supported by this script"
	exit 1
}

# Zig is needed to build the vendored libghostty-vt
if [[ ! -x "$ZIG_DIR/zig" ]]; then
	log "installing Zig $ZIG_VERSION"
	mkdir -p "$(dirname "$ZIG_DIR")"
	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' EXIT
	curl -fsSL -o "$tmp/zig.tar.xz" "https://ziglang.org/download/$ZIG_VERSION/zig-aarch64-macos-$ZIG_VERSION.tar.xz"
	echo "$ZIG_SHA256  $tmp/zig.tar.xz" | shasum -a 256 -c - >/dev/null
	tar -xf "$tmp/zig.tar.xz" -C "$(dirname "$ZIG_DIR")"
fi
export ZIG="$ZIG_DIR/zig"

# Fresh checkout of the release tag, then apply every patch
if [[ -d "$SRC_DIR/.git" ]]; then
	git -C "$SRC_DIR" fetch -q --depth 1 origin tag "v$version"
else
	git clone -q --depth 1 --branch "v$version" https://github.com/herdrdev/herdr.git "$SRC_DIR"
fi
git -C "$SRC_DIR" checkout -q --force "v$version"
git -C "$SRC_DIR" clean -q -fd -e target
for patch in "$DONBURI_HERDR"/patches/*.patch; do
	log "applying $(basename "$patch")"
	git -C "$SRC_DIR" apply "$patch"
done

(cd "$SRC_DIR" && cargo build --release --bin herdr)

# Keep the unpatched release around, then swap atomically (running herdr keeps its old inode)
if [[ -x "$BIN_DIR/herdr" && ! -e "$BIN_DIR/herdr.upstream-$version" ]]; then
	cp -p "$BIN_DIR/herdr" "$BIN_DIR/herdr.upstream-$version"
fi
mkdir -p "$BIN_DIR"
cp "$SRC_DIR/target/release/herdr" "$BIN_DIR/herdr.new"
mv "$BIN_DIR/herdr.new" "$BIN_DIR/herdr"
log "installed $("$BIN_DIR/herdr" --version) (patched) to $BIN_DIR/herdr"
log "detach (prefix+q) and run 'herdr' again to use it"
