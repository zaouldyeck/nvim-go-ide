# Neovim Go IDE — shortcut reference

Press `Esc` before a Normal-mode shortcut. **`Space` is the leader key**: press the keys in sequence, not together. A capital letter means hold `Shift` for that letter. `Ctrl+P` means hold `Ctrl` while pressing `P`.

## Start here

| Action | Shortcut | Mode / note |
| --- | --- | --- |
| Type text | `i` | Normal → Insert |
| Return to Normal mode | `Esc` | Insert / Visual |
| Save | `Ctrl+S` or `Space w w` | Normal; Ctrl+S also works while editing |
| Find a file | `Ctrl+P` or `Space f f` | Normal |
| Search project text | `Space f g` | Normal |
| Explorer | `Ctrl+B` or `Space e` | Normal |
| Documentation under cursor | `K`, then `K` again to focus | Normal |
| Go to definition | `F12` or `gd` | Normal |
| Rename symbol | `F2` or `Space r n` | Normal |
| Code actions | `Space c a` | Normal / Visual |
| Expand snippet / next placeholder | `Ctrl+L` | Insert / snippet Select |
| Previous snippet placeholder | `Ctrl+H` | Insert / snippet Select |
| Next / previous snippet choice | `Alt+N` / `Alt+P` | Insert / snippet Select, with an active choice |
| Nearest test | `Space t t` | Normal, in a Go test file |
| Run package | `Space r r` | Normal, Go file active |
| Debug / continue | `F5` or `Space d c` | Normal |
| Toggle breakpoint | `F9` or `Space d b` | Normal |
| Project terminal | `Space` then backtick | Normal; or `:GoTerminal` |
| Leave terminal input mode | `Esc`, `Esc` | Terminal → Normal |
| Show available leader keys | `Space`, then pause | Normal |

## Files, search, and layout

| Action | Shortcut |
| --- | --- |
| Find file | `Space f f` |
| Search text across project | `Space f g` |
| Choose an open buffer | `Space f b` |
| Recently opened files | `Space f r` |
| Command palette | `Space f c` |
| Symbols in current document | `Space f s` |
| Workspace symbols | `Space f S` |
| Find implementations in picker | `Space f i` |
| Fuzzy search current buffer | `Space /` |
| Search current word | `Space s w` |
| Resume last picker | `Space s r` |
| Search help / key mappings | `Space s h` / `Space s k` |
| Search text in open buffers | `Space s /` |
| Find active Neovim profile files | `Space s n` |
| Choose an open buffer (original alias) | `Space Space` |
| Find file / project text (original aliases) | `Space s f` / `Space s g` |
| Recently opened files (original alias) | `Space s .` |
| Search diagnostics | `Space s d` |
| Choose a Telescope picker | `Space s s` |
| Toggle Explorer | `Space e` |
| Reveal current file in Explorer | `Space E` |
| Toggle symbol outline | `Space o` |
| Toggle minimap | `Space m m` |
| Toggle symbol breadcrumbs | `Space u b` or `:GoIdeBreadcrumbs` |
| Toggle sticky code context | `Space u c` or `:GoIdeContext` |
| Toggle Focus Mode | `Space u f` or `:GoIdeFocus` |
| Toggle sticky code context | `Space u c` or `:GoIdeContext` |
| Toggle Focus Mode | `Space u f` or `:GoIdeFocus` |
| Next / previous buffer | `Tab` / `Shift+Tab` in Normal mode |
| Close current buffer | `Space b d` |
| Move left / down / up / right between windows | `Ctrl+H` / `Ctrl+J` / `Ctrl+K` / `Ctrl+L` |
| Create a vertical split | `Space w v` or `:vsplit` |
| Create a horizontal split | `Space w s` or `:split` |
| Close a pane | `Space w c` |
| Equalize pane sizes | `Space w =` |
| Save and quit current window | `Space w q` |
| Quit all windows | `Space q q` |

These keys apply while the **Neo-tree Explorer** is focused:

| Action | Keys |
| --- | --- |
| Open file / expand directory | `Enter` or `l` |
| Close directory node | `h` |
| Add file / add directory | `a` / `A` |
| Rename / request deletion | `r` / `d` (deletion asks for confirmation) |
| Show or hide filtered entries | `H` |
| Local Explorer help | `?` |
| Refresh | `R` |
| Go to parent directory | `Backspace` |
| Use selected directory as root | `.` |
| Open in vertical / horizontal split | `s` / `S` |
| Close Explorer | `q` or `Ctrl+B` |

Explorer starts 34 columns wide with a blue open-folder icon and bold home-relative root path. Dotfiles and ignored entries start hidden; the native `(N hidden items)` row reports the count. `H` toggles filtered entries without changing your files.

In a file/search picker, type to filter, use `Ctrl+J` / `Ctrl+K` or the arrow keys to select an item, `Enter` to open it, and `Esc` to close the picker. Telescope's default `Ctrl+V` / `Ctrl+X` open a selected file in a vertical/horizontal split, `Ctrl+T` opens it in a tab, and `Ctrl+U` / `Ctrl+D` scroll the preview.

