# nvim-stay.lua

Lua rewrite of [vim-stay](https://github.com/zhimsel/vim-stay) for Neovim. It keeps cursor, folds, and related view state intact as you jump between buffers or restart Neovim—no manual commands required.

## Install

### lazy.nvim

```lua
{
  'Faria22/nvim-stay.lua',
  event = 'BufReadPre',
  config = function()
    require('stay').setup()
  end,
}
```

### packer.nvim

```lua
use { 'Faria22/nvim-stay.lua' }
```

With other plugin managers, add the repository to your runtime path and the plugin activates automatically.

## Usage

Just install the plugin. It saves a view when you leave a buffer and restores it when you return. Commit messages, scratch buffers, and other volatile content are skipped by default.

### Commands

- `:CleanViewdir[!] [days]` removes saved view files (optionally keeping entries newer than `days`).
- `:StayReload[!]` reloads the plugin; append `!` for a full reset.

## Optional Configuration

Defaults match the original plugin. Tweak behaviour through Lua if needed:

```lua
require('stay').setup({
  disabled_viewoptions = {'folds'},  -- stop tracking specific view options
  verbosity = 0,                     -- -1 = silent, 0 = errors, 1 = verbose
})

vim.g.volatile_ftypes = { 'gitcommit', 'gitrebase' }  -- extend or replace skip list
```

Per-buffer flags from vim-stay still work:

- `b:stay_ignore = 1` to skip a buffer entirely.
- `b:stay_atpos = {line, col}` to reuse a position chosen by another tool.

User autocommands are emitted on load/save (`BufStayLoadPre/Post`, `BufStaySavePre/Post`) for integrations that need hooks.

## Docs

See `:help nvim-stay` for the full reference, including heuristics and maintenance tips. Run `:helptags doc` after updating the plugin locally.

## License

MIT. See `LICENSE` for details.
