# Project-specific Go IDE configuration

Put an optional `.nvim-go.json` in the Go module/workspace root when a project
needs build tags, stable test flags, or environment variables.

Example:

```json
{
  "build_tags": ["integration", "linux"],
  "go_test_args": ["-timeout=90s"],
  "go_env": {
    "CGO_ENABLED": "1",
    "APP_ENV": "test"
  }
}
```

The file is deliberately simple and contains only strings, string arrays and a
string-like environment map. No Lua from the repository is executed.

## What consumes it

| Setting | gopls | go test / race | benchmarks | coverage | go run | Delve |
| --- | --- | --- | --- | --- | --- | --- |
| `build_tags` | yes | yes | yes | yes | yes | yes |
| `go_test_args` | — | yes | yes | yes | — | — |
| `go_env` | yes | yes | yes | yes | yes | yes |

After editing the file, run:

```vim
:GoProjectReload
```

That clears the project-config cache and restarts gopls so language analysis and
execution agree again.

## Workspaces

The IDE stores recent-project metadata under the isolated Neovim state
directory, not in your repository. A workspace remembers:

- open project files;
- editor split layout;
- cursor positions;
- the active file;
- Explorer visibility;
- minimap and breadcrumb state.

Use:

```text
Space p p   switch recent project
Space p s   save current workspace
Space p r   restore current workspace
```

The workspace file is local editor state. It is not intended for Git.

## Build tags

`build_tags` becomes a single Go `-tags=...` build flag and is passed to both
gopls and commands that compile project code. This prevents the common mismatch
where completion/type checking sees different files from tests or debugging.

## Test arguments

`go_test_args` is appended to normal tests, race tests, benchmarks and
coverage. Keep it to stable project-wide flags such as timeout or count policy;
use the integrated terminal for one-off experiments.

## Environment

`go_env` is merged over the environment inherited by `nvim-go`. Avoid
committing secrets. Use your shell, secret manager or another local mechanism
for credentials.
