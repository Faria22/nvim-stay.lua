-- vim-stay.lua: Main plugin entry point
-- A Lua implementation of vim-stay

-- Check if plugin should load
if vim.g.loaded_stay_lua then
  return
end

-- Check for required features
if vim.fn.has('nvim') == 0 and vim.fn.has('vim') == 0 then
  return
end

vim.g.loaded_stay_lua = 1

local stay = require('stay')
local view = require('stay.view')
local viewdir = require('stay.viewdir')

-- Initialize configuration from global variables if they exist
if vim.g.volatile_ftypes then
  stay.config.volatile_ftypes = vim.g.volatile_ftypes
else
  vim.g.volatile_ftypes = stay.config.volatile_ftypes
end

if vim.g.stay_verbosity ~= nil then
  stay.config.verbosity = vim.g.stay_verbosity
else
  vim.g.stay_verbosity = stay.config.verbosity
end

-- Track when views were last saved to avoid redundant saves
local last_save_time = {}

-- Make view session for buffer
local function make_view(stage, bufnr, winid)
  -- Don't create view if a recent save was done for a lower stage
  local state = stay.get_buffer_state(bufnr)
  if state.left and stage > 1 then
    local prev_stage = state.left[stage - 1]
    if prev_stage and os.time() - prev_stage <= 1 then
      return 0
    end
  end
  
  -- Check if we should persist this buffer
  if vim.fn.pumvisible() == 1 or
     not stay.is_view_window(winid) or
     not stay.is_persistent(bufnr, stay.config.volatile_ftypes) then
    return 0
  end
  
  -- Create the view
  local result = view.make(winid)
  stay.handle_error(result, vim.v.errmsg)
  
  -- Track save time
  if result == 1 then
    if not state.left then
      state.left = {}
    end
    state.left[stage] = os.time()
  end
  
  return result
end

-- Load view session for buffer
local function load_view(bufnr, winid)
  -- Don't load during session load or if popup menu is visible
  if vim.g.SessionLoad or
     vim.fn.pumvisible() == 1 or
     not stay.is_view_window(winid) or
     not stay.is_persistent(bufnr, stay.config.volatile_ftypes) then
    return 0
  end
  
  -- Load the view
  local result = view.load(winid)
  stay.handle_error(result, vim.v.errmsg)
  
  return result
end

-- Set up autocommands
local augroup = vim.api.nvim_create_augroup('stay', { clear = true })

-- Load view when buffer becomes visible in a window
vim.api.nvim_create_autocmd('BufWinEnter', {
  group = augroup,
  pattern = '*',
  callback = function(args)
    local bufnr = args.buf
    local winid = vim.api.nvim_get_current_win()
    load_view(bufnr, winid)
  end,
})

-- Save view when leaving a window
vim.api.nvim_create_autocmd('WinLeave', {
  group = augroup,
  pattern = '*',
  callback = function(args)
    local bufnr = args.buf
    local winid = vim.api.nvim_get_current_win()
    make_view(2, bufnr, winid)
  end,
})

-- Save view when buffer is hidden
vim.api.nvim_create_autocmd('BufWinLeave', {
  group = augroup,
  pattern = '*',
  callback = function(args)
    local bufnr = args.buf
    local winid = vim.api.nvim_get_current_win()
    make_view(3, bufnr, winid)
  end,
})

-- Save view after writing or renaming buffer
vim.api.nvim_create_autocmd({'BufWritePost', 'BufFilePost'}, {
  group = augroup,
  pattern = '*',
  callback = function(args)
    local bufnr = args.buf
    local winid = vim.api.nvim_get_current_win()
    make_view(1, bufnr, winid)
  end,
})

-- Define user commands
vim.api.nvim_create_user_command('CleanViewdir', function(opts)
  local bang = opts.bang
  local keepdays = tonumber(opts.args) or 0
  viewdir.clean(bang, keepdays)
end, {
  bang = true,
  nargs = '?',
  desc = 'Remove view session files from viewdir',
})

vim.api.nvim_create_user_command('StayReload', function(opts)
  local bang = opts.bang
  if bang then
    -- Full reload: re-source the plugin
    vim.g.loaded_stay_lua = nil
    vim.cmd('source ' .. vim.fn.stdpath('config') .. '/plugin/stay.lua')
  else
    -- Just reload integrations (if any exist)
    -- This is a placeholder for integration support
    print('Integrations reloaded')
  end
end, {
  bang = true,
  nargs = 0,
  desc = 'Reload vim-stay integrations',
})
