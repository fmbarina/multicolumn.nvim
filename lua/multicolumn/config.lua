local M = {}

---@class multicolumn.Ruleset
---@field scope? 'file' | 'window' | 'line'
---@field rulers integer[]
---@field to_line_end? boolean
---@field full_column? boolean
---@field always_on? boolean
---@field on_exceeded? boolean
---@field bg_color? string
---@field fg_color? string

---@class multicolumn.Opts
---@field start? 'enabled' | 'disabled' | 'remember'
---@field update? 'on_move' | 'lazy_hold' | integer
---@field command? 'multiple' | 'single' | 'none'
---@field max_lines? integer
---@field max_size? integer
---@field use_default_set? boolean
---@field exclude_floating? boolean
---@field exclude_ft? string[]
---@field editorconfig? boolean
---@field base_set? multicolumn.Ruleset
---@field sets? { [string]: multicolumn.Ruleset }

---@type multicolumn.Opts
local defaults = {
  start = 'enabled',
  update = 'on_move',
  command = 'multiple',
  max_lines = 6000,
  max_size = 64 * 1024 * 1024,
  use_default_set = true,
  exclude_floating = true,
  exclude_ft = { 'markdown', 'help', 'netrw' },
  editorconfig = false,
  base_set = {
    scope = 'window',
    rulers = {},
    to_line_end = false,
    full_column = false,
    always_on = false,
    on_exceeded = false,
    bg_color = nil,
    fg_color = nil,
  },
  sets = {
    default = {
      rulers = { 81 },
    },
  },
}

---@param set multicolumn.Ruleset
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

---@param opts? multicolumn.Opts
function M.build(opts)
  local cfg = vim.tbl_deep_extend('force', {}, defaults, opts or {})

  local update_t = type(cfg.update)
  if not vim.tbl_contains({ 'string', 'number' }, update_t) then
    vim.notify(
      'multicolumn.nvim: not a valid update type: ' .. update_t,
      vim.log.levels.ERROR
    )
    return false
  end

  local update_strs = { 'on_move', 'lazy_hold' }
  if update_t == 'string' and not vim.tbl_contains(update_strs, cfg.update) then
    vim.notify(
      'multicolumn.nvim: not a valid update option: ' .. cfg.update,
      vim.log.levels.ERROR
    )
    return false
  elseif update_t == 'number' and cfg.update <= 0 then
    vim.notify(
      'multicolumn.nvim: invalid update timing (must be positive): '
        .. cfg.update,
      vim.log.levels.ERROR
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
