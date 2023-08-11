local M = {}

local MULTICOLUMN_DIR = vim.fn.stdpath('state') .. '/multicolumn'
local ENABLED_FILE = MULTICOLUMN_DIR .. '/is-enabled'

local m = {
  enabled = nil,
  first_reload = nil,
  bg_color = nil,
  fg_color = nil,
}

local config = {
  start = 'enabled', -- enabled, disabled, remember
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
  line_limit = 6000, -- 0 (disabled) OR int
  exclude_floating = true,
  exclude_ft = { 'markdown', 'help', 'netrw' },
}

local function get_hi_value(group, attr)
  return vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(group)), attr .. '#')
end

local function is_floating(win)
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative > '' or cfg.external then return true end
  return false
end

local function clear_colorcolum(win)
  if vim.wo[win].colorcolumn then vim.wo[win].colorcolumn = nil end
end

local function buffer_disabled(win)
  if config.exclude_floating and is_floating(win) then
    return true
  elseif vim.tbl_contains(config.exclude_ft, vim.bo.filetype) then
    return true
  end
  return false
end

local function get_exceeded(ruleset, buf, win)
  local lines = nil

  if ruleset.scope == 'file' then
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
  elseif ruleset.scope == 'window' then
    local first = vim.fn.line('w0', win)
    local last = vim.fn.line('w$', win)
    lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, true)
  else -- config.cope == 'line'
    local cur_line = vim.fn.line('.', win)
    lines = vim.api.nvim_buf_get_lines(buf, cur_line - 1, cur_line, true)
  end

  local col = vim.fn.min(ruleset.rulers)
  for _, line in pairs(lines) do
    if col <= vim.fn.strdisplaywidth(line) then return true end
  end

  return false
end

local function update_colorcolumn(ruleset, buf, win)
  if ruleset.always_on then
    vim.wo[win].colorcolumn = table.concat(ruleset.rulers, ',')
    return
  end

  local state = get_exceeded(ruleset, buf, win)
  local rulers = table.concat(ruleset.rulers, ',')

  if (state ~= vim.b.prev_state) or (rulers ~= vim.b.prev_rulers) then
    vim.b.prev_state = state
    vim.b.prev_rulers = ruleset.rulers

    if state then
      vim.wo[win].colorcolumn = rulers
    else
      vim.wo[win].colorcolumn = nil
    end
  end
end

local function update_matches(ruleset)
  vim.fn.clearmatches()

  local line_prefix = ''
  if ruleset.scope == 'line' then
    line_prefix = '\\%' .. vim.fn.line('.') .. 'l'
  end

  if ruleset.to_line_end then
    vim.fn.matchadd(
      'ColorColumn',
      line_prefix .. '\\%' .. vim.fn.min(ruleset.rulers) .. 'v[^\n].*$'
    )
  else
    for _, v in pairs(ruleset.rulers) do
      vim.fn.matchadd('ColorColumn', line_prefix .. '\\%' .. v .. 'v[^\n]')
    end
  end
end

local function update(buf, win)
  local ruleset = vim.deepcopy(config.base_set)

  if config.sets[vim.bo.filetype] == nil then
    ruleset = vim.tbl_deep_extend('force', ruleset, config.sets.default)
  elseif type(config.sets[vim.bo.filetype]) == 'function' then
    local ok, result = pcall(config.sets[vim.bo.filetype], buf, win)
    if ok and ruleset ~= nil then ruleset = result end
  else
    ruleset =
      vim.tbl_deep_extend('force', ruleset, config.sets[vim.bo.filetype])
  end

  if
    ruleset.scope == 'file'
    and (config.line_limit ~= 0)
    and (vim.api.nvim_buf_line_count(buf) > config.line_limit)
  then
    return true -- DYK returning true in an autocmd callback deletes it?
  end

  vim.api.nvim_set_hl(0, 'ColorColumn', {
    bg = ruleset.bg_color or m.bg_color,
    fg = ruleset.fg_color or m.fg_color,
  })

  if ruleset.full_column or ruleset.always_on then
    update_colorcolumn(ruleset, buf, win)
  else
    clear_colorcolum(win)
  end

  if (not ruleset.full_column) or ruleset.to_line_end then
    update_matches(ruleset)
  else
    vim.fn.clearmatches(win)
  end

  return false
