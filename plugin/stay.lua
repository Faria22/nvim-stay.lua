-- nvim-stay.lua: Main plugin entry point
-- A Lua implementation of vim-stay for Neovim

-- Check if plugin should load
if vim.g.loaded_stay_lua then
  return
end

-- Check for required features
if vim.fn.has('nvim') == 0 then
  return
end

vim.g.loaded_stay_lua = 1

local stay = require('stay')
local view = require('stay.view')
local viewdir = require('stay.viewdir')

local loaded_integrations = {}

local function stringify_error(err)
  if type(err) == 'string' then
    return err
  end
  if type(err) == 'table' and err.msg then
    return err.msg
  end
  return tostring(err)
end

local function load_config(force)
  if force then
    stay.reset_config()
  end

  if vim.g.volatile_ftypes ~= nil then
    stay.config.volatile_ftypes = stay.normalize_list(vim.g.volatile_ftypes)
  end
  vim.g.volatile_ftypes = stay.config.volatile_ftypes

  if vim.g.stay_disabled_viewoptions ~= nil then
    stay.config.disabled_viewoptions = stay.normalize_list(vim.g.stay_disabled_viewoptions)
  end
  vim.g.stay_disabled_viewoptions = stay.config.disabled_viewoptions

  if vim.g.stay_verbosity ~= nil then
    stay.config.verbosity = vim.g.stay_verbosity
  else
    vim.g.stay_verbosity = stay.config.verbosity
  end
end

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
  local result = view.make(winid, stay.config.disabled_viewoptions)
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

local function resolve_win(args)
  if args and args.win and args.win ~= 0 then
    return args.win
  end
  return vim.api.nvim_get_current_win()
end

local function define_autocommands()
  local augroup = vim.api.nvim_create_augroup('stay', { clear = true })

  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = augroup,
    pattern = '*',
    nested = true,
    callback = function(args)
      local bufnr = args.buf
      local winid = resolve_win(args)
      load_view(bufnr, winid)
    end,
  })

  vim.api.nvim_create_autocmd('WinLeave', {
    group = augroup,
    pattern = '*',
    nested = true,
    callback = function(args)
      local bufnr = args.buf
      local winid = resolve_win(args)
      make_view(2, bufnr, winid)
    end,
  })

  vim.api.nvim_create_autocmd('BufWinLeave', {
    group = augroup,
    pattern = '*',
    nested = true,
    callback = function(args)
      local bufnr = args.buf
      local winid = resolve_win(args)
      make_view(3, bufnr, winid)
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufFilePost' }, {
    group = augroup,
    pattern = '*',
    nested = true,
    callback = function(args)
      local bufnr = args.buf
      local winid = resolve_win(args)
      make_view(1, bufnr, winid)
    end,
  })
end

local function load_lua_integration(name, force)
  local module_name = 'stay.integrate.' .. name:gsub('/', '.')
  if force then
    package.loaded[module_name] = nil
  end

  local ok, mod = pcall(require, module_name)
  if not ok then
    stay.handle_error(-1, 'Skipped nvim-stay integration for ' .. name .. ' due to error: ' .. stringify_error(mod))
    return false
  end

  local setup_fn = nil
  if type(mod) == 'function' then
    setup_fn = mod
  elseif type(mod) == 'table' then
    setup_fn = mod.setup or mod.configure
  end

  if type(setup_fn) ~= 'function' then
    stay.handle_error(0, 'No nvim-stay integration setup function found for ' .. name)
    return false
  end

  local success, err = pcall(setup_fn)
  if not success then
    stay.handle_error(-1, 'Skipped nvim-stay integration for ' .. name .. ' due to error: ' .. stringify_error(err))
    return false
  end

  return true
end

local function load_vim_integration(name)
  local runtime_cmd = string.format('silent! runtime! autoload/stay/integrate/%s.vim', name)
  pcall(vim.cmd, runtime_cmd)

  local funcname = string.format('stay#integrate#%s#setup', name)
  if vim.fn.exists('*' .. funcname) == 0 then
    stay.handle_error(0, 'No nvim-stay integration setup function found for ' .. name)
    return false
  end

  local success, err = pcall(vim.api.nvim_call_function, funcname, {})

  if not success then
    stay.handle_error(-1, 'Skipped nvim-stay integration for ' .. name .. ' due to error: ' .. stringify_error(err))
    return false
  end

  return true
end

local function load_integrations(force)
  if force then
    loaded_integrations = {}
  end

  local seen = {}
  local ordered = {}

  for _, file in ipairs(vim.api.nvim_get_runtime_file('lua/stay/integrate/*.lua', true)) do
    local name = file:match('stay/integrate/(.+)%.lua$')
    if name and not seen[name] then
      table.insert(ordered, { kind = 'lua', name = name })
      seen[name] = true
    end
  end

  for _, file in ipairs(vim.api.nvim_get_runtime_file('autoload/stay/integrate/*.vim', true)) do
    local name = file:match('integrate/(.+)%.vim$')
    if name and not seen[name] then
      table.insert(ordered, { kind = 'vim', name = name })
      seen[name] = true
    end
  end

  for _, item in ipairs(ordered) do
    if not loaded_integrations[item.name] then
      local ok = false
      if item.kind == 'lua' then
        ok = load_lua_integration(item.name, force)
      else
        ok = load_vim_integration(item.name)
      end
      if ok then
        loaded_integrations[item.name] = true
      end
    end
  end
end

local setup_core

local function define_commands(force)
  if force then
    pcall(vim.api.nvim_del_user_command, 'CleanViewdir')
    pcall(vim.api.nvim_del_user_command, 'StayReload')
  end

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
    if opts.bang then
      setup_core(true)
    else
      load_integrations(false)
    end
  end, {
    bang = true,
    nargs = 0,
    desc = 'Reload nvim-stay integrations',
  })
end

setup_core = function(force)
  load_config(force)
  define_autocommands()
  define_commands(force)
  load_integrations(true)
end

setup_core(true)
