-- nvim-stay.lua: Core persistence logic
-- Maintainer: Based on vim-stay by Martin Kopischke and Zach Himsel
-- License: MIT

local M = {}

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

-- Buffer state storage
local buffer_states = {}

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
  
  local backupskip = vim.o.backupskip
  if not backupskip or backupskip == '' then
    return false
  end
  
  -- Split backupskip by commas (handle escaped commas)
  for pattern in backupskip:gmatch('[^,]+') do
    -- Simple pattern matching - convert vim glob to lua pattern
    pattern = pattern:gsub('\\,', ',') -- unescape commas
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
  if level < math.min(1, M.config.verbosity) then
    vim.api.nvim_echo({{message, 'ErrorMsg'}}, true, {})
  end
end

return M