The file strip appears automatically when several files are open. Set `always_show_tabs = true` in the profile settings to keep it visible with one file. Relative numbers are enabled by default: the highlighted number is the current file line, and surrounding numbers are distances for motions such as `5j` or `5k`.

## Go editing and navigation

| Action | Shortcut / command |
| --- | --- |
| Go to definition | `gd` or `F12` |
| Find references | `gr` |
| Find implementations | `gi` |
| Go to type definition | `gy` |
| Flash jump to visible target | `s` |
| Flash syntax-tree selection | `S` |
| Jump to sticky context | `[c` |
| Next / previous Go function or method | `]m` / `[m` |
| Next / previous Go test | `]t` / `[t` |
| Return after a jump | `Ctrl+O` or `Space j b` |
| Go forward again | `Space j f` |
| Hover documentation / focus its card | `K` / `K` again |
| Scroll focused documentation | `j` / `k`, or `Ctrl+D` / `Ctrl+U` |
| Close focused documentation | `q` or `Esc` |
| Signature help | `Ctrl+K` in Insert mode |
| Rename symbol | `Space r n` or `F2` |
| Code actions for cursor/selection | `Space c a` |
| Format and organize imports | `Space c f`, `:GoFormat`, or `:GoImports` |
| Tidy active module dependencies | `Space c m` or `:GoModTidy` |
| Toggle format on save | `:GoFormatToggle` |
| Toggle inlay hints | `Space c i` or `:GoInlayHints` |
| Run a code lens | `Space c l` |
| Toggle code-lens display | `:GoCodeLens` |
| Restart gopls | `:GoLspRestart` |
| Comment current line | `gcc` |
| Comment selected lines | `V` to select, then `gc` |
| Move current line or selected lines | `Alt+J` / `Alt+K` in Normal / Visual mode |
| Save all modified files | `:wall` |

Code actions open a Telescope dropdown and depend on the cursor location, selection, and available type information. Struct tags, interface implementation, and extraction are available when `gopls` offers them at that location. Type to filter, use `Ctrl+J` / `Ctrl+K` or the arrow keys to select, and press `Enter` to apply or `Esc` to cancel.

`:GoModTidy` runs asynchronously in the module containing the active Go file, `go.mod`, or `go.sum`. It first saves that module's modified named Go buffers and open `go.mod`/`go.sum` buffers, excluding nested modules. It reloads metadata buffers with no unsaved changes after the job and preserves unsaved edits made while it runs. Inspect output with `:GoOutput`, cancel with `:GoStop`, and review the `go.mod` / `go.sum` diff. It is an explicit action; it does not run on save.

The hover card uses native Markdown rendering and Go syntax highlighting with a rounded blue border and a **Documentation** title. Moving the source cursor dismisses an unfocused card. Insert-mode `Ctrl+K` opens matching **Signature** help; the close keys above apply while a documentation window is focused.

## Completion and snippets

Completion keys apply in Insert mode; dedicated snippet keys also work in snippet Select mode.

| Action | Keys |
| --- | --- |
| Request completion | `Ctrl+Space` |
| Select next / previous item | `Tab` / `Shift+Tab`, or `Ctrl+N` / `Ctrl+P` |
| Accept selected item | `Enter` |
| Dismiss completion | `Ctrl+E` |
| Scroll completion documentation | `Ctrl+F` / `Ctrl+B` |
| Expand snippet trigger / next placeholder | `Ctrl+L` |
| Previous snippet placeholder | `Ctrl+H` |
| Next / previous active snippet choice | `Alt+N` / `Alt+P` |
| Expand or move through snippet placeholders | `Tab` / `Shift+Tab` when completion is closed |
| Reload custom snippets after editing | `:GoSnippetsReload` in Normal mode |

No item is silently preselected: `Enter` confirms only an item you selected. Tab/Shift+Tab select completion entries first while the menu is visible; use Ctrl+L/Ctrl+H for dedicated snippet navigation. Type a trigger and press Ctrl+L, select its **Snippet** completion entry, or use Tab when completion is closed.

| Trigger | Expansion |
| --- | --- |
| `tys`, `struct` | Struct name, first field name/type, then remaining body |
| `meth` | Editable receiver name/type, method name/parameters, return choice, body |
| `func` | Function name/parameters, return choice, body |
| `fmain`, `main` | Bare `func main()` with cursor in the body |
| `iferr` | Error check |
| `test` | Go test function |
| `forr` | Range loop |
| `iface` | Interface declaration |
| `switch` | Switch statement |
| `errf` | Wrapped `fmt.Errorf` expression |

In `func` and `meth`, Alt+N cycles `(T1, error)` → `error` → no return type; Alt+P cycles backward. Make the selection while the return choice is active. Edit the placeholder types and finish a valid body before formatting.

