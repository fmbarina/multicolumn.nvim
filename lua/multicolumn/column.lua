local config = require('multicolumn.config')

local timer = nil

local M = {}

function M.get_hl_value(group, attr)
  return vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(group)), attr .. '#')
end

function M.clear_all()
  for _, win in pairs(vim.api.nvim_list_wins()) do
    if vim.wo[win].colorcolumn then vim.wo[win].colorcolumn = nil end
    vim.fn.clearmatches(win)
  end
  for _, buf in pairs(vim.api.nvim_list_bufs()) do
    vim.b[buf].prev_state = nil
  end
end

local function is_floating(win)
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative > '' or cfg.external then return true end
  return false
end

local function buffer_disabled(win)
  if config.opts.use_default_set then
    if config.opts.exclude_floating and is_floating(win) then
      return true
    elseif vim.tbl_contains(config.opts.exclude_ft, vim.bo.filetype) then
      return true
    end
  elseif config.opts.sets[vim.bo.filetype] == nil then
    return true
  end
  return false
end

local function get_exceeded(ruleset, buf, win)
  local lines = nil

  if ruleset.scope == 'file' then
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  elseif ruleset.scope == 'window' then
    local first = vim.fn.line('w0', win)
    local last = vim.fn.line('w$', win)
    lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
  else -- config.opts.scope == 'line'
    local cur_line = vim.fn.line('.', win)
    lines = vim.api.nvim_buf_get_lines(buf, cur_line - 1, cur_line, false)
  end

  local col = vim.fn.min(ruleset.rulers)
  for _, line in pairs(lines) do
    local ok, cells = pcall(vim.fn.strdisplaywidth, line)
    if not ok then return false end
    if col <= cells then return true end
  end

  return false
end

local function update_colorcolumn(ruleset, buf, win)
  local state = ruleset.always_on or get_exceeded(ruleset, buf, win)
  local rulers = table.concat(ruleset.rulers, ',')

  if (state ~= vim.b.prev_state) or (rulers ~= vim.b.prev_rulers) then
    vim.b.prev_state = state
    vim.b.prev_rulers = rulers

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

function M.update(buf, win)
  local ruleset = {}

  if type(config.opts.sets[vim.bo.filetype]) == 'function' then
    local ok, result = pcall(config.opts.sets[vim.bo.filetype], buf, win)
    if ok and result ~= nil then
      ruleset = vim.tbl_extend('keep', result, config.opts.base_set)
    else
      return true
    end
  elseif config.opts.sets[vim.bo.filetype] ~= nil then
    ruleset = config.opts.sets[vim.bo.filetype]
  elseif config.opts.use_default_set then
    ruleset = config.opts.sets.default
  else
    return true -- shoudn't happen on a proper config?
  end

  if
    ruleset.scope == 'file'
    and (config.opts.max_lines ~= 0)
    and (vim.api.nvim_buf_line_count(buf) > config.opts.max_lines)
  then
    return true -- DYK returning true in an autocmd callback deletes it?
  end

  if config.got_hl then
    vim.api.nvim_set_hl(0, 'ColorColumn', {
      bg = ruleset.bg_color or config.default_bg_color or '',
      fg = ruleset.fg_color or config.default_fg_color or '',
    })
  end

  if ruleset.full_column or ruleset.always_on then
    update_colorcolumn(ruleset, buf, win)
  end

  if (not ruleset.full_column) or ruleset.to_line_end then
    update_matches(ruleset)
  end
end

function M.reload()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  -- HACK: del_augroup and clear_autocmds will error(?) if group or
  -- autocmd don't exist, respectively, so just create an empty one
  vim.api.nvim_create_augroup('MulticolumnUpdate', {})
  if timer then
    if not timer:is_closing() then timer:close() end
    timer = nil
  end

  M.clear_all()

  -- HACK: ft might not be set fast enough? unsure, but force reloading fixes it
  if vim.bo.filetype == '' then
    vim.api.nvim_create_autocmd('Filetype', {
      group = vim.api.nvim_create_augroup('MulticolumnHackReload', {}),
      callback = M.reload,
      once = true,
    })
  end

  if buffer_disabled(win) then return end

  if type(config.opts.update) == 'string' then
    local events = nil
    if config.opts.update == 'lazy_hold' then
      events = { 'CursorHold', 'CursorHoldI' }
    elseif config.opts.update == 'on_move' then
      events = { 'CursorMoved', 'CursorMovedI', 'WinScrolled' }
    else
      return true -- Should be impossible with setup checking
    end

    vim.api.nvim_create_autocmd(events, {
      group = vim.api.nvim_create_augroup('MulticolumnUpdate', {}),
      buffer = buf,
      callback = function()
        return M.update(buf, win)
      end,
    })

    M.update(buf, win)
  elseif type(config.opts.update) == 'number' then
    if timer then return end

    timer = vim.loop.new_timer()
    if timer == nil then
      print('multicolumn.nvim: failed to start timer')
      return true
    end

    timer:start(
      0,
      config.opts.update,
      vim.schedule_wrap(function()
        M.update(buf, win)
      end)
    )
  else
    return true -- again, shouldn't happen with setup checking
  end
end

return M
