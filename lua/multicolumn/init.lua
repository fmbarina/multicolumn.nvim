local config = require('multicolumn.config')
local reload = require('multicolumn.column').reload
local util = require('multicolumn.util')

local MULTICOLUMN_DIR = vim.fn.stdpath('state') .. '/multicolumn'
local ENABLED_FILE = MULTICOLUMN_DIR .. '/is-enabled'

local enabled = false

local M = {}

local function save_enabled_state()
  if vim.fn.isdirectory(MULTICOLUMN_DIR) ~= 0 then
    if vim.fn.filereadable(ENABLED_FILE) ~= 0 then
      vim.fn.delete(ENABLED_FILE)
    end
  else
    vim.fn.mkdir(MULTICOLUMN_DIR, 'p')
  end

  if enabled then
    local f = io.open(ENABLED_FILE, 'w')
    if f ~= nil then
      f:write('')
      f:close()
    end
  end
end

M.enable = function()
  if enabled then return end
  enabled = true

  -- Give theme plugins some time to set the default highlight
  vim.defer_fn(function()
    config.default_bg_color = util.get_hl_value('ColorColumn', 'bg')
    config.default_fg_color = util.get_hl_value('ColorColumn', 'fg')
    config.got_hl = true
  end, 100)

  reload()
  vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
    group = vim.api.nvim_create_augroup('MulticolumnReload', {}),
    callback = reload,
  })
end

M.disable = function()
  if not enabled then return end
  enabled = false

  vim.api.nvim_del_augroup_by_name('MulticolumnReload')
  vim.api.nvim_del_augroup_by_name('MulticolumnUpdate')

  vim.api.nvim_set_hl(0, 'ColorColumn', {
    bg = config.default_bg_color,
    fg = config.default_fg_color,
  })

  util.clear_all()
end

M.toggle = function()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

M.setup = function(opts)
  local ok = config.build(opts or {})

  if not ok then return end

  local start_enabled = false
  if config.opts.start == 'remember' then
    if vim.fn.isdirectory(MULTICOLUMN_DIR) ~= 0 then
      start_enabled = vim.fn.filereadable(ENABLED_FILE) ~= 0
    else
      start_enabled = true
    end
    vim.api.nvim_create_autocmd('VimLeave', { callback = save_enabled_state })
  else
    start_enabled = (config.opts.start == 'enabled')
  end

  if start_enabled then M.enable() end

  vim.api.nvim_create_user_command('MulticolumnEnable', M.enable, {
    desc = 'Enable colorcolumn',
  })
  vim.api.nvim_create_user_command('MulticolumnDisable', M.disable, {
    desc = 'Disable colorcolumn',
  })
  vim.api.nvim_create_user_command('MulticolumnToggle', M.toggle, {
    desc = 'Toggle on/off colorcolumn',
  })
end

return M