Snippet jumps act on **active placeholders**, including those inserted by gopls completion. They do not jump between arbitrary existing call arguments. The function template's parameters are a single field, so commas typed within it do not create new placeholders. Outside an available expansion/jump or active choice, the keys fall back normally. In Normal mode Ctrl+H/Ctrl+L still change windows. Some terminals send Backspace as Ctrl+H or intercept Alt combinations; adjust terminal/tmux passthrough, or use Tab/Shift+Tab with completion closed for jumps.

Edit `config/lua/custom/snippets.lua` in the repository or `~/.config/nvim-go/lua/custom/snippets.lua` in the default installed profile. Save the installed module and run `:GoSnippetsReload`, then expand a fresh snippet. Reinstalling copies the repository configuration, so preserve lasting customizations there too.

## Problems, tests, coverage, and running

| Action | Shortcut | Explicit command |
| --- | --- | --- |
| Problems panel | `Space x x` | `:Trouble diagnostics toggle` |
| Current line's diagnostic | `Space x d` | — |
| Next / previous diagnostic | `Space x n` / `Space x p` | — |
| Run nearest top-level test | `Space t t` | `:GoTest nearest` |
| Run tests declared in current file | `Space t f` | `:GoTest file` |
| Run current package tests | `Space t p` | `:GoTest package` |
| Run current module tests | `Space t a` | `:GoTest all` |
| Rerun exact previous test command | `Space t r` | `:GoTestLast` |
| Show/hide Go output | `Space t o` | `:GoOutput` |
| Run module coverage | `Space t c` | `:GoCoverage` |
| Clear coverage marks | `Space t C` | `:GoCoverageClear` |
| Stop Go run/test/tidy task | `Space t s` | `:GoStop` |
| Run current package | `Space r r` | `:GoRun` |
| Run package with prompted arguments | `Space r a` | `:GoRun arg1 arg2` |
| Open styled failure locations | `Space x q` | `:copen` / Quicker |
| Next / previous failure | — | `:cnext` / `:cprevious` |

`all` is the active module, even inside a `go.work` workspace. The file scope compiles the entire package while selecting that file's test functions. Run/test/debug actions save modified named Go buffers in the active module first.

## Debugging

| Action | Primary shortcut | Alternative |
| --- | --- | --- |
| Start or continue | `F5` | `Space d c` |
| Toggle breakpoint | `F9` | `Space d b` |
| Set conditional breakpoint | `Space d B` | — |
| Step over | `F10` | `Space d o` |
| Step into | `F11` | `Space d i` |
| Step out | `Space d O` | `Shift+F11` |
| Pause | `Space d p` | — |
| Stop session | `Space d t` | — |
| Debug nearest test | `Space d r` | `:GoDebugTest` |
| Debug last test again | `Space d R` | `:GoDebugLastTest` |
| Toggle debug panels | `Space d u` | — |
| Evaluate word or selection | `Space d e` | Normal / Visual |

In Scopes, `Enter` expands a value. In Watches, `i` begins a new expression, `Enter` adds it, `e` edits it, and `d` removes it. Stop the current session before choosing a different launch configuration. Debug output stays visible until you hide the panels.

The function keys need to reach the terminal; on some keyboards this means using `Fn`. Leader shortcuts provide the same actions.

## Git, appearance, and help

| Action | Shortcut |
| --- | --- |
| Preview changed hunk | `Space g h` |
| Blame current line | `Space g b` |
| Stage current hunk | `Space g s` |
| Reset hunk, with confirmation | `Space g u` |
| Next / previous changed hunk | `Space g n` / `Space g p` |
| Profile health check | `Space u i` or `:GoIdeHealth` |
| Edit settings | `Space u s` or `:GoIdeSettings` |
| Open getting-started guide | `Space u h` or `:GoIdeGuide` |
| Toggle relative line numbers | `Space u n` |
| Toggle symbol breadcrumbs | `Space u b` or `:GoIdeBreadcrumbs` |
| Plugin manager | `:Lazy` |
| Recent messages/errors | `:messages` |

## Terminal and clipboard

`Space` followed by backtick toggles the project shell. In terminal input mode, `Esc` twice returns control to Neovim; `i` resumes shell input. The native sequence `Ctrl+\`, then `Ctrl+N` also leaves terminal input mode. Use `Ctrl+C` while in terminal input mode to interrupt the foreground shell command.

The system clipboard is integrated through `unnamedplus` when a provider such as `wl-clipboard` is available. Select text with `v` or `V`, then `y` to copy; use `p` to paste in Normal mode. Your terminal's paste shortcut can also insert text. `Ctrl+C` retains its Neovim/shell meaning rather than acting as the editor's Copy shortcut.

For extended Ctrl/Shift combinations, support depends on the terminal and any tmux layer. If a chord fails, use its leader alternative. `Ctrl+P` opens files in Normal mode and navigates completion in Insert mode; `Ctrl+K` changes windows in Normal mode and shows signature help in Insert mode.
