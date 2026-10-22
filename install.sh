#!/usr/bin/env bash
# Isolated, reproducible Neovim Go IDE installer. Never changes shell rc files.
set -euo pipefail

PACKAGE_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_BASE="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_DIR="$CONFIG_BASE/nvim-go"
DATA_DIR="$DATA_BASE/nvim-go"
BIN_DIR="${NVIM_GO_BIN_DIR:-$HOME/.local/bin}"
INSTALL_FONT=0
INSTALL_GO=0
CHECK_ONLY=0
SKIP_PLUGINS=0

usage() {
  cat <<'EOF'
Usage: bash install.sh [--font] [--install-go] [--check] [--skip-plugins]

  --font          Install JetBrainsMono Nerd Font Mono for this user.
                  Select it in your terminal afterwards; no terminal settings change.
  --install-go    Always install the pinned private Go toolchain.
                  It is also installed automatically if Go 1.27 is unavailable.
  --check         Show prerequisites and target paths; make no changes.
  --skip-plugins  Install files/tools only; defer plugin and parser downloads.
                  Advanced/offline-staging option. This is not a complete IDE install.
  --help          Show this help.

The launcher is ~/.local/bin/nvim-go. Ordinary nvim is unaffected.
For custom locations, XDG_CONFIG_HOME, XDG_DATA_HOME and NVIM_GO_BIN_DIR are honored.
An internet connection is required for Neovim, Go tools, plugins and parsers.
Existing nvim-go configuration and launcher files are backed up on reinstall.
EOF
}

while (($#)); do
  case "$1" in
    --font) INSTALL_FONT=1 ;;
    --install-go) INSTALL_GO=1 ;;
    --check) CHECK_ONLY=1 ;;
    --skip-plugins) SKIP_PLUGINS=1 ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

platform=$(uname -s)
machine=$(uname -m)
case "$platform:$machine" in Linux:aarch64|Linux:arm64|Linux:x86_64|Darwin:arm64|Darwin:x86_64) ;;
  *) printf 'Supported systems: Linux/macOS on ARM64 or x86_64. Found: %s %s\n' "$platform" "$machine" >&2; exit 1 ;;
