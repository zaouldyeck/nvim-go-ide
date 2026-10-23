#!/usr/bin/env bash
# Install the pinned executable dependencies inside this Neovim profile.
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=versions.env
source "$SCRIPT_DIR/versions.env"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim-go"
FORCE_LOCAL_GO=0
while (($#)); do
  case "$1" in
    --data-dir) DATA_DIR=${2:?--data-dir needs a directory}; shift 2 ;;
    --install-go) FORCE_LOCAL_GO=1; shift ;;
    *) printf 'Unknown tools option: %s\n' "$1" >&2; exit 2 ;;
  esac
done
case "$DATA_DIR" in /*) ;; *) printf 'Data directory must be absolute.\n' >&2; exit 2 ;; esac

platform=$(uname -s)
machine=$(uname -m)
case "$platform" in Linux) nvim_os=linux; go_os=linux ;; Darwin) nvim_os=macos; go_os=darwin ;; *) printf 'Unsupported operating system: %s\n' "$platform" >&2; exit 1 ;; esac
case "$machine" in aarch64|arm64) nvim_arch=arm64; go_arch=arm64 ;; x86_64|amd64) nvim_arch=x86_64; go_arch=amd64 ;; *) printf 'Unsupported CPU: %s\n' "$machine" >&2; exit 1 ;; esac

mkdir -p "$DATA_DIR/bin" "$DATA_DIR/toolchain" "$DATA_DIR/downloads"
stage=$(mktemp -d "$DATA_DIR/toolchain/.stage.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

download_checked() {
  local url=$1 destination=$2 expected=$3 actual
  if [[ -f "$destination" ]]; then
    actual=$(sha256_file "$destination")
    if [[ "$actual" == "$expected" ]]; then return; fi
    printf 'Replacing an incomplete or mismatched cached download: %s\n' "$destination"
  fi
  curl --fail --location --retry 3 --connect-timeout 30 --proto '=https' --tlsv1.2 \
    --output "$destination.part" "$url"
  actual=$(sha256_file "$destination.part")
  if [[ "$actual" != "$expected" ]]; then
    printf 'SHA-256 mismatch for %s\nExpected: %s\nReceived: %s\n' "$url" "$expected" "$actual" >&2
    rm -f -- "$destination.part"
    exit 1
  fi
  mv -- "$destination.part" "$destination"
}

nvim_release="$DATA_DIR/toolchain/neovim-$NVIM_VERSION"
if [[ ! -x "$nvim_release/bin/nvim" ]]; then
  archive="nvim-$nvim_os-$nvim_arch.tar.gz"
  checksum_name="NVIM_SHA_${nvim_os}_${nvim_arch}"
  printf '\nInstalling Neovim %s (%s/%s)…\n' "$NVIM_VERSION" "$nvim_os" "$nvim_arch"
  download_checked "https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/$archive" \
    "$DATA_DIR/downloads/nvim-$NVIM_VERSION-$nvim_os-$nvim_arch.tar.gz" "${!checksum_name}"
  mkdir -p "$stage/nvim"
  tar -xzf "$DATA_DIR/downloads/nvim-$NVIM_VERSION-$nvim_os-$nvim_arch.tar.gz" --strip-components=1 -C "$stage/nvim"
  "$stage/nvim/bin/nvim" --version | head -n 1
  mv -- "$stage/nvim" "$nvim_release"
fi
if [[ -e "$DATA_DIR/toolchain/nvim" && ! -L "$DATA_DIR/toolchain/nvim" ]]; then
  printf 'Refusing to replace non-symlink %s\n' "$DATA_DIR/toolchain/nvim" >&2; exit 1
fi
ln -sfn "neovim-$NVIM_VERSION" "$DATA_DIR/toolchain/nvim"

# Go stays private to the nvim-go launcher; the user's shell Go is unchanged.
use_local_go=$FORCE_LOCAL_GO
if [[ -x "$DATA_DIR/toolchain/go/bin/go" ]]; then use_local_go=1; fi
if command -v go >/dev/null 2>&1; then
  existing_go=$(GOTOOLCHAIN=local go env GOVERSION 2>/dev/null || true)
  case "$existing_go" in
    go1.27.*) ;;
    *) use_local_go=1 ;;
  esac
else
  use_local_go=1
fi
if ((use_local_go)); then
  go_release="$DATA_DIR/toolchain/go$GO_VERSION"
  if [[ ! -x "$go_release/bin/go" ]]; then
    archive="go$GO_VERSION.$go_os-$go_arch.tar.gz"
    checksum_name="GO_SHA_${go_os}_${go_arch}"
    printf '\nInstalling local Go %s (%s/%s)…\n' "$GO_VERSION" "$go_os" "$go_arch"
    download_checked "https://go.dev/dl/$archive" "$DATA_DIR/downloads/$archive" "${!checksum_name}"
    tar -xzf "$DATA_DIR/downloads/$archive" -C "$stage"
    mv -- "$stage/go" "$go_release"
  fi
  if [[ -e "$DATA_DIR/toolchain/go" && ! -L "$DATA_DIR/toolchain/go" ]]; then
    printf 'Refusing to replace non-symlink %s\n' "$DATA_DIR/toolchain/go" >&2; exit 1
  fi
  ln -sfn "go$GO_VERSION" "$DATA_DIR/toolchain/go"
  export PATH="$DATA_DIR/toolchain/go/bin:$PATH"
  # Ignore an unrelated exported GOROOT when selecting the private toolchain.
  unset GOROOT
fi
export PATH="$DATA_DIR/bin:$PATH"

# A stamp avoids recompilation; binary build metadata is checked before reuse.
binary_has_version() {
  go version -m "$1" 2>/dev/null | awk -v module="$2" -v version="$3" \
    '$1 == "mod" && $2 == module && $3 == version {found=1} END {exit !found}'
}
tool_stamp="gopls=$GOPLS_VERSION goimports=$GOIMPORTS_VERSION delve=$DELVE_VERSION benchstat=$BENCHSTAT_VERSION"
reuse_tools=0
if [[ -f "$DATA_DIR/bin/.versions" && "$(cat "$DATA_DIR/bin/.versions")" == "$tool_stamp" ]]; then
  if [[ -x "$DATA_DIR/bin/gopls" && -x "$DATA_DIR/bin/goimports" && -x "$DATA_DIR/bin/dlv" && -x "$DATA_DIR/bin/benchstat" ]] \
    && binary_has_version "$DATA_DIR/bin/gopls" golang.org/x/tools/gopls "$GOPLS_VERSION" \
    && binary_has_version "$DATA_DIR/bin/goimports" golang.org/x/tools "$GOIMPORTS_VERSION" \
    && binary_has_version "$DATA_DIR/bin/dlv" github.com/go-delve/delve "$DELVE_VERSION"; then reuse_tools=1; fi
fi
if ((!reuse_tools)); then
  printf '\nBuilding pinned Go tools (first install can take several minutes)…\n'
  mkdir -p "$stage/bin"
  # These are host executables even when the developer exports GOOS/GOARCH for WASI.
  export GOCACHE="${GOCACHE:-$DATA_DIR/cache/go-build}"
  export GOMODCACHE="${GOMODCACHE:-$DATA_DIR/cache/go-mod}"
  GOBIN="$stage/bin" GOTOOLCHAIN=local GOOS="$go_os" GOARCH="$go_arch" go install "golang.org/x/tools/gopls@$GOPLS_VERSION"
  GOBIN="$stage/bin" GOTOOLCHAIN=local GOOS="$go_os" GOARCH="$go_arch" go install "golang.org/x/tools/cmd/goimports@$GOIMPORTS_VERSION"
  GOBIN="$stage/bin" GOTOOLCHAIN=local GOOS="$go_os" GOARCH="$go_arch" go install "github.com/go-delve/delve/cmd/dlv@$DELVE_VERSION"
  GOBIN="$stage/bin" GOTOOLCHAIN=local GOOS="$go_os" GOARCH="$go_arch" go install "golang.org/x/perf/cmd/benchstat@$BENCHSTAT_VERSION"
  for binary in gopls goimports dlv benchstat; do mv -f -- "$stage/bin/$binary" "$DATA_DIR/bin/$binary"; done
  printf '%s\n' "$tool_stamp" > "$DATA_DIR/bin/.versions"
fi
printf '\nExecutable dependencies are ready.\n'
"$DATA_DIR/toolchain/nvim/bin/nvim" --version | head -n 1
go version
"$DATA_DIR/bin/gopls" version
"$DATA_DIR/bin/dlv" version
"$DATA_DIR/bin/benchstat" -h >/dev/null 2>&1 || true
