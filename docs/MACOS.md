# macOS installation

This guide installs the same isolated `nvim-go` profile on macOS without
touching your normal Neovim configuration.

The primary target is an **Apple Silicon Mac** running current macOS. As of
October 2026, Apple's latest macOS release is **macOS Golden Gate 27.0.1**.
The install commands below are intentionally version-agnostic so they continue
to work across compatible macOS updates.

The repository also contains a Darwin `x86_64` code path for older Intel Macs,
but macOS Golden Gate 27 itself targets Apple Silicon. Homebrew also treats
Intel macOS as a lower support tier, so Apple Silicon is the recommended macOS
setup.

## 1. Install the system prerequisites

### Apple Command Line Tools

Install Apple's Command Line Tools:

```bash
xcode-select --install
```

A macOS dialog opens. Complete the installation, then verify the active tools:

```bash
xcode-select --print-path
clang --version
git --version
```

`/Library/Developer/CommandLineTools` is a normal result when you use the
standalone Command Line Tools package. A full Xcode installation is not required
for this Neovim profile.

Apple's documentation:
[Installing the command-line tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/)

### Homebrew and ripgrep

The profile needs `rg` (ripgrep). Homebrew is the simplest way to install it.

If Homebrew is not installed, use the current installer from
[brew.sh](https://brew.sh/):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the shell setup instructions printed by Homebrew. On a standard Apple
Silicon install, this usually means making `/opt/homebrew/bin/brew` available
to your shell. For the current shell you can run:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Then install ripgrep:

```bash
brew install ripgrep
rg --version
```

The remaining prerequisites used by `install.sh` are supplied by macOS and the
Command Line Tools: `git`, `curl`, `tar`, `unzip`, `clang` and
`shasum`.

You do **not** need to install Neovim or Go with Homebrew for this profile.
The installer downloads the repository's pinned Neovim release and supplies its
private Go toolchain when needed.

## 2. Clone and install

```bash
git clone https://github.com/zaouldyeck/nvim-go-ide.git
cd nvim-go-ide
bash install.sh --font
```

The installer detects `Darwin:arm64` on Apple Silicon and downloads the pinned
native macOS ARM64 Neovim archive. It installs the profile under these default
paths:

| Content | Default path |
| --- | --- |
| Configuration | `~/.config/nvim-go` |
| Plugins, parsers and private tools | `~/.local/share/nvim-go` |
| Launcher | `~/.local/bin/nvim-go` |
| Nerd Font | `~/Library/Fonts/JetBrainsMonoNerdFontMono` |

Your ordinary `nvim` configuration remains separate because the launcher uses
`NVIM_APPNAME=nvim-go`.

Check the finished installation from the repository root:

```bash
bash scripts/check.sh ~/.local/bin/nvim-go
```

Then open the bundled sample:

```bash
cd sample-project
~/.local/bin/nvim-go main.go
```

Inside Neovim, run:

```vim
:GoIdeHealth
```

## 3. Make the macOS UI match the screenshots

The terminal controls the final glyph shape, font rasterization, cell size and
window transparency. The Neovim profile controls the editor colours and layout.

### Use the exact Nerd Font

`bash install.sh --font` installs **JetBrainsMono Nerd Font Mono**. Fully quit
and reopen the terminal after the first font install, then select that exact
family.

Do not select ordinary **JetBrains Mono** if you want the file icons, rounded
Powerline caps and status-line symbols to match.

Suggested starting size: **12–14 pt**.

### Ghostty

Ghostty can use the installed font directly. A minimal macOS configuration is:

```ini
font-family = JetBrainsMono Nerd Font Mono
font-size = 13
background-opacity = 1
```

Ghostty accepts configuration in `~/.config/ghostty/config.ghostty` and also
supports its macOS Application Support location. Reload its configuration with
**Cmd+Shift+,** or restart Ghostty.

Reference:
[Ghostty configuration](https://ghostty.org/docs/config)

### Terminal.app or iTerm2

Select **JetBrainsMono Nerd Font Mono** as the profile font in the terminal's
preferences. Use an opaque background for the closest colour match.

### Window width matters

The minimap is enabled only on sufficiently wide editor windows. The current
profile threshold is **140 terminal columns**. If everything else looks right
but the minimap is missing:

1. maximize or widen the terminal;
2. reduce the terminal font size slightly; or
3. toggle it with **Space m m**.

The exact pixel width is terminal-dependent; the important measurement is the
number of terminal columns.

## 4. Clipboard on macOS

No extra clipboard package is needed. Neovim supports macOS
`pbcopy`/`pbpaste` as a clipboard provider.

Check it inside Neovim with:

```vim
:checkhealth vim.provider
```

The profile sets `clipboard=unnamedplus`, so normal yank/delete/paste workflows
can use the system clipboard when the provider is available.

Reference:
[Neovim clipboard providers](https://neovim.io/doc/user/provider/#clipboard)

## 5. Optional: put nvim-go on PATH

The installer deliberately does not edit your shell startup files. The full
launcher path always works:

```bash
~/.local/bin/nvim-go .
```

If you want to type just `nvim-go`, add `~/.local/bin` to your zsh PATH:

```bash
printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> ~/.zshrc
exec zsh
```

This is optional.

## 6. macOS troubleshooting

### xcode-select reports no active developer directory

Run:

```bash
xcode-select --install
```

After a major macOS upgrade, Apple recommends checking for a compatible Command
Line Tools update through Software Update.

If the tools are installed but another Xcode selection is broken, inspect:

```bash
xcode-select --print-path
```

### brew: command not found after installing Homebrew

On an Apple Silicon Mac, load Homebrew into the current shell:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Then follow Homebrew's printed instructions to make that persistent in future
shells.

### Icons are squares or the rounded tab edges are wrong

Confirm the terminal is actually using:

```text
JetBrainsMono Nerd Font Mono
```

Restart the terminal after changing the font.

### The colours look different from Linux

Use an opaque terminal background and confirm true colour is enabled. macOS font
rasterization and terminal rendering can still make glyphs look slightly
different even with the same Neovim palette.

### The minimap does not appear

Check the current terminal width inside Neovim:

```vim
:echo &columns
```

It should normally be at least 140 columns for the minimap to open
automatically. You can always toggle it with **Space m m**.

### Clipboard integration is missing

Run:

```vim
:checkhealth vim.provider
```

A normal local macOS session should detect `pbcopy`/`pbpaste`.

## Official references

- [Latest macOS versions](https://support.apple.com/109033)
- [Apple Command Line Tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/)
- [Homebrew installation](https://brew.sh/)
- [Homebrew macOS support](https://docs.brew.sh/Installation.html)
- [Neovim clipboard providers](https://neovim.io/doc/user/provider/#clipboard)
- [Ghostty configuration](https://ghostty.org/docs/config)
