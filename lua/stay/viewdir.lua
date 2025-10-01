-- nvim-stay.lua: viewdir management utilities
-- Handles cleaning of view directory

local M = {}

-- Clean view directory
function M.clean(bang, keepdays)
  keepdays = keepdays or 0
  local keepsecs = math.max(keepdays * 86400, 0)
  
  local viewdir = vim.o.viewdir
  if not viewdir or viewdir == '' then
    print('viewdir is not set')
    return {0, 0}
  end
  
  -- Get all files in viewdir
  local pattern = viewdir .. '/*'
  local candidates = vim.fn.glob(pattern, 1, 1)
  
  -- Filter by age
  local current_time = os.time()
  local filtered_candidates = {}
  for _, file in ipairs(candidates) do
    local ftime = vim.fn.getftime(file)
    if current_time - ftime > keepsecs then
      table.insert(filtered_candidates, file)
    end
  end
  
  local cand_count = #filtered_candidates
  local del_count = 0
  
  -- Ask for confirmation unless bang is used
  if bang or vim.fn.input('Delete ' .. cand_count .. ' view session files? (y/n): ') == 'y' then
    for _, file in ipairs(filtered_candidates) do
      if vim.fn.delete(file) == 0 then
        del_count = del_count + 1
      end
    end
  end
  
  print('\nDeleted ' .. del_count .. ' files.')
  return {cand_count, del_count}
end

return M
