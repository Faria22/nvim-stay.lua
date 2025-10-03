# nvim-stay.lua Translation Gaps

## Overview
This report compares the current Lua port with the original [`vim-stay`](https://github.com/zhimsel/vim-stay) plugin (commit `HEAD` as of 2024-05-14) and documents missing features or behavioural regressions that block parity. References use repository-relative paths and 1-based line numbers.

## Broken Behaviour

### 1. View saves report success even when `mkview` fails
- Location: `lua/stay/view.lua:59`
- Issue: The port executes `silent! mkview` inside a `pcall`. When the view directory is unwritable (`E190`, `E166`, `E212`, ...), Neovim sets `vim.v.errmsg` but `pcall` still succeeds, so `view.make` returns `1` and the error is dropped by `stay.handle_error`.
- Original behaviour: `autoload/stay/view.vim` uses `silent mkview` (no bang) and catches specific exceptions, returning `-1` so the failure propagates.
- Impact: View sessions silently fail to persist; users never see an error message and the buffer state is lost across windows/sessions.
- Repro: `XDG_STATE_HOME=$PWD/tmpstate nvim --headless -u NORC "+set viewdir=/var/empty" "+edit $PWD/teststay.txt" "+lua package.path=package.path..';$PWD/lua/?.lua;$PWD/lua/?/init.lua'; local view=require('stay.view'); local stay=require('stay'); print(view.make(vim.api.nvim_get_current_win(), stay.config.disabled_viewoptions)); print(vim.v.errmsg)` → returns `1` plus `E190`.
- Fix: Drop the `!` so failures raise, trap them, and surface the error text as in the Vimscript implementation.

### 2. Loaded view detection never succeeds
- Location: `lua/stay/view.lua:117-134`
- Issue: Success is inferred by reading `b:stay_loaded_view`. The port never sets this buffer variable, so `did_load_view` is always `false`.
- Original behaviour: `autoload/stay/view.vim` attaches a one-shot `SourcePre` autocommand to capture the path of the file read by `:loadview`, sets `b:stay_loaded_view`, and restores any prior value if loading fails.
- Impact:
  - `view.load` returns `0` even when the view file exists.
  - `SessionLoadPost` is never triggered (code gated by `did_load_view`).
  - The documented integration API (`b:stay_loaded_view`) never exposes the loaded path.
- Fix: Replicate the `SourcePre` hook (via `nvim_create_autocmd`) to set `b:stay_loaded_view`, and preserve/restores previous values on failure.

### 3. `SessionLoadPost` runs with `<nomodeline>`
- Location: `lua/stay/view.lua:6-16` & `:123-134`
- Issue: `doautocmd` helpers always append `<nomodeline>`. The Vimscript plugin deliberately avoids `<nomodeline>` for the final `SessionLoadPost` so modelines in view files execute.
- Impact: Any modelines or autocommands that rely on `SessionLoadPost` modeline evaluation no longer run, diverging from the original behaviour.
- Fix: Special-case `SessionLoadPost` (or parameterise the helper) to run without `<nomodeline>`.

### 4. `backupskip` parsing breaks on escaped commas
- Location: `lua/stay/init.lua:109-124`
- Issue: `backupskip:gmatch('[^,]+')` splits on every comma, even escaped `\,`. The subsequent unescape happens too late, leaving truncated patterns like `"foo\\"`.
- Impact: Paths that should be recognised as temporary (e.g. `set backupskip=foo\,bar/*`) fall through `M.is_temp_file`, so transient files are persisted.
- Repro: `vim.o.backupskip='foo\\,bar/*'; stay.is_temp_file('foo,bar/example.txt')` → `false` (expected `true`).
- Fix: Mirror `stay#istemp` by respecting escaped delimiters (e.g. use the Vimscript split pattern or delegate to `vim.fn.split(backupskip, '\\@<!\\%(\\\\\\)*,')`).

### 5. `StayReload` cannot reload the plugin
- Location: `plugin/stay.lua:152-167`
- Issues:
  1. `StayReload!` attempts to `source stdpath('config') .. '/plugin/stay.lua'`, which does not exist for package-managed installs.
  2. `StayReload` (without bang) just prints `"Integrations reloaded"`; no integrations are discovered or initialised.
- Original behaviour: `plugin/stay.vim` re-runs its internal `Setup` function. The bang path clears autocommands, re-establishes defaults, and reloads integrations; the non-bang path discovers newly added integration scripts under `autoload/stay/integrate/`.
- Impact: Users cannot reload configuration, and documentation promises about integration hot-loading are unfulfilled.
- Fix: Recreate the original control flow—wrap setup logic in a reusable function, re-run it, and implement integration scanning.

### 6. Integration discovery/removal is missing entirely
- Evidence: The Lua port contains no equivalent of `stay#shim#globpath` + `stay#integrate#{name}#setup`. `IMPLEMENTATION.md` and `doc/nvim-stay.txt` still advertise the integration API.
- Impact: Any third-party integrations under `autoload/stay/integrate/` are ignored. The `StayReload` command has nothing to reload.
- Fix: Port the runtimepath scan (`vim.api.nvim_get_runtime_file('autoload/stay/integrate/*.lua', true)`) and call a conventional Lua entry point per integration.

### 7. Autocommands are no longer `nested`
- Location: `plugin/stay.lua:98-139`
- Issue: The original autocommands were declared with `nested`, allowing `:loadview`/`:mkview` side-effects to trigger other autocmds. The Lua port omits `nested` so Neovim prevents recursive autocommand execution inside these callbacks.
- Impact: Workflows that relied on nested autocmds (e.g. integrations reacting to `BufWinLeave` triggered by `:mkview`) break.
- Fix: Pass `nested = true` in each `nvim_create_autocmd` definition.

## Summary
At least seven parity gaps remain between the Lua port and the Vimscript original. The most severe (Items 1 & 2) prevent reliable persistence altogether. Items 5 & 6 remove the documented integration story, while Items 3, 4, and 7 silently change long-standing behaviours. Restoring these pieces should be prioritised before presenting this port as a drop-in replacement.
