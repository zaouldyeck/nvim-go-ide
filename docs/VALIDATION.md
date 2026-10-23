# Validation record

Validated on **20 October 2026**, using the actual tools and plugin revisions
included in this configuration. Execution host: **Ubuntu 24.04, Linux x86_64**.
The primary installation target is Fedora Asahi Remix on ARM64; that machine's
desktop, terminal and kernel were not available for live execution.

## Installation

| Check | Result |
| --- | --- |
| All installer/checker Bash scripts parse | Passed |
| All Lua configuration files compile under bundled Neovim | Passed |
| Official Neovim, Go and optional Nerd Font release SHA-256 values | Passed |
| Pinned gopls, goimports and Delve build and execute | Passed |
| Tool reuse validates embedded module versions | Passed |
| `--help` and `--check` flags | Passed |
| Configuration and launcher paths containing spaces | Passed |
| Existing configuration and launcher preserved in timestamped backups | Passed |
| Complete installer, including plugin restoration and 13 compiled parsers | Passed |
| Reinstallation completes without parser confirmation prompts | Passed |
| Final installed launcher and `scripts/check.sh` | Passed, exit 0 |
| Installed guide, settings command, directory launch and `:Tutor` | Passed |

The installed parsers are Go, go.mod, go.sum, go.work, Lua, Vim, Vim help,
Tree-sitter queries, JSON, YAML, Bash, Markdown and inline Markdown.

## Go editing and execution

| Check | Result |
| --- | --- |
| Missing fmt import is inserted and source is formatted | Passed |
| gopls attaches to a real Go module | Passed |
| Hover, document symbols, completion and definition requests | Passed |
| Rename returns edits across multiple files | Passed |
| Standard-library definition navigation reuses the existing gopls workspace | Passed |
| Nearest-test selection ignores fake functions in comments | Passed |
| File scope includes its tests/subtests and excludes tests in other files | Passed |
| Package scope and module scope | Passed |
| Failure in a subpackage resolves to the exact source file and line | Passed |
| Successful t.Log output does not create false quickfix failures | Passed |
| Coverage profile, editor signs and clearing | Passed |
| `go run` uses the terminal and exits successfully | Passed |

## Debugging

These were live Delve/DAP sessions, not just configuration checks.

| Check | Result |
| --- | --- |
| Launch a Go program and stop at a configured breakpoint | Passed |
| Evaluate the paused program's `answer` variable | Returned `42` |
| Continue the program to normal exit | Passed |
| Debug the nearest Go test and stop at a breakpoint | Passed |
| Evaluate the paused test's `got` variable | Returned `5` |
| Continue the test to completion | Passed |
| Rerun the previous debug test after changing to another Go module | Passed |

## Interactive interface

An actual Neovim UI was attached through its MessagePack UI protocol. The
screenshots supplied with this package were rendered from its real cell grid,
highlight attributes and the installed font.

- No startup or runtime errors after the completed UI scenario.
- Explorer, open-file tabs, Go highlighting, breadcrumbs and minimap rendered.
- Symbol outline and fuzzy file search opened and closed successfully.
- Problems, Output and Terminal switched without blocking.
- An empty Problems list remained usable.
- Exiting the shell and reopening Terminal started a fresh shell.
- Running the sample tests in the integrated terminal succeeded.

## First visual revision: current Neovim style

The first appearance revision was validated on the same Linux x86_64 host on
20 October 2026. At that stage, the native tool versions, plugin lockfile,
installer, language-server configuration, completion dependencies and debugger
configuration were unchanged from the original release. The later Neo-tree
migration and hover refinements are recorded separately below.

| Check | Result |
| --- | --- |
| Revised Lua files compile and the navy theme loads under the pinned Neovim | Passed |
| Relative numbers enabled; current absolute line highlighted in amber | Passed |
| One-file tab strip hidden; multiple-file strip visible; hidden again after closing the second file | Passed |
| Breadcrumbs hidden initially; command and shortcut toggle them across two code windows | Passed |
| Minimap hidden initially; shortcut opens and closes it in a wide window | Passed |
| Screenshot palette, italic keywords, gopher icons and powerline status lines | Visually inspected |
| Actual UI previews with normal and fallback fonts | No missing glyphs |
| Saving Go inserts a missing import and formats the source | Passed |
| `:GoTest package` through the revised editor | 5 passed, 0 failed |
| Integrated shell exit/restart and `go test ./...` | Passed |
| Final installed launcher and portable installation checker | Passed, exit 0 |

The default preview shows the compact layout. `nvim-go-workbench.png` shows
the optional file tabs, breadcrumbs and minimap together. The UI error state
was empty at startup and completion; the message history contains only
expected layout-toggle notices and a passing test summary. The live Delve
checks above belong to the original release and were not repeated for this
appearance revision.

## Detail revision: Neo-tree, Horizon and bordered documentation

This revision uses actual Neo-tree in place of nvim-tree. The lockfile now
contains 27 plugins, including Neo-tree `v3.x` at
`1a14083046d96e88e361d1da00761c40d45012f3` and Nui at
`10fc361835c856ba4233ef5ea135b919bf3dce97`. Native tool versions, Go task runners,
language-server configuration, completion and debugger configuration remain
as previously tested.