end

local function reload()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  -- HACK: del_augroup errors if grp doesn't exist, so just create an empty one
  vim.api.nvim_create_augroup('MulticolumnUpdate', {})
  for _, fwin in pairs(vim.api.nvim_list_wins()) do
    clear_colorcolum(fwin)
    vim.fn.clearmatches(fwin)
  end

  if buffer_disabled(win) then return false end

  -- If get_hi_value is called in enable() the right ColorColumn hl may not be
  -- set during setup (ex: due to a theme plugin). Here, that's less likely
  if m.first_reload then
    m.bg_color = get_hi_value('ColorColumn', 'bg')
    m.fg_color = get_hi_value('ColorColumn', 'fg')
    m.first_reload = false
  end

  vim.api.nvim_create_autocmd(
    { 'CursorMoved', 'CursorMovedI', 'WinScrolled' },
    {
      group = vim.api.nvim_create_augroup('MulticolumnUpdate', {}),
      buffer = buf,
      callback = function()
        return update(buf, win)
      end,
    }
  )

  update(buf, win)
end

local function build_config(cfg)
  local new_config = vim.deepcopy(cfg)
  for k, _ in pairs(cfg.sets) do
    if type(cfg.sets[k]) == 'function' then
      new_config.sets[k] = cfg.sets[k]
    else
      new_config.sets[k] =
        vim.tbl_deep_extend('keep', cfg.sets[k], cfg.base_set)
    end
  end
  return config
end

local function save_enabled_state()
  if vim.fn.isdirectory(MULTICOLUMN_DIR) ~= 0 then
    if vim.fn.filereadable(ENABLED_FILE) ~= 0 then
      vim.fn.delete(ENABLED_FILE)
    end
  else
    vim.fn.mkdir(MULTICOLUMN_DIR, 'p')
  end

  if m.enabled then
    local f = io.open(ENABLED_FILE, 'w')
    if f ~= nil then
      f:write('')
      f:close()
    end
  end
end

M.enable = function()
  if m.enabled then return end

  vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
    group = vim.api.nvim_create_augroup('MulticolumnReload', {}),
    callback = reload,
  })

  m.first_reload = true
  m.enabled = true
end

M.disable = function()
  if not m.enabled then return end

  vim.api.nvim_del_augroup_by_name('MulticolumnReload')
  vim.api.nvim_del_augroup_by_name('MulticolumnUpdate')

  vim.api.nvim_set_hl(0, 'ColorColumn', {
    bg = m.bg_color,
    fg = m.fg_color,
  })

  for _, win in pairs(vim.api.nvim_list_wins()) do
    vim.fn.clearmatches(win)
    vim.wo[win].colorcolumn = nil
  end

  m.first_reload = true
  m.enabled = false
end

M.toggle = function()
  if m.enabled then
    M.disable()
  else
    M.enable()
  end
end

M.setup = function(opts)
  config = vim.tbl_deep_extend('force', config, opts or {})
  config = build_config(config)

  local start_enabled = false
  if config.start == 'remember' then
    start_enabled = vim.fn.filereadable(ENABLED_FILE) ~= 0
    vim.api.nvim_create_autocmd('VimLeave', { callback = save_enabled_state })
  else
    start_enabled = (config.start == 'enabled')
  end

  if start_enabled then M.enable() end

  vim.api.nvim_create_user_command('MulticolumnEnable', M.enable, {})
  vim.api.nvim_create_user_command('MulticolumnDisable', M.disable, {})
  vim.api.nvim_create_user_command('MulticolumnToggle', M.toggle, {})
end

return M