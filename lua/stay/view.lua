-- nvim-stay.lua: View session handling
-- Handles creation and restoration of view sessions

local M = {}

-- Trigger autocommand if it exists
local function doautocmd(event, pattern)
  -- Check if there are any autocommands for this event
  local has_autocmd = vim.fn.exists('#' .. event)
  if pattern then
    has_autocmd = vim.fn.exists('#' .. event .. '#' .. pattern)
  end
  
  if has_autocmd ~= 0 then
    vim.cmd('doautocmd <nomodeline> ' .. event .. (pattern and (' ' .. pattern) or ''))
  end
end

-- Make a view session for the current window
function M.make(winid)
  local original_winid = vim.api.nvim_get_current_win()
  
  -- Switch to target window
  local ok = pcall(vim.api.nvim_set_current_win, winid)
  if not ok then
    vim.v.errmsg = 'vim-stay could not switch to window ID: ' .. tostring(winid)
    return 0
  end
  
  -- Trigger pre-save event
  doautocmd('User', 'BufStaySavePre')
  
  -- Save current viewoptions and enforce non-storage of options
  local original_viewoptions = vim.o.viewoptions
  
  local success = pcall(function()
    -- Remove options and localoptions from viewoptions
    local viewopts = {}
    for opt in original_viewoptions:gmatch('[^,]+') do
      if opt ~= 'options' and opt ~= 'localoptions' then
        table.insert(viewopts, opt)
      end
    end
    vim.o.viewoptions = table.concat(viewopts, ',')
    
    -- Clear stay_atpos if it exists
    pcall(vim.api.nvim_buf_del_var, 0, 'stay_atpos')
    
    -- Create the view
    vim.cmd('silent! mkview')
  end)
  
  -- Restore viewoptions
  vim.o.viewoptions = original_viewoptions
  
  -- Trigger post-save event
  doautocmd('User', 'BufStaySavePost')
  
  -- Return to original window
  pcall(vim.api.nvim_set_current_win, original_winid)
  
  if not success then
    vim.v.errmsg = 'vim-stay error while creating view'
    return -1
  end
  
  return 1
end

-- Load a view session for the current window
function M.load(winid)
  local original_winid = vim.api.nvim_get_current_win()
  
  -- Switch to target window
  local ok = pcall(vim.api.nvim_set_current_win, winid)
  if not ok then
    vim.v.errmsg = 'vim-stay could not switch to window ID: ' .. tostring(winid)
    return 0
  end
  
  -- Trigger pre-load event
  doautocmd('User', 'BufStayLoadPre')
  
  -- Save current eventignore and suppress SessionLoadPost
  local original_eventignore = vim.o.eventignore
  
  local did_load_view = false
  local stay_atpos = nil
  
  local success = pcall(function()
    -- Suppress SessionLoadPost for performance
    local ei_parts = {}
    for part in original_eventignore:gmatch('[^,]+') do
      table.insert(ei_parts, part)
    end
    table.insert(ei_parts, 'SessionLoadPost')
    vim.o.eventignore = table.concat(ei_parts, ',')
    
    -- Get stay_atpos before loading view
    ok, stay_atpos = pcall(vim.api.nvim_buf_get_var, 0, 'stay_atpos')
    if not ok then
      stay_atpos = nil
    end
    
    -- Load the view
    vim.cmd('silent! loadview')
    
    -- Check if a view was actually loaded by seeing if stay_loaded_view was set
    local loaded_ok, loaded_view = pcall(vim.api.nvim_buf_get_var, 0, 'stay_loaded_view')
    did_load_view = loaded_ok and loaded_view ~= nil
    
    if did_load_view then
      -- Restore eventignore and trigger SessionLoadPost
      vim.o.eventignore = original_eventignore
      doautocmd('SessionLoadPost')
      
      -- Respect position set by other scripts/plugins
      if stay_atpos then
        local pos = vim.api.nvim_win_get_cursor(0)
        if pos[1] ~= stay_atpos[1] or pos[2] ~= stay_atpos[2] then
          vim.api.nvim_win_set_cursor(0, {stay_atpos[1], stay_atpos[2]})
          vim.cmd('silent! normal! zOzz')
        end
      end
    end
  end)
  
  -- Restore eventignore
  vim.o.eventignore = original_eventignore
  
  -- Trigger post-load event
  doautocmd('User', 'BufStayLoadPost')
  
  -- Return to original window
  pcall(vim.api.nvim_set_current_win, original_winid)
  
  if not success then
    -- Silently fail for Neovim which commonly produces E484
    return 0
  end
  
  return did_load_view and 1 or 0
end

return M
