# Neovim Go IDE

A complete, isolated Neovim profile for daily Go development. It combines the
navy palette, italic syntax, relative numbers, and status line of your current
Neovim screenshot with the Go IDE workflow built for this package. Start it
with `nvim-go`.

## Install on Fedora Asahi Remix

From the directory containing this file:

```bash
sudo dnf install git curl tar unzip gcc ripgrep wl-clipboard fontconfig
bash install.sh --font
bash scripts/check.sh ~/.local/bin/nvim-go
cd sample-project
~/.local/bin/nvim-go main.go
```

Select **JetBrainsMono Nerd Font Mono** in your terminal's font settings.
The optional font installer does not change your selected terminal font.
The installer needs internet access and a C compiler for the syntax parsers.
It selects native Linux ARM64 binaries on Fedora Asahi. Linux x86_64 and macOS
ARM64/x86_64 paths are also included; Linux x86_64 was the execution test host.

For your own project:

```bash
cd ~/code/golang/cli
~/.local/bin/nvim-go .
```

## What is included

| Area | Features |
| --- | --- |
| Appearance | Screenshot-sampled navy palette, italic purple keywords, cyan Go gophers, relative line numbers, tab guides, Horizon status line with rose-red Normal and cyan Insert accents at both ends, automatic open-file tabs, optional breadcrumbs and minimap |
| Navigation | Neo-tree Explorer with a blue folder icon, bold italic directory header and hidden-file summary; fuzzy file search, project text search, outline, document/workspace symbols, split windows, definition/reference/implementation jumps |
| Go editing | gopls, completion, snippets, rounded bordered signature help and rich hover docs, rename, code actions, import management, format on save, optional inlay hints and code lenses |
| Execution | Run the current package in a terminal with stdin support; run nearest/file/package/module tests; navigable failure locations; coverage markers |
| Debugging | Delve, breakpoints and conditional breakpoints, step/continue, locals, watches, call stacks, expression evaluation, nearest-test debugging, compatible Go launch.json entries |
| Daily workflow | Git gutter changes, hunk preview/staging/reset, blame, integrated shell, persistent undo, mouse support, discoverable Space-prefixed keys |
| Delivery | Installer, exact plugin lockfile, pinned native tool versions, sample CLI and tests, getting-started guide, shortcut reference, installation checker |

## Start here

- Read [the getting-started guide](docs/GETTING_STARTED.md).
- Keep [the complete shortcut reference](docs/SHORTCUTS.md) nearby.
- Open the printable `nvim-go-getting-started.pdf` supplied with this package.
- Review [what was actually tested](docs/VALIDATION.md).

Inside Neovim, `:GoIdeGuide`, `:GoIdeSettings`, and `:GoIdeHealth` open the guide,
preferences, and diagnostics. Press **Esc**, then **Space** and pause to discover
the available actions. For example, **Space f f** finds a file and **Space t t**
runs the nearest test.

The default view stays compact: file tabs appear when more than one file is
open, while breadcrumbs and the minimap start hidden. Use **Space u b** for
breadcrumbs, **Space m m** for the minimap, and **Space u n** to switch line
number styles. Search, the symbol outline, tests, and debugging remain available
in this layout.

The Explorer is 40 columns wide. Its header keeps the beginning of the directory
path, replacing your home directory with `~` when applicable. Press **H** inside
Explorer to show or hide filtered files, and **?** for its local key reference.
The active editor's status line uses Horizon's **`#e95678`** in Normal mode and
**`#25b2bc`** in Insert mode; inactive panes have subdued status lines.

Press **K** on a Go symbol for syntax-coloured documentation in a dark card
with a rounded blue border. Press **K** again to focus it, scroll with **j/k**
or **Ctrl+D / Ctrl+U**, and close it with **q** or **Esc**. Moving the cursor in
the source dismisses an unfocused card. **Ctrl+K** in Insert mode shows signature
help with the same border.

## Installation and version choices

The default profile uses `~/.config/nvim-go` and `~/.local/share/nvim-go`, with a
launcher at `~/.local/bin/nvim-go`. Neovim's `NVIM_APPNAME` keeps its configuration,
plugins, state and cache separate from ordinary `nvim`.

