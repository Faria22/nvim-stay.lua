# Changelog

All notable changes to vim-stay.lua will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-10-01

### Added
- Initial release of vim-stay.lua
- Lua implementation of vim-stay plugin functionality
- Automatic view session creation and restoration
- Smart heuristics for detecting persistent buffers
- Configuration options:
  - `g:volatile_ftypes` - list of file types to never persist
  - `g:stay_verbosity` - error message verbosity control
- User commands:
  - `:CleanViewdir[!] [days]` - clean up view directory
  - `:StayReload[!]` - reload plugin/integrations
- Buffer variables for integration:
  - `b:stay_ignore` - mark buffer as non-persistent
  - `b:stay_atpos` - set custom cursor position after view load
  - `b:stay_loaded_view` - path to loaded view file
- User autocommand events:
  - `BufStayLoadPre` - before loading view
  - `BufStayLoadPost` - after loading view
  - `BufStaySavePre` - before saving view
  - `BufStaySavePost` - after saving view
- Comprehensive documentation in `:help vim-stay-lua`
- Support for both Neovim and Vim 8.0+ with Lua support

### Features from Original vim-stay
- ✅ Automatic view creation/restoration on buffer events
- ✅ Smart buffer persistence detection
- ✅ Temporary file filtering via backupskip
- ✅ Volatile file type filtering
- ✅ Preview and diff window exclusion
- ✅ View directory management
- ✅ Plugin integration API
- ✅ Error handling and verbosity control

### Performance Benefits
- Faster execution due to Lua implementation
- Native integration with Neovim's Lua API
- Reduced overhead compared to VimScript

[1.0.0]: https://github.com/Faria22/vim-stay.lua/releases/tag/v1.0.0
