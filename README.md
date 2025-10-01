# nvim-stay.lua

Make Neovim persist editing state without fuss, written in Lua.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

*nvim-stay.lua* is a Lua implementation of the excellent [vim-stay](https://github.com/zhimsel/vim-stay) plugin. It adds automated view session creation and restoration whenever editing a buffer, across Neovim sessions and window life cycles. It also alleviates Neovim's tendency to lose view state when cycling through buffers (via `argdo`, `bufdo` et al.).

If you have wished Neovim would be smarter about keeping your editing state, *nvim-stay.lua* is for you.

## Features

- 🔄 **Automatic persistence**: Cursor position, folds, and other view settings are automatically saved and restored
- 🧠 **Smart heuristics**: Intelligently detects which buffers should be persisted and which should not
- ⚡ **Performance optimized**: Written in Lua for speed and efficiency
- 🔌 **Plugin friendly**: Integrates well with other plugins through autocommand events
- 🛡️ **Safe by default**: Won't persist temporary files, commit messages, or special buffers

## Installation

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'Faria22/nvim-stay.lua'
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use 'Faria22/nvim-stay.lua'
```

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'Faria22/nvim-stay.lua',
  event = 'BufReadPre',
}
```

### Manual Installation

Clone the repository into your `packpath`:

```bash
# For Neovim
git clone https://github.com/Faria22/nvim-stay.lua \
  ~/.local/share/nvim/site/pack/plugins/start/nvim-stay.lua
```

Then run `:helptags ALL` to generate help tags.

## Configuration

### Recommended Settings

Add this to your `init.vim` or `init.lua`:

```vim
" Recommended viewoptions settings
set viewoptions=cursor,folds,slash,unix

" Or at minimum, remove the 'options' flag
set viewoptions-=options
```

In Lua:
```lua
-- Recommended viewoptions settings
vim.opt.viewoptions = {'cursor', 'folds', 'slash', 'unix'}

-- Or at minimum
vim.opt.viewoptions:remove('options')
```

### Customizing Volatile File Types

Some file types should never be persisted (e.g., git commit messages). You can customize this list:

```lua
-- Add to the default list
local defaults = vim.g.volatile_ftypes or {}
table.insert(defaults, 'myfiletype')
vim.g.volatile_ftypes = defaults

-- Or replace entirely
vim.g.volatile_ftypes = {
  'gitcommit', 'gitrebase', 
  'hgcommit', 'svn', 'cvs',
}
```

### Disabling Specific View Options

To stop persisting particular view attributes (such as folds), provide a list of tokens from `:set viewoptions?`:

```lua
-- Stop tracking folds when saving views
vim.g.stay_disabled_viewoptions = {'folds'}

-- You can also disable multiple entries
vim.g.stay_disabled_viewoptions = {'folds', 'cursor'}
```

### Error Verbosity

Control how verbose error messages are:

```lua
vim.g.stay_verbosity = 0  -- Important errors only (default)
vim.g.stay_verbosity = 1  -- All errors
vim.g.stay_verbosity = -1 -- No error messages
```

## Usage

Once installed and configured, *vim-stay.lua* works automatically in the background. No manual intervention is required.

### Commands

#### `:CleanViewdir[!] [days]`

Remove saved view session files from `viewdir`.

```vim
:CleanViewdir      " Remove all view files (with confirmation)
:CleanViewdir!     " Remove all view files (no confirmation)
:CleanViewdir 30   " Keep files from last 30 days
```

#### `:StayReload[!]`

Reload integrations or the entire plugin.

```vim
:StayReload   " Reload integrations
:StayReload!  " Full plugin reload
```

### Integration with Other Plugins

#### Ignoring Specific Buffers

To prevent nvim-stay.lua from persisting a specific buffer:

```vim
let b:stay_ignore = 1
```

#### Setting Custom Position

To make nvim-stay.lua respect a position set by another plugin:

```vim
let b:stay_atpos = [line, column]
```

#### Autocommand Events

nvim-stay.lua triggers these User autocommand events:

- `BufStayLoadPre` - Before loading a view session
- `BufStayLoadPost` - After loading a view session
- `BufStaySavePre` - Before saving a view session
- `BufStaySavePost` - After saving a view session

Example:
```vim
autocmd User BufStayLoadPost lua print("View restored!")
```

## Troubleshooting

### Cursor position not persisted

Make sure `cursor` is in your `viewoptions`:
```vim
set viewoptions+=cursor
```

### Folds not persisted

Make sure `folds` is in your `viewoptions`:
```vim
set viewoptions+=folds
```

### View directory is cluttered

Clean it up periodically:
```vim
:CleanViewdir 30  " Keep last 30 days
```

### More Help

See `:help nvim-stay` for complete documentation.

## Differences from Original vim-stay

*nvim-stay.lua* is implemented in Lua for better performance and native integration with Neovim, but maintains API compatibility with the original vim-stay:

- ✅ Same core functionality
- ✅ Same configuration variables
- ✅ Same commands
- ✅ Same autocommand events
- ✅ Compatible buffer variables

## Why Lua?

- **Performance**: Lua code runs faster than VimScript
- **Native support**: First-class support in Neovim
- **Modern**: Cleaner, more maintainable codebase
- **Future-proof**: Better positioned for future Neovim development

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- Original [vim-stay](https://github.com/zhimsel/vim-stay) by Martin Kopischke and Zach Himsel
- This Lua implementation inspired by the excellent design of the original

## Related Projects

- [vim-stay](https://github.com/zhimsel/vim-stay) - The original VimScript implementation
- [vim-fetch](https://github.com/kopischke/vim-fetch) - Handle line and column position specs in file paths
