-- nvim-stay.lua: View session handling
-- Handles creation and restoration of view sessions

local M = {}

-- Trigger autocommand if it exists
local function doautocmd(event, pattern, opts)
  opts = opts or {}
  -- Check if there are any autocommands for this event
  local has_autocmd
  if pattern then
    has_autocmd = vim.fn.exists('#' .. event .. '#' .. pattern)
  else
    has_autocmd = vim.fn.exists('#' .. event)
  end

  if has_autocmd ~= 0 then
    local cmd = 'doautocmd'
    if opts.nomodeline ~= false then
      cmd = cmd .. ' <nomodeline>'
    end
    cmd = cmd .. ' ' .. event
    if pattern then
      cmd = cmd .. ' ' .. pattern
    end
    vim.cmd(cmd)
  end
end

local function split_option_list(option)
  local result = {}
  if not option or option == '' then
    return result
  end

  for part in option:gmatch('[^,]+') do
    table.insert(result, part)
  end

  return result
end

local function ensure_string(err)
  if type(err) == 'string' then
    return err
  end
  if type(err) == 'table' and err.msg then
    return err.msg
  end
  return tostring(err)
end

local function classify_mkview_error(err)
  local message = ensure_string(err)
  local code = message:match('(E%d+)')

  if code == 'E166' or code == 'E190' or code == 'E212' then
    return -1, 'nvim-stay could not write the view session file! ' .. message
  end

  return -1, 'nvim-stay error ' .. message
end

local function classify_load_error(err)
  local message = ensure_string(err)
  local code = message:match('(E%d+)')

  if code == 'E484' then
    return 0, 'nvim-stay could not open the view session file! ' .. message
  end
  if code == 'E485' then
    return -1, 'nvim-stay could not read the view session file! ' .. message
  end
  if code == 'E350' or code == 'E351' or code == 'E352' or code == 'E490' then
    return 0, 'nvim-stay error ' .. message
  end

  return -1, 'nvim-stay error ' .. message
end

local viewdir_cache = {
  option = nil,
  path = nil,
}

local function get_viewdir_path()
  local option = vim.o.viewdir
  if not option or option == '' then
    return nil
  end

  if viewdir_cache.option ~= option then
    local normalized = option:gsub('\\', '/')
    normalized = normalized:gsub('/+$', '')
    viewdir_cache.option = option
    viewdir_cache.path = normalized
  end

  return viewdir_cache.path
end

-- Make a view session for the current window
function M.make(winid, disabled_viewoptions)
  local original_winid = vim.api.nvim_get_current_win()
  local disabled_lookup = {}

  if type(disabled_viewoptions) == 'table' then
    for _, opt in ipairs(disabled_viewoptions) do
      if type(opt) == 'string' and opt ~= '' then
        disabled_lookup[opt] = true
      end
    end
  end
  
  -- Switch to target window
  local ok = pcall(vim.api.nvim_set_current_win, winid)
  if not ok then
    vim.v.errmsg = 'nvim-stay could not switch to window ID: ' .. tostring(winid)
    return 0
  end
  
  -- Trigger pre-save event
  doautocmd('User', 'BufStaySavePre')
  
  -- Save current viewoptions and enforce non-storage of options
  local original_viewoptions = vim.o.viewoptions
  
  local ok, err = pcall(function()
    -- Remove options and localoptions from viewoptions
    local viewopts = {}
    for opt in original_viewoptions:gmatch('[^,]+') do
      if opt ~= 'options' and opt ~= 'localoptions' and not disabled_lookup[opt] then
        table.insert(viewopts, opt)
      end
    end
    vim.o.viewoptions = table.concat(viewopts, ',')

    -- Clear stay_atpos if it exists
    pcall(vim.api.nvim_buf_del_var, 0, 'stay_atpos')

    -- Create the view
    local success_mkview, mkview_err = pcall(vim.cmd, 'silent mkview')
    if not success_mkview then
      error(mkview_err)
    end
  end)

  -- Restore viewoptions
  vim.o.viewoptions = original_viewoptions
  
  -- Trigger post-save event
  doautocmd('User', 'BufStaySavePost')
  
  -- Return to original window
  pcall(vim.api.nvim_set_current_win, original_winid)
  
  if not ok then
    local level, message = classify_mkview_error(err)
    vim.v.errmsg = message
    return level
  end
  
  return 1
