local M = {}

local defaults = {
  start = 'enabled', -- enabled, disabled, remember
  update = 'on_move', -- on_move, lazy_hold, int
  max_lines = 6000, -- 0 (disabled) OR int
  use_default_set = true,
  exclude_floating = true,
  exclude_ft = { 'markdown', 'help', 'netrw' },
  base_set = {
    scope = 'window', -- file, window, line
    rulers = {}, -- { int, int, ... }
    to_line_end = false,
    full_column = false,
    always_on = false,
    bg_color = nil,
    fg_color = nil,
  },
  sets = {
    default = {
      rulers = { 81 },
    },
  },
}

M.opts = {}

function M.fix_set(set)
  -- Some configs imply others. Fixing nonsensical stuff early on helps simplify
  -- code later by reducing the amount of cases that must be handled.
  if set.always_on then
    set.full_column = true -- Implied when always_on
    if set.scope == 'file' then
      set.scope = 'window' -- Needn't scope file if column is always on
    end
  end
  if set.scope == 'file' and not set.full_column then
    set.scope = 'window' -- Needn't scope file if not even drawing full column
  end
  return set
end

function M.build(opts)
  local cfg = vim.tbl_deep_extend('force', {}, defaults, opts or {})

  local update_t = type(cfg.update)
  if not vim.tbl_contains({ 'string', 'number' }, update_t) then
    print('multicolumn.nvim: not a valid update type: ' .. update_t)
    return false
  end

  local update_strs = { 'on_move', 'lazy_hold' }
  if update_t == 'string' and not vim.tbl_contains(update_strs, cfg.update) then
    print('multicolumn.nvim: not a valid update option: ' .. cfg.update)
    return false
  elseif update_t == 'number' and cfg.update <= 0 then
    print(
      'multicolumn.nvim: invalid update timing (must be positive): '
        .. cfg.update
    )
    return false
  end

  for k, _ in pairs(cfg.sets) do
    if not (type(cfg.sets[k]) == 'function') then
      cfg.sets[k] = M.fix_set(vim.tbl_extend('keep', cfg.sets[k], cfg.base_set))
    end
  end

  M.opts = cfg
  return true
end

return M
