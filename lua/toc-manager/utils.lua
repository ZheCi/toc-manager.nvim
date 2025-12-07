local M = {}

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "TOC Manager" })
end

function M.get_path_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local path = line:match('%((%./.-)%)')
  if not path then return nil, nil end
  local filename = vim.fn.fnamemodify(path, ':t')
  return path, filename
end

function M.get_dir_from_path(path)
  return vim.fn.fnamemodify(path, ':h')
end

function M.copy_file(src, dest)
  local uv = vim.uv or vim.loop
  if vim.fn.filereadable(src) == 0 then return false, "源文件不存在" end
  local success, err = uv.fs_copyfile(src, dest, { excl = false })
  if not success then return false, err end
  return true, nil
end

function M.input(prompt, default_text, callback)
  vim.ui.input({ prompt = prompt, default = default_text }, callback)
end

return M
