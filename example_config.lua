-- Example configuration for vim-stay.lua
-- Add this to your init.lua or init.vim

-- Recommended viewoptions settings
vim.opt.viewoptions = {'cursor', 'folds', 'slash', 'unix'}

-- Or at minimum, remove the 'options' flag to avoid issues
-- vim.opt.viewoptions:remove('options')

-- Optional: Customize volatile file types
-- These file types will never have their view persisted
-- vim.g.volatile_ftypes = {
--   'gitcommit', 'gitrebase', 'gitsendmail',
--   'hgcommit', 'svn', 'cvs', 'bzr',
--   'myfiletype',  -- Add your own file types here
-- }

-- Optional: Set error message verbosity
-- -1 = no messages, 0 = important errors only (default), 1 = all errors
-- vim.g.stay_verbosity = 0

-- Optional: Set a custom viewdir location
-- vim.opt.viewdir = vim.fn.stdpath('data') .. '/view'

-- That's it! vim-stay.lua will work automatically in the background