esac
for directory in "$CONFIG_BASE" "$DATA_BASE" "$BIN_DIR"; do
  case "$directory" in /*) ;; *) printf 'XDG and home paths must be absolute: %s\n' "$directory" >&2; exit 1 ;; esac
done

printf 'Neovim Go IDE — %s %s\n' "$platform" "$machine"
printf 'Config:   %s\nData:     %s\nLauncher: %s/nvim-go\n' "$CONFIG_DIR" "$DATA_DIR" "$BIN_DIR"
missing=0
for dependency in git curl tar unzip rg; do
  if ! command -v "$dependency" >/dev/null 2>&1; then printf 'Missing prerequisite: %s\n' "$dependency" >&2; missing=1; fi
done
if ! command -v cc >/dev/null 2>&1 && ! command -v gcc >/dev/null 2>&1 && ! command -v clang >/dev/null 2>&1; then
  printf 'Missing prerequisite: C compiler (gcc/clang), needed for syntax parsers.\n' >&2; missing=1
fi
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
  printf 'Missing prerequisite: sha256sum or shasum.\n' >&2; missing=1
fi
if ((missing)); then
  if [[ "$platform" == Linux ]]; then
    printf '\nFedora / Fedora Asahi Remix:\n  sudo dnf install git curl tar unzip gcc ripgrep wl-clipboard fontconfig\n'
    printf '\nDebian / Ubuntu:\n  sudo apt install git curl tar unzip gcc ripgrep wl-clipboard fontconfig\n'
  else
    printf '\nmacOS: install Command Line Tools (xcode-select --install), then install Homebrew if needed and run brew install ripgrep\n'
  fi
  exit 1
fi
if [[ "$platform" == Linux ]] && ! command -v wl-copy >/dev/null 2>&1 && ! command -v xclip >/dev/null 2>&1 && ! command -v xsel >/dev/null 2>&1; then
  printf 'Clipboard helper missing: on Fedora GNOME, run sudo dnf install wl-clipboard.\n'
fi
if [[ ! -f "$PACKAGE_DIR/config/init.lua" ]]; then
  printf 'The package is incomplete: config/init.lua is missing. Extract the entire archive.\n' >&2; exit 1
fi
if ((CHECK_ONLY)); then
  printf '\nPrerequisite check passed. Nothing was changed.\n'
  exit 0
fi

tools_options=(--data-dir "$DATA_DIR")
if ((INSTALL_GO)); then tools_options+=(--install-go); fi
bash "$PACKAGE_DIR/scripts/bootstrap-tools.sh" "${tools_options[@]}"

mkdir -p "$CONFIG_BASE" "$BIN_DIR" "$DATA_DIR"
config_stage=$(mktemp -d "$CONFIG_BASE/.nvim-go-install.XXXXXXXX")
trap 'rm -rf -- "$config_stage"' EXIT
cp -R "$PACKAGE_DIR/config/." "$config_stage/"
# Keep package documentation and operational helpers reachable after extraction is deleted.
mkdir -p "$config_stage/docs" "$config_stage/scripts"
if [[ -d "$PACKAGE_DIR/docs" ]]; then cp -R "$PACKAGE_DIR/docs/." "$config_stage/docs/"; fi
cp "$PACKAGE_DIR/scripts/versions.env" "$config_stage/scripts/versions.env"
cp "$PACKAGE_DIR/scripts/bootstrap-tools.sh" "$config_stage/scripts/bootstrap-tools.sh"
if [[ -f "$PACKAGE_DIR/scripts/check.sh" ]]; then cp "$PACKAGE_DIR/scripts/check.sh" "$config_stage/scripts/check.sh"; fi

stamp=$(date '+%Y%m%d-%H%M%S')-$$
if [[ -e "$CONFIG_DIR" || -L "$CONFIG_DIR" ]]; then
  config_backup="$CONFIG_DIR.backup-$stamp"
  mv -- "$CONFIG_DIR" "$config_backup"
  printf '\nPrevious profile configuration: %s\n' "$config_backup"
fi
mv -- "$config_stage" "$CONFIG_DIR"
if [[ -e "$BIN_DIR/nvim-go" || -L "$BIN_DIR/nvim-go" ]]; then
  launcher_backup="$BIN_DIR/nvim-go.backup-$stamp"
  mv -- "$BIN_DIR/nvim-go" "$launcher_backup"
  printf 'Previous launcher: %s\n' "$launcher_backup"
fi

# Quoted Bash literals preserve spaces, apostrophes and other path characters.
{
  printf '#!/usr/bin/env bash\nset -euo pipefail\n'
  printf 'export NVIM_APPNAME=nvim-go\n'
  printf 'export XDG_CONFIG_HOME=%q\n' "$CONFIG_BASE"
  printf 'export XDG_DATA_HOME=%q\n' "$DATA_BASE"
  printf 'profile_data=%q\n' "$DATA_DIR"
  cat <<'EOF'
export PATH="$profile_data/bin:$PATH"
if [[ -x "$profile_data/toolchain/go/bin/go" ]]; then
  export PATH="$profile_data/toolchain/go/bin:$PATH"
  unset GOROOT
fi
exec "$profile_data/toolchain/nvim/bin/nvim" "$@"
EOF
} > "$BIN_DIR/nvim-go"
chmod u+x "$BIN_DIR/nvim-go"

if ((INSTALL_FONT)); then
  # shellcheck source=scripts/versions.env
  source "$PACKAGE_DIR/scripts/versions.env"
  font_zip="$DATA_DIR/downloads/JetBrainsMono-$NERD_FONT_VERSION.zip"
  if [[ ! -f "$font_zip" ]]; then
    curl --fail --location --retry 3 --connect-timeout 30 --proto '=https' --tlsv1.2 \
      --output "$font_zip.part" "https://github.com/ryanoasis/nerd-fonts/releases/download/v$NERD_FONT_VERSION/JetBrainsMono.zip"
  else
    cp -- "$font_zip" "$font_zip.part"
  fi
  if command -v sha256sum >/dev/null 2>&1; then actual=$(sha256sum "$font_zip.part" | awk '{print $1}')
  else actual=$(shasum -a 256 "$font_zip.part" | awk '{print $1}'); fi
  if [[ "$actual" != "$NERD_FONT_SHA256" ]]; then
    rm -f -- "$font_zip.part"
    printf 'Nerd Font checksum mismatch. No font files were installed.\n' >&2; exit 1
  fi
  mv -- "$font_zip.part" "$font_zip"
  if [[ "$platform" == Darwin ]]; then font_dir="$HOME/Library/Fonts/JetBrainsMonoNerdFontMono"
  else font_dir="$DATA_BASE/fonts/JetBrainsMonoNerdFontMono"; fi
  mkdir -p "$font_dir"
  unzip -jo "$font_zip" '*NerdFontMono-*.ttf' -d "$font_dir"
  if command -v fc-cache >/dev/null 2>&1; then fc-cache -f "$font_dir"; fi
  printf '\nSelect "JetBrainsMono Nerd Font Mono" in your terminal font settings.\n'
fi

if ((!SKIP_PLUGINS)); then
  printf '\nInstalling the pinned plugins and syntax parsers…\n'
  "$BIN_DIR/nvim-go" --headless \
    -c 'lua local ok, err = xpcall(function() require("go_ide.bootstrap").run() end, debug.traceback); if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") end' \
    -c 'qa'
fi
printf '\nInstallation complete.\n'
printf 'Open a project:  %q ~/code/golang/cli\n' "$BIN_DIR/nvim-go"
printf 'Check health:    %q +GoIdeHealth\n' "$BIN_DIR/nvim-go"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) printf '\nYour PATH does not contain %s. Use the full launcher path shown above.\n' "$BIN_DIR" ;; esac
if ((SKIP_PLUGINS)); then
  printf '\nPlugins were deferred. Complete the installation with:\n'
  printf '  %q --headless %q +qa\n' "$BIN_DIR/nvim-go" '+lua require("go_ide.bootstrap").run()'
fi
