# Repository Guidelines

## Project Structure & Module Organization
This plugin follows the standard Neovim layout. Runtime modules live in `lua/stay/`, with `init.lua` managing buffer heuristics, `view.lua` handling mkview/loadview, and `viewdir.lua` cleaning persisted files. The autocommand bootstrapper sits in `plugin/stay.lua`. End-user help is authored in `doc/nvim-stay.txt`, and `example_config.lua` demonstrates recommended settings. There is currently no dedicated test directory; keep new source under `lua/stay/` and mirror the existing naming to keep the runtime path clean.

## Build, Test, and Development Commands
There is no build step. For quick smoke tests, run `nvim --headless -u NORC "+set rtp+=." "+lua require('stay')" +qa` to ensure the module loads from the repo. Regenerate help tags after changing docs with `nvim --headless -u NORC "+set rtp+=." +"helptags doc" +qa`. When iterating, launch Neovim with `nvim -u example_config.lua` and interactively exercise buffer opens/closes to observe persisted state.

## Coding Style & Naming Conventions
Lua files use two-space indentation, no tabs, and trim trailing whitespace. Module tables are exported through `return M`, with internal helpers in `local` scope. Function and variable names use lower_snake_case (`is_temp_file`, `make_view`). Prefer concise inline comments beginning with `--` for non-obvious logic; avoid block comments unless documenting public APIs. Keep API-facing strings plain ASCII and follow Neovim Lua style (access through `vim.api`, `vim.fn`, `vim.bo`).

## Testing Guidelines
Automated tests are not in place yet; rely on reproducible manual checks. Validate persistence by: 1) opening a tracked file, 2) creating folds or moving the cursor, 3) leaving and re-entering the buffer/window, and 4) restarting Neovim if relevant. Capture observations with `:messages` when debugging. If adding complex logic, consider temporary headless scripts under `scratch/` (gitignored) to exercise edge cases and describe the scenario in the PR.

## Commit & Pull Request Guidelines
Recent commits follow an imperative mood summary (`Add example config`, `Rename plugin ...`). Keep messages short (≤72 characters) with additional detail in the body when needed. Pull requests should explain the problem, outline the solution, list manual test steps, and link related issues. Update `doc/nvim-stay.txt` and the README whenever behavior or public commands change, and include screenshots or terminal recordings only when UI output meaningfully changes.

## Documentation & Helpfiles
When editing help text, match Vim help formatting (`*tags*`, indenting with tabs where required) and regenerate tags before submitting. Ensure command names and option defaults remain synchronized between `doc/nvim-stay.txt`, `README.md`, and code comments so users and plugin hosts receive consistent guidance.