The installer pins Neovim **0.11.7**, gopls **v0.24.0**, goimports from x/tools
**v0.52.0**, and Delve **v1.27.2**. If a suitable Go 1.27 toolchain is not already
available, it installs a private **Go 1.27.3** for this profile. `--install-go`
forces that private toolchain. These versions are recorded in
`scripts/versions.env`; the exact plugin commits are in `config/lazy-lock.json`.

Neovim 0.11.7 is intentionally paired with nvim-treesitter's frozen `master`
API and Aerial's `nvim-0.11` compatibility branch. Change the editor and related
plugin APIs together if you later migrate to a newer Neovim series. The
configuration avoids the deprecated `require('lspconfig').gopls.setup()` path.
Neo-tree's `v3.x` branch and its Nui dependency are pinned alongside the other
plugins; the installer restores all 27 recorded plugin revisions.

To install this revision over the earlier package, extract the new archive into
a fresh directory. From its `go-ide` directory, rerun `bash install.sh --font`
and `bash scripts/check.sh ~/.local/bin/nvim-go`. Reinstalling creates timestamped
configuration and launcher backups; keep any personal edits you want to carry
over. Keep the archive to restore this exact release. The guide explains the
distinction between restoring settings and rolling back executable tools and
plugin data.

## Configuration map

| File | Purpose |
| --- | --- |
| `config/init.lua` | Startup sequence |
| `config/lua/go_ide/settings.lua` | Common user preferences and colour palette |
| `config/lua/go_ide/theme.lua` | Syntax and UI highlight groups |
| `config/lua/go_ide/keymaps.lua` | Keyboard actions |
| `config/lua/go_ide/explorer.lua` | Shared Neo-tree open, toggle and reveal actions |
| `config/lua/go_ide/hover.lua` | Native documentation/signature cards, sizing, borders and local close keys |
| `config/lua/plugins/ui.lua` | Explorer, tabs, status line, search, outline, minimap, Git |
| `config/lua/plugins/go.lua` | Completion, snippets and debugger dependencies |
| `config/lua/go_ide/lsp.lua` | gopls, formatting, imports and analysis |
| `config/lua/go_ide/go.lua` | Run, tests, quickfix and coverage |
| `config/lua/go_ide/debug.lua` | Delve launch configurations and debugger panels |
| `config/lua/go_ide/terminal.lua` | Persistent project shell |
| `scripts/versions.env` | Tool versions and official release checksums |
| `scripts/check.sh` | Installation checks; no plugin installation in check mode |

## Scope

This is a terminal-native Go IDE. Fonts, outer window chrome, terminal
transparency and your shell prompt are controlled by the terminal and shell.
The minimap uses terminal cells rather than VS Code's tiny pixel font.
VS Code's extension marketplace, Ports panel and arbitrary extension-specific
settings are not reproduced. Compatible Go debugging entries can be read from
`.vscode/launch.json`; VS Code tasks and extension commands need adaptation.

The package downloads third-party tools and plugins from their upstream sources;
their original licenses continue to apply. It does not bundle their binaries.

## Official references

- [Neovim 0.11.7](https://github.com/neovim/neovim/releases/tag/v0.11.7)
- [Neovim standard paths and NVIM_APPNAME](https://neovim.io/doc/user/starting/#standard-path)
- [gopls features](https://go.dev/gopls/features/)
- [nvim-dap-go](https://github.com/leoluz/nvim-dap-go)
- [lazy.nvim lockfiles](https://lazy.folke.io/usage/lockfile)
- [nvim-treesitter compatibility branch](https://github.com/nvim-treesitter/nvim-treesitter/tree/master)
- [Neo-tree v3.x](https://github.com/nvim-neo-tree/neo-tree.nvim/tree/v3.x)
- [lualine Horizon theme](https://github.com/nvim-lualine/lualine.nvim/blob/221ce6b2d999187044529f49da6554a92f740a96/lua/lualine/themes/horizon.lua)
- [Neovim hover documentation](https://neovim.io/doc/user/lsp/#vim.lsp.buf.hover())
