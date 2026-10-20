#!/usr/bin/env bash
# Check an installed profile without editing source files or installing packages.
set -euo pipefail
launcher="${1:-${NVIM_GO_BIN_DIR:-$HOME/.local/bin}/nvim-go}"
if [[ "$launcher" == --help || "$launcher" == -h ]]; then
  printf 'Usage: bash scripts/check.sh [absolute-path-to-nvim-go]\n'
  exit 0
fi
if [[ ! -x "$launcher" ]]; then
  printf 'Launcher is missing or not executable: %s\nRun bash install.sh first.\n' "$launcher" >&2
  exit 1
fi
NVIM_GO_CHECK_ONLY=1 "$launcher" --headless \
  -c 'lua local ok, err = xpcall(function() require("go_ide.doctor").run() end, debug.traceback); if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") end' \
  -c 'qa'