The UI checks use a real 160-column by 40-row Neovim instance and a fresh copy
of the bundled sample project. Previews are rendered directly from the editor's
UI cells and highlight attributes. The preview directory is an actual temporary
directory; its path has not been replaced with a pretend home directory.

| Check | Result |
| --- | --- |
| Startup and completion error state | Empty; no unexpected RPC notifications |
| Active Normal status line, mode and location blocks | Both `#e95678`, with `#1c1e26` text |
| Active Insert status line, mode and location blocks | Both `#25b2bc`, with `#1c1e26` text |
| Actual Neo-tree sidebar | 40 columns, blue open folder, full bold italic root path |
| Hidden-file summary | Native `(2 hidden items)`; dotfiles hidden initially |
| Hidden-file summary colour | Screenshot-matched `#424455` |
| Explorer shortcuts | `H` shows/hides filtered entries; `?` opens help; `Ctrl+B` closes from the tree; `Space e` reopens; `Space E` reveals the file |
| Native gopls hover on `WithOutStream` | Correct Go signature and pkg.go.dev link |
| Hover window border | All four rounded corners visible; `#7aa2f7` on dark panel |
| Hover syntax rendering | Six distinct colours in the native Go signature |
| Hover documentation link | Full label `#2ac3de`; inline symbol background `#414868` |
| Hover sizing | Content fits inside the configured adaptive size limits |
| First `K`, then second `K` | Opens without taking focus, then focuses the card |
| Focused hover `q` and `Esc` | Close the card and return to the source |
| Source cursor movement | Dismisses the unfocused documentation card |
| Native signature help | Go signature and active-parameter handling retained, same border styling |
| Tabs, breadcrumbs and minimap | Default compact view and toggles passed |
| Saving Go through the editor | Missing import inserted and source formatted |
| `:GoTest package` | 5 passed, 0 failed |
| Integrated shell | Exit/restart and `go test ./...` passed |

A separate first-load check began with copied caches for the 25 unchanged
plugins and no Neo-tree or Nui directories. Normal profile startup installed
both missing dependencies; `Lazy restore` selected the exact recorded commits.
All 27 plugins were present, the portable `scripts/check.sh` returned exit 0,
and an attached UI launched with `nvim-go .` displayed the sample directory in
Neo-tree. This check used its own config, data, cache and state paths.

The migration also fixes Neo-tree's cleanup of the disabled built-in file
browser: an empty `FileExplorer` autocommand group is created before setup.
The editor's error state is not cleared or ignored to pass validation.

The standalone hover check exercised the real bundled gopls, Markdown parser,
injected Go parser and native signature-help handler. The full Delve sessions
recorded earlier were not repeated for this visual revision. The isolated
first-load check reused existing native tools and parsers; it did not rebuild
them.

After the complete integration pass, a focused final pass checked the two
remaining colour adjustments, Explorer shortcuts, hover interactions and
refreshed all previews. Go execution checks were not needlessly repeated for
those highlight-only changes.

Included previews: `nvim-go-editor.png` (Normal), `nvim-go-insert.png` (Insert),
`nvim-go-hover.png` (documentation), `nvim-go-workbench.png` (optional panels)
and `nvim-go-terminal.png` (integrated shell).

## Personal workflow migration: snippets, search and module tidy

Validated on **21 October 2026**, starting from repository commit
`a7b42f764bf91b896f1a0bc7f04e30ca9e552ac1`. Execution used the pinned Neovim
**0.11.7** and Go **1.27.3** on the same Linux x86_64 host. The plugin lockfile
adds Telescope UI Select at
`6e51d7da30bd139a6950adf2a47fda6df9fa06d2`; the other plugin revisions and
native tool versions are unchanged.

| Check | Result |
| --- | --- |
| Full profile startup and `go_ide.doctor` | Passed, including all checked tools, plugins, Go parser and commands |
| All 12 custom snippet triggers, keyed reload and preservation of unrelated snippets | Passed |
| Function expansion, nested forward/backward stops and both return-choice keys | Passed |
| Multiple, single and no return types; correct optional spacing | Passed |
| Value/pointer method receivers, struct aliases and main aliases | Passed |
| Ctrl+L/Ctrl+H through LSP-style argument placeholders | Passed |
| Visible completion menu during a snippet jump | Passed; text retained and next field selected |
| Insert/Select fallbacks and local jump guards with snippet history enabled | Passed |
| Normal Ctrl+H/Ctrl+L between Neo-tree and source | Passed |
| Restored search mappings and current-buffer fuzzy picker | Passed in the attached UI |
| `vim.ui.select` dropdown | Correct choice, callback called exactly once; border and palette visually inspected |
| Real gopls completion for `Printf` | Argument placeholders supplied and Ctrl+L advanced to the second argument |
| Completion candidate inserted while editing a snippet | Ctrl+L closed the menu, kept `string` and selected `error` |
| `GoModTidy` focused suite | 39 checks passed |
| Updated PDF guide and shortcut reference | All 21 pages rendered and visually inspected |
| PDF rebuild from a different working directory | Passed; identical inputs produced identical bytes |
| Final patch whitespace check | Passed |