end

-- Load a view session for the current window
function M.load(winid)
  local original_winid = vim.api.nvim_get_current_win()
  
  -- Switch to target window
  local ok = pcall(vim.api.nvim_set_current_win, winid)
  if not ok then
    vim.v.errmsg = 'nvim-stay could not switch to window ID: ' .. tostring(winid)
    return 0
  end
  
  -- Trigger pre-load event
  doautocmd('User', 'BufStayLoadPre')
  
  -- Save current eventignore and suppress SessionLoadPost
  local original_eventignore = vim.o.eventignore
  
  local stay_atpos = nil
  local had_previous_loaded_view = false
  local previous_loaded_view
  local did_load_view = false
  local autocmd_id
  
  local ok_load, load_err = pcall(function()
    -- Suppress SessionLoadPost for performance and ensure SourceCmd still fires
    local ei_parts = split_option_list(original_eventignore)
    local filtered = {}
    local seen = {}
    for _, part in ipairs(ei_parts) do
      if part ~= '' and part ~= 'SessionLoadPost' and part ~= 'SourceCmd' and not seen[part] then
        table.insert(filtered, part)
        seen[part] = true
      end
    end
    table.insert(filtered, 'SessionLoadPost')
    vim.o.eventignore = table.concat(filtered, ',')

    -- Get stay_atpos before loading view
    local ok_var
    ok_var, stay_atpos = pcall(vim.api.nvim_buf_get_var, 0, 'stay_atpos')
    if not ok_var then
      stay_atpos = nil
    end

    ok_var, previous_loaded_view = pcall(vim.api.nvim_buf_get_var, 0, 'stay_loaded_view')
    if ok_var then
      had_previous_loaded_view = true
      pcall(vim.api.nvim_buf_del_var, 0, 'stay_loaded_view')
    else
      previous_loaded_view = nil
    end

    local viewdir_path = get_viewdir_path()
    if viewdir_path then
      local buftail = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')
      local escaped_dir = vim.fn.fnameescape(viewdir_path)
      local pattern = escaped_dir .. '*' .. vim.fn.fnameescape(buftail) .. '*'
      autocmd_id = vim.api.nvim_create_autocmd('SourcePre', {
        pattern = pattern,
        once = true,
        callback = function(args)
          vim.b.stay_loaded_view = args.file
        end,
      })
    end

    local ok_cmd, cmd_err = pcall(vim.cmd, 'silent loadview')
    if not ok_cmd then
      error(cmd_err)
    end

    did_load_view = vim.b.stay_loaded_view ~= nil

    if did_load_view then
      -- Restore eventignore and trigger SessionLoadPost with modelines enabled
      vim.o.eventignore = original_eventignore
      doautocmd('SessionLoadPost', nil, { nomodeline = false })

      -- Respect position set by other scripts/plugins
      if stay_atpos then
        local pos = vim.api.nvim_win_get_cursor(0)
        if pos[1] ~= stay_atpos[1] or pos[2] ~= stay_atpos[2] then
          vim.api.nvim_win_set_cursor(0, { stay_atpos[1], stay_atpos[2] })
          vim.cmd('silent! normal! zOzz')
        end
      end
    end
  end)

  -- Ensure temporary SourcePre autocmd is removed if it never fired
  if autocmd_id then
    pcall(vim.api.nvim_del_autocmd, autocmd_id)
  end

  -- Restore eventignore
  vim.o.eventignore = original_eventignore
  
  -- Trigger post-load event
  doautocmd('User', 'BufStayLoadPost')
  
  -- Return to original window
  pcall(vim.api.nvim_set_current_win, original_winid)
  
  if not ok_load then
    local level, message = classify_load_error(load_err)
    vim.v.errmsg = message

    if not did_load_view and had_previous_loaded_view and previous_loaded_view ~= nil then
      vim.b.stay_loaded_view = previous_loaded_view
    end

    return level
  end
  
  if not did_load_view and had_previous_loaded_view and previous_loaded_view ~= nil then
    vim.b.stay_loaded_view = previous_loaded_view
  end
  
  return did_load_view and 1 or 0
end

return M
