-- nvim-stay.lua: viewdir management utilities
-- Handles cleaning of view directory

local M = {}

local function to_bool(value)
  if value == nil then
    return false
  end
  if type(value) == 'boolean' then
    return value
  end
  if type(value) == 'number' then
    return value ~= 0
  end
  if type(value) == 'string' then
    return value ~= ''
  end
  return false
end

-- Clean view directory
function M.clean(bang, keepdays)
  local keep = tonumber(keepdays) or 0
  local keepsecs = math.max(math.floor(keep * 86400), 0)

  local viewdir = vim.o.viewdir
  if not viewdir or viewdir == '' then
    vim.notify('nvim-stay: viewdir is not set', vim.log.levels.WARN)
    return { 0, 0 }
  end

  local candidates = vim.fn.globpath(viewdir, '*', 1, 1)
  if type(candidates) ~= 'table' then
    candidates = {}
  end

  local current_time = os.time()
  local expired = {}
  for _, file in ipairs(candidates) do
    local ftime = vim.fn.getftime(file)
    if current_time - ftime > keepsecs then
      table.insert(expired, file)
    end
  end

  local cand_count = #expired
  local del_count = 0

  local should_delete = to_bool(bang)
  if not should_delete and cand_count > 0 then
    local answer = vim.fn.input('Delete ' .. cand_count .. ' view session files? (y/n): ')
    should_delete = type(answer) == 'string' and answer:lower() == 'y'
  end

  if should_delete then
    for _, file in ipairs(expired) do
      if vim.fn.delete(file) == 0 then
        del_count = del_count + 1
      end
    end
  end

  print('\nDeleted ' .. del_count .. ' files.')
  return { cand_count, del_count }
end

return M
