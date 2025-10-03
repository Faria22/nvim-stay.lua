-- nvim-stay.lua: Core persistence logic
-- Maintainer: Based on vim-stay by Martin Kopischke and Zach Himsel
-- License: MIT

local M = {}

local DEFAULT_CONFIG -- forward definition after config initialisation

local tbl_islist = vim.tbl_islist or function(t)
  local count = 0
  for k, _ in pairs(t) do
    if type(k) ~= 'number' then
      return false
    end
    count = count + 1
  end
  for i = 1, count do
    if t[i] == nil then
      return false
    end
  end
  return true
end

local function normalize_list(value)
  if value == nil then
    return {}
  end

  if type(value) ~= 'table' then
    if value ~= '' then
      return { value }
    end
    return {}
  end

  local list = {}

  if tbl_islist(value) then
    for _, item in ipairs(value) do
      if type(item) == 'string' and item ~= '' then
        table.insert(list, item)
      end
    end
  else
    for key, enabled in pairs(value) do
      if enabled and type(key) == 'string' and key ~= '' then
        table.insert(list, key)
      end
    end
  end

  return list
end

-- Default configuration
M.config = {
  -- File types that should never be persisted
  volatile_ftypes = {
    'gitcommit', 'gitrebase', 'gitsendmail',
    'hgcommit', 'hgcommitmsg', 'hgstatus', 'hglog', 'hglog-changelog', 'hglog-compact',
    'svn', 'cvs', 'cvsrc', 'bzr',
  },
  -- View options that should be excluded when creating view sessions
  disabled_viewoptions = {},
  -- Verbosity of error messages
  -- -1: no messages, 0: important errors only, 1: all errors
  verbosity = 0,
}

DEFAULT_CONFIG = vim.deepcopy(M.config)

function M.reset_config()
  M.config = vim.deepcopy(DEFAULT_CONFIG)
end

function M.setup(opts)
  if type(opts) ~= 'table' then
    return
  end

  if opts.volatile_ftypes ~= nil then
    M.config.volatile_ftypes = normalize_list(opts.volatile_ftypes)
    vim.g.volatile_ftypes = M.config.volatile_ftypes
  end

  if opts.disabled_viewoptions ~= nil then
    M.config.disabled_viewoptions = normalize_list(opts.disabled_viewoptions)
    vim.g.stay_disabled_viewoptions = M.config.disabled_viewoptions
  end

  if opts.verbosity ~= nil then
    M.config.verbosity = opts.verbosity
    vim.g.stay_verbosity = opts.verbosity
  end
end

M.normalize_list = normalize_list

-- Buffer state storage
local buffer_states = {}

-- Cached backupskip patterns
local backupskip_cache = {
  option = nil,
  items = {},
}

local function parse_backupskip(option)
  if not option or option == '' then
    return {}
  end

  local items = {}
  local chunk = {}
  local i = 1
  local len = #option

  local function push_chunk()
    if #chunk > 0 then
      table.insert(items, table.concat(chunk))
    end
    chunk = {}
  end

  while i <= len do
    local ch = option:sub(i, i)
    if ch == '\\' then
      local next_char = option:sub(i + 1, i + 1)
      if next_char == ',' or next_char == ' ' then
        table.insert(chunk, next_char)
        i = i + 2
      elseif next_char ~= '' then
        table.insert(chunk, '\\' .. next_char)
        i = i + 2
      else
        table.insert(chunk, '\\')
        i = i + 1
      end
    elseif ch == ',' then
      push_chunk()
      i = i + 1
    else
      table.insert(chunk, ch)
      i = i + 1
    end
  end

  push_chunk()

  return items
end

local function get_backupskip_items()
  local option = vim.o.backupskip or ''
  if backupskip_cache.option ~= option then
    backupskip_cache.option = option
    backupskip_cache.items = parse_backupskip(option)
  end
  return backupskip_cache.items
end

-- Get or create buffer state
function M.get_buffer_state(bufnr)
  if not buffer_states[bufnr] then
    buffer_states[bufnr] = {}
  end
  return buffer_states[bufnr]
end

-- Check if a file is in a temp directory (from backupskip)
function M.is_temp_file(path)
  if not path or path == '' then
    return true
  end
  
  -- Split backupskip respecting escaped commas
  for _, pattern in ipairs(get_backupskip_items()) do
    pattern = vim.fn.glob2regpat(pattern)
    if vim.fn.match(path, pattern) ~= -1 then
      return true
    end
  end
  
  return false
end

-- Check if buffer's filetype is in the volatile list
function M.is_volatile_filetype(bufnr, volatile_ftypes)
  local filetype = vim.bo[bufnr].filetype
  if not filetype or filetype == '' then
    return false
  end
  
  -- Handle composite (dotted) filetypes
  for ft in filetype:gmatch('[^.]+') do
    for _, volatile_ft in ipairs(volatile_ftypes) do
      if ft == volatile_ft then
        return true
      end
    end
  end
  
  return false
end

-- Check if buffer should be persisted
function M.is_persistent(bufnr, volatile_ftypes)
  -- Get buffer path
  local bufpath = vim.api.nvim_buf_get_name(bufnr)
  
  -- Buffer name must not be empty
  if not bufpath or bufpath == '' then
    return false
  end
  
  -- Buffer must not be marked as ignored
  local ok, stay_ignore = pcall(vim.api.nvim_buf_get_var, bufnr, 'stay_ignore')
  if ok and stay_ignore == 1 then
    return false
  end
  
  -- Buffer must be listed
  if not vim.bo[bufnr].buflisted then
    return false
  end
  
  -- Buffer must be of ordinary or "acwrite" buftype
  local buftype = vim.bo[bufnr].buftype
  if buftype ~= '' and buftype ~= 'acwrite' then
    return false
  end
  
  -- Buffer's bufhidden must be empty or "hide"
  local bufhidden = vim.bo[bufnr].bufhidden
  if bufhidden ~= '' and bufhidden ~= 'hide' then
    return false
  end
  
  -- Buffer must map to a readable file
  if vim.fn.filereadable(bufpath) ~= 1 then
    return false
  end
  
  -- Buffer must not be of a volatile file type
  if M.is_volatile_filetype(bufnr, volatile_ftypes) then
    return false
  end
  
  -- Buffer file must not be in a temp directory
  if M.is_temp_file(bufpath) then
    return false
  end
  
  return true
end

-- Check if window is eligible for view saving
function M.is_view_window(winid)
  if not winid or winid == 0 then
    return false
  end
  
  -- Window must not be a preview window
  local ok, is_preview = pcall(vim.api.nvim_win_get_option, winid, 'previewwindow')
  if ok and is_preview then
    return false
  end
  
  -- Window must not be a diff window
  ok, is_diff = pcall(vim.api.nvim_win_get_option, winid, 'diff')
  if ok and is_diff then
    return false
  end
  
  return true
end

-- Handle error messages based on verbosity
function M.handle_error(level, message)
  if not message or message == '' then
    return
  end

  if level < math.min(1, M.config.verbosity) then
    vim.api.nvim_echo({{message, 'ErrorMsg'}}, true, {})
  end
end

return M
