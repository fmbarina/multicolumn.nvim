local M = {}

function M.get_hl_value(group, attr)
  return vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(group)), attr .. '#')
end

function M.is_floating(win)
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative > '' or cfg.external then return true end
  return false
end

function M.clear_colorcolum(win)
  if vim.wo[win].colorcolumn then vim.wo[win].colorcolumn = nil end
end

function M.clear_all()
  for _, win in pairs(vim.api.nvim_list_wins()) do
    M.clear_colorcolum(win)
    vim.fn.clearmatches(win)
  end
  for _, buf in pairs(vim.api.nvim_list_bufs()) do
    vim.b[buf].prev_state = nil
  end
end

return M