The portable snippet suite contains eight interaction groups. It uses the real
pinned LuaSnip, nvim-cmp and cmp_luasnip plugins in an isolated Neovim child,
without downloading dependencies. A separate attached-UI check covered an
actual selected completion candidate: after inserting `string` in the first
return field, Ctrl+L preserved `func Name(x int) (string, error) {` and moved to
the `error` field. Real gopls completion was also checked independently of the
synthetic LSP-style snippet fixture.

The module-tidy suite uses real Go with offline, temporary modules. It checks
the active module even when the editor's working directory is elsewhere,
paths containing spaces, saving modified source and metadata, excluding nested
modules, invocation from Go/go.mod/go.sum, clean metadata reload, unsaved edits
made during the job, invalid metadata, busy-task rejection, cancellation and
rejection outside a module. The suite completed with:

```text
GoModTidy: 39 checks passed (offline real Go, module scope, saves/reload, failures and cancellation)
```

After installing this revision, run the portable suites from the repository
root with the installed launcher:

```bash
~/.local/bin/nvim-go --headless -u NONE -i NONE -l scripts/test-snippets.lua
~/.local/bin/nvim-go --headless -u NONE -l scripts/test-go-tidy.lua
```

The first script also accepts an explicit plugin directory as its final
argument; the second accepts an explicit Go executable. They create isolated
temporary fixtures and do not edit project files.

This migration's integration check reused the pinned native tools and parsers.
All 25 reused plugin checkouts matched their lockfile commits. The environment's
Git proxy was unavailable, so the missing Neo-tree, Nui and UI Select runtime
files were retrieved through the GitHub connector; all 116 retrieved files
matched their Git blob hashes. The assembled profile passed its doctor and UI
checks. A fresh networked installer run and the earlier full Delve sessions
were not repeated for this migration.

LuaSnip's existing optional `repeat#set` call is suppressed upstream but can
leave `E117` in `vim.v.errmsg` after snippet expansion when vim-repeat is not
installed. It produced no visible error or message in these interaction
checks. Fresh-start error state and doctor checks passed; this migration does
not add vim-repeat or alter that upstream behavior.

## Ultimate Go IDE v3: performance, workspaces and advanced Go workflows

Validated on **23 October 2026** in GitHub Actions on Ubuntu 24.04 x86_64,
using the repository's pinned Neovim 0.11.7 and a fresh isolated profile.

| Check | Result |
| --- | --- |
| Fresh installer after optional-plugin lazy-loading changes | Passed |
| Headless plugin restore and all 13 parser installations | Passed |
| Portable `scripts/check.sh` / doctor | Passed |
| Pinned benchstat build | Passed |
| Bundled sample normal tests | Passed |
| Bundled sample `go test -race ./...` | Passed |
| Bundled `BenchmarkApp` execution with allocations | Passed |
| New commands and tool checks | Passed by doctor |
| Tree-sitter bootstrap under lazy loading | Passed after explicit bootstrap load |

The first lazy-loading CI runs exposed a real installer regression:
`TSInstallSync` was invoked before the lazy Tree-sitter plugin had registered
its command. The bootstrap now explicitly loads `nvim-treesitter` after
`Lazy restore` and before parser installation. The subsequent fresh-install
run completed successfully.

The v3 branch also adds project workspaces, project-local `.nvim-go.json`
settings, Tree-sitter-native Go text objects, call hierarchy, Git branch review,
module browsing, race-test commands, benchmark baseline/comparison through
benchstat, startup profiling, large-file mode and optional-plugin lazy loading.
The original Horizon per-pane statusline remains unchanged.

## ARM64 static check

The official pinned `nvim-linux-arm64.tar.gz` was downloaded separately and its
SHA-256 matched the installer value. Its executable is ELF64 AArch64. Both
loadable ELF segments use 65,536-byte alignment, and their file and virtual
offsets are congruent modulo 16,384 bytes. This passes the load-segment alignment
check relevant to a 16 KiB-page ARM64 system.

This does **not** constitute execution on an Asahi Mac. On-machine checks still
cover the selected terminal font, desktop clipboard, keyboard interception,
graphics/display settings and OS-level debugging permissions. Use
`:GoIdeHealth` after opening a Go project on the target machine.

## Boundaries

- Native ARM64 and macOS installation paths are implemented; only Linux x86_64
  was executed end to end.
- Initial installation requires network access. New Go dependencies can require
  later network access.
- The terminal owns font size, line spacing, outer window decorations and shell
  appearance; this profile configures the editor.
- The Go tools intentionally run the current package or module. Multi-module
  workspace-wide test orchestration is left to ordinary Go commands.
- Temporary UI integration scripts contain local fixture paths and are omitted
  from the package. The portable installation checker, snippet/module-tidy
  interaction suites and executable sample tests are included.
