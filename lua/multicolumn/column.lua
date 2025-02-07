local config = require('multicolumn.config')

local timer = nil

local M = {}

function M.get_hl_value(group, attr)
  return vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(group)), attr .. '#')
end

function M.clear_all()
  for _, win in pairs(vim.api.nvim_list_wins()) do
    if vim.wo[win].colorcolumn then vim.wo[win].colorcolumn = '' end
    vim.fn.clearmatches(win)
  end
  for _, buf in pairs(vim.api.nvim_list_bufs()) do
    vim.b[buf].multicolumn_prev_state = nil
    vim.b[buf].multicolumn_prev_rulers = nil
  end
end

local function is_floating(win)
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative > '' or cfg.external then return true end
  return false
end

local function is_disabled(win)
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

-- Inspired by the work of loicreynier in smartcolumn.nvim
local function get_editorconfig_ruler()
  local max_line_length = vim.b.editorconfig
    and vim.b.editorconfig.max_line_length ~= 'off'
    and vim.b.editorconfig.max_line_length ~= 'unset'
    and vim.b.editorconfig.max_line_length

  if max_line_length then return { tonumber(max_line_length) } end
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

  if ruleset.on_exceeded then col = col + 1 end

  for _, line in pairs(lines) do
    local ok, cells = pcall(vim.fn.strdisplaywidth, line)
    if not ok then return false end
    if col <= cells then return true end
  end

  return false
end

local function update_colorcolumn(ruleset, buf, win)
  local state = ruleset.always_on or get_exceeded(ruleset, buf, win)
  local rulers = ''

  if ruleset.on_exceeded then
    local new_rulers = {}
    for i, v in ipairs(ruleset.rulers) do
      new_rulers[i] = v
    end
    rulers = table.concat(new_rulers, ',')
    print(vim.inspect(rulers))
  else
    rulers = table.concat(ruleset.rulers, ',')
  end

  if
    (state ~= vim.b.multicolumn_prev_state)
    or (rulers ~= vim.b.multicolumn_prev_rulers)
  then
    -- Maybe should switch to an internal data structure?
    ---@diagnostic disable: inject-field
    vim.b.multicolumn_prev_state = state
    vim.b.multicolumn_prev_rulers = rulers
    ---@diagnostic enable: inject-field

    if state then
      vim.wo[win].colorcolumn = rulers
    else
      vim.wo[win].colorcolumn = ''
    end
  end
end

-- NOTE: would be interesting to scope matches to buffer (passed as 'buf' arg,
-- as in update_colorcolumn), if that feature is ever implemented in [neo]vim
local function update_matches(ruleset, win)
  vim.fn.clearmatches()

  local line_prefix = ''
  if ruleset.scope == 'line' then
    line_prefix = '\\%' .. vim.fn.line('.') .. 'l'
  end

  local function add_match(pattern)
    vim.fn.matchadd('ColorColumn', pattern, nil, -1, { window = win })
  end

  if ruleset.to_line_end then
    local col = vim.fn.min(ruleset.rulers)
    if ruleset.on_exceeded then col = col + 1 end
    add_match(line_prefix .. '\\%' .. col .. 'v[^\n].*$')
  else
    for _, v in pairs(ruleset.rules) do
      if ruleset.on_exceeded then v = v + 1 end
      add_match(line_prefix .. '\\%' .. v .. 'v[^\n]')
    end
  end
end

function M.update(win)
  local buf = vim.api.nvim_win_get_buf(win)
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
    (
      config.opts.max_size ~= 0
      and (vim.fn.getfsize(vim.fn.expand('%')) > config.opts.max_size)
    )
    or (
      ruleset.scope == 'file'
      and (config.opts.max_lines ~= 0)
      and (vim.api.nvim_buf_line_count(buf) > config.opts.max_lines)
    )
  then
    return true -- DYK returning true in an autocmd callback deletes it?
  end

  if config.got_hl then
    vim.api.nvim_set_hl(0, 'ColorColumn', {
      bg = ruleset.bg_color or config.default_bg_color or '',
      fg = ruleset.fg_color or config.default_fg_color or '',
    })
  end

  if config.opts.editorconfig then
    ruleset.rulers = get_editorconfig_ruler() or ruleset.rulers
  end

  print(ruleset.on_exceeded)

  if ruleset.full_column or ruleset.always_on then
    update_colorcolumn(ruleset, buf, win)
  end

  if (not ruleset.full_column) or ruleset.to_line_end then
    update_matches(ruleset, win)
  end
end

local function create_update_aucmds(win)
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
      callback = function()
        return M.update(win)
      end,
    })
    return M.update(win)
  elseif type(config.opts.update) == 'number' then
    if timer then return end

    timer = vim.loop.new_timer()
    if timer == nil then
      vim.notify_once(
        'multicolumn.nvim: failed to start timer',
        vim.log.levels.ERROR
      )
      return true
    end

    timer:start(
      0,
      config.opts.update,
      vim.schedule_wrap(function()
        M.update(win)
      end)
    )
  else
    return true -- again, shouldn't happen with setup checking
  end
end

function M.reload()
  -- HACK: del_augroup and clear_autocmds will error(?) if group or
  -- autocmd don't exist, respectively, so just create an empty one
  vim.api.nvim_create_augroup('MulticolumnUpdate', {})

  if timer then
    if not timer:is_closing() then timer:close() end
    timer = nil
  end

  M.clear_all()

  -- NOTE: I tried all I know to obviate the need for this code, but AFAIK there
  -- is no pretty & reliable way to run a callback on window switching only when
  -- it is certain that, if a filetype was to be set, it will have been already.
  -- This may be revisited in a future release, but for now it'll do.
  vim.defer_fn(function()
    local win = vim.api.nvim_get_current_win()
    if is_disabled(win) then return end
    return create_update_aucmds(win)
  end, 50)
end

return M
