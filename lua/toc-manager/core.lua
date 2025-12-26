local M = {}
local config = require("toc-manager.config")
local utils = require("toc-manager.utils")

M.cwd = vim.fn.getcwd()
M.last_yank = nil
M.line_map = {}

-- =======================================================
-- 1. 生成与渲染
-- =======================================================

local function scan_to_tree_node(path, rel_base)
  local handle = vim.loop.fs_scandir(path)
  if not handle then return {} end
  local children = {}
  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end
    local is_dir = (type == "directory")
    local rel_path = (rel_base == "" and name or rel_base .. "/" .. name)
    local full_path = path .. "/" .. name
    local skip = false

    if name == config.options.filename then skip = true end
    if not config.options.behavior.filters.show_hidden and name:match("^%.") then skip = true end
    if is_dir and vim.tbl_contains(config.options.behavior.filters.exclude_dirs, name) then skip = true end

    if not skip then
      local node = { name = name, type = is_dir and "dir" or "file", path = full_path, rel = rel_path, children = {} }
      if is_dir then node.children = scan_to_tree_node(full_path, rel_path) end
      table.insert(children, node)
    end
  end
  table.sort(children, function(a, b) if a.type ~= b.type then return a.type == "dir" else return a.name < b.name end end)
  return children
end

local function render_tree_recursive(nodes, indent_level, lines, map)
  local indent = string.rep("  ", indent_level)
  local icons = config.options.icons
  for _, node in ipairs(nodes) do
    local line_text = ""
    if node.type == "dir" then
      line_text = string.format("%s- %s%s/", indent, icons.dir, node.name)
    else
      local display_name = utils.get_stem(node.name)
      local url = "./" .. node.rel:gsub(" ", "%%20")
      line_text = string.format("%s- %s[%s](%s)", indent, icons.file, display_name, url)
      if node.name:match("%.md$") then
        local tags = utils.extract_tags(node.path)
        if #tags > 0 then line_text = line_text .. config.options.behavior.tags.prefix .. table.concat(tags, ", ") .. "`" end
      end
    end
    table.insert(lines, line_text)
    map[#lines] = { path = node.path, type = node.type }
    if node.type == "dir" then render_tree_recursive(node.children, indent_level + 1, lines, map) end
  end
end

function M.refresh(silent)
  M.cwd = vim.fn.getcwd()
  local tree = scan_to_tree_node(M.cwd, "")
  local lines = {}
  table.insert(lines, config.options.title)
  table.insert(lines, "")
  table.insert(lines, "> Root: `" .. M.cwd .. "`")
  table.insert(lines, "> Help: `?`")
  table.insert(lines, "---")
  table.insert(lines, "")

  M.line_map = {}
  render_tree_recursive(tree, 0, lines, M.line_map)

  local bufnr = vim.api.nvim_get_current_buf()
  if vim.fn.bufname(bufnr):match(config.options.filename .. "$") then
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].modified = false
  end

  local f = io.open(M.cwd .. "/" .. config.options.filename, "w")
  if f then
    for _, l in ipairs(lines) do f:write(l .. "\n") end
    f:close()
  end

  if is_toc_buf then
    vim.cmd("checktime")
  end

  if not silent then utils.notify("已刷新") end
end

-- =======================================================
-- 2. 操作逻辑
-- =======================================================

function M.get_current_info()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local info = M.line_map[row]
  if info then
    local rel_path = utils.get_relative_path(M.cwd, info.path)
    return info.path, info.type, rel_path
  end
  return nil, nil, nil
end

function M.action_delete()
  local full_path, type, _ = M.get_current_info()
  if not full_path then return end

  -- [修改] 移除 confirm 确认，直接删除
  local name = vim.fn.fnamemodify(full_path, ":t")
  local trash_dir = utils.ensure_trash_dir(M.cwd)
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local trash_name = name .. "_" .. timestamp
  if type == "file" then
    trash_name = name:gsub("(%.%w+)$", "") .. "_" .. timestamp .. name:match("(%.%w+)$")
  end
  local trash_path = trash_dir .. "/" .. trash_name

  if os.rename(full_path, trash_path) then
    utils.notify("🗑️ 已删除: " .. name)
    M.refresh(true)
  else
    utils.notify("❌ 删除失败", vim.log.levels.ERROR)
  end
end

function M.action_restore()
  local trash_dir = M.cwd .. "/" .. config.options.behavior.trash_dir
  local handle = vim.loop.fs_scandir(trash_dir)
  if not handle then
    utils.notify("回收站为空"); return
  end
  local files = {}
  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end
    local stat = vim.loop.fs_stat(trash_dir .. "/" .. name)
    if stat then table.insert(files, { name = name, time = stat.mtime.sec }) end
  end
  if #files == 0 then
    utils.notify("回收站为空"); return
  end
  table.sort(files, function(a, b) return a.time > b.time end)
  local target_file = files[1].name
  local original_name = target_file:gsub("_%d%d%d%d%d%d%d%d_%d%d%d%d%d%d", "")
  local dest_path = M.cwd .. "/" .. original_name
  if os.rename(trash_dir .. "/" .. target_file, dest_path) then
    utils.notify("♻️ 已恢复: " .. original_name)
    M.refresh(true)
  end
end

function M.action_yank()
  local _, type, rel_path = M.get_current_info()
  if rel_path and type == "file" then
    M.last_yank = rel_path
    utils.notify("已记录源: " .. rel_path)
  end
end

function M.action_paste()
  if not M.last_yank then
    utils.notify("请先 yy 复制"); return
  end
  local full_path, type, _ = M.get_current_info()
  local dest_dir = M.cwd
  if full_path then
    if type == "dir" then
      dest_dir = full_path
    else
      dest_dir = vim.fn.fnamemodify(full_path, ":h")
    end
  end
  local old_name = vim.fn.fnamemodify(M.last_yank, ":t")
  utils.input("Copy as: ", "copy_" .. old_name, function(new_name)
    if not new_name or new_name == "" then return end
    local src_path = M.cwd .. "/" .. M.last_yank:sub(3)
    local dest_path = dest_dir .. "/" .. new_name
    if utils.copy_file(src_path, dest_path) then
      utils.notify("✅ 已复制: " .. new_name)
      M.refresh(true)
    end
  end)
end

function M.create_new()
  local full_path, type, _ = M.get_current_info()
  local base_dir = M.cwd
  if full_path then
    if type == "dir" then
      base_dir = full_path
    else
      base_dir = vim.fn.fnamemodify(full_path, ":h")
    end
  end
  utils.input("New (file.md or dir/): ", "", function(input)
    if not input or input == "" then return end
    local new_full = base_dir .. "/" .. input
    if input:match("/$") then
      vim.fn.mkdir(new_full, "p")
    else
      if not input:match("%.%w+$") then new_full = new_full .. ".md" end
      local f = io.open(new_full, "w")
      if f then
        f:write("# " .. vim.fn.fnamemodify(new_full, ":t:r") .. "\n"); f:close()
      end
    end
    M.refresh(true)
  end)
end

function M.rename_item()
  local full_path, _, _ = M.get_current_info()
  if not full_path then return end
  local old_name = vim.fn.fnamemodify(full_path, ":t")
  utils.input("Rename: ", old_name, function(new_name)
    if new_name and new_name ~= "" and new_name ~= old_name then
      local dir = vim.fn.fnamemodify(full_path, ":h")
      os.rename(full_path, dir .. "/" .. new_name)
      M.refresh(true)
    end
  end)
end

return M
