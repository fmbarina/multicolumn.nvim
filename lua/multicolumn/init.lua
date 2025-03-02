local column = require('multicolumn.column')
local config = require('multicolumn.config')

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
    config.default_bg_color = column.get_hl_value('ColorColumn', 'bg')
    config.default_fg_color = column.get_hl_value('ColorColumn', 'fg')
    config.got_hl = true
  end, 100)

  column.reload()
  vim.api.nvim_create_autocmd({ 'WinEnter' }, {
    group = vim.api.nvim_create_augroup('MulticolumnReload', {}),
    callback = column.reload,
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

  column.clear_all()
end

M.toggle = function()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

local function command_create()
  if config.opts.command == 'multiple' then
    vim.api.nvim_create_user_command('MulticolumnEnable', M.enable, {
      desc = 'Enable colorcolumn',
    })
    vim.api.nvim_create_user_command('MulticolumnDisable', M.disable, {
      desc = 'Disable colorcolumn',
    })
    vim.api.nvim_create_user_command('MulticolumnToggle', M.toggle, {
      desc = 'Toggle on/off colorcolumn',
    })
  elseif config.opts.command == 'single' then
    vim.api.nvim_create_user_command('Multicolumn', function(cmd)
      if #cmd.args == 0 then
        M.toggle()
      else
        M[cmd.args]()
      end
    end, {
      desc = 'Colorcolumn plugin commands',
      nargs = '?',
      complete = function(lead)
        return vim.tbl_filter(function(key)
          return string.find(key, lead, 1, true) == 1
        end, {
          'toggle',
          'enable',
          'disable',
        })
      end,
    })
  end
end

---@param opts? multicolumn.Opts
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

  command_create()
end

return M
