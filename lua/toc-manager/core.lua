local M = {}
local config = require("toc-manager.config")
local utils = require("toc-manager.utils")

local clipboard = {
  action = nil,
  path = nil,
  filename = nil
}

-- 辅助函数：修改 Buffer 内容时的安全包装器
local function modify_buffer(bufnr, callback)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  
  -- 1. 临时解锁
  vim.bo[bufnr].modifiable = true
  
  -- 2. 执行修改操作
  callback()
  
  -- 3. 修改完立即保存并锁定
  vim.cmd('write')
  vim.bo[bufnr].modifiable = false
end

-- 生成 TOC
function M.update()
  local target_file = config.options.filename
  if vim.fn.expand('%:t') ~= target_file then return end

  local files = vim.fn.glob('**/*.md', true, true)
  local tree = {}
  
  for _, filepath in ipairs(files) do
    if filepath ~= target_file and not string.match(filepath, "/%.") then
      local dir = vim.fn.fnamemodify(filepath, ':h')
      if dir == '.' then dir = '📂 根目录' end
      if not tree[dir] then tree[dir] = {} end
      table.insert(tree[dir], filepath)
    end
  end

  local lines = {}
  table.insert(lines, '# ' .. config.options.title)
  table.insert(lines, '')

  local keys = config.options.keymaps or config.defaults.keymaps
  local help_text = string.format(
    '> [yy]复制 [dd]剪切 [p]粘贴 [x]删 [r]改名 [n]新建 [R]刷新'
  )
  table.insert(lines, help_text)
  
  if clipboard.action then
    local action_name = clipboard.action == "copy" and "复制" or "移动"
    table.insert(lines, string.format('> 📌 剪贴板: %s "%s"', action_name, clipboard.filename))
  end
  
  table.insert(lines, '')

  local dirs = {}
  for dir, _ in pairs(tree) do table.insert(dirs, dir) end
  table.sort(dirs)

  for _, dir in ipairs(dirs) do
    table.insert(lines, '## ' .. dir)
    local dir_files = tree[dir]
    table.sort(dir_files)
    for _, path in ipairs(dir_files) do
      local filename = vim.fn.fnamemodify(path, ':t:r')
      table.insert(lines, string.format('- [%s](./%s)', filename, path))
    end
    table.insert(lines, '')
  end

  local bufnr = vim.api.nvim_get_current_buf()
  
  -- 使用包装器更新内容
  modify_buffer(bufnr, function()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end)
end

-- [yy] 复制
function M.yank()
  local path, name = utils.get_path_under_cursor()
  if not path then return end

  clipboard = { action = "copy", path = path, filename = name }
  utils.notify("📋 已复制: " .. name .. " (按 p 粘贴)")
  M.update()
end

-- [dd] 剪切 (视觉删除)
function M.cut()
  local path, name = utils.get_path_under_cursor()
  if not path then return end

  clipboard = { action = "move", path = path, filename = name }
  
  -- 使用包装器删除当前行
  local bufnr = vim.api.nvim_get_current_buf()
  modify_buffer(bufnr, function()
    vim.api.nvim_del_current_line()
  end)
  
  utils.notify("✂️ 已剪切: " .. name .. " (按 p 移动，按 R 撤销)")
end

-- [x] 物理删除
function M.delete()
  local path, name = utils.get_path_under_cursor()
  if not path then return end

  local choice = vim.fn.confirm("🗑️ 永久删除: " .. name .. " ?", "&Yes\n&No", 2)
  if choice == 1 then
    if os.remove(path) then
      -- 使用包装器删除行
      local bufnr = vim.api.nvim_get_current_buf()
      modify_buffer(bufnr, function()
        vim.api.nvim_del_current_line()
      end)
      
      utils.notify("🗑️ 已物理删除: " .. name)
      if clipboard.path == path then clipboard = {} end
      M.update()
    else
      utils.notify("❌ 删除失败", vim.log.levels.ERROR)
    end
  end
end

-- 执行粘贴 IO
local function execute_paste(dest_path)
  local src = clipboard.path
  
  if clipboard.action == "copy" then
    local success, err = utils.copy_file(src, dest_path)
    if success then
      utils.notify("✅ 复制成功: " .. dest_path)
      M.update()
    else
      utils.notify("❌ 复制失败: " .. (err or ""), vim.log.levels.ERROR)
    end

  elseif clipboard.action == "move" then
    if vim.fn.filereadable(src) == 0 then
      utils.notify("❌ 源文件已不存在", vim.log.levels.ERROR)
      return
    end

    local success, err = os.rename(src, dest_path)
    if success then
      utils.notify("✅ 移动成功: " .. dest_path)
      clipboard = {} 
      M.update()
    else
      utils.notify("❌ 移动失败: " .. (err or ""), vim.log.levels.ERROR)
    end
  end
end

-- [p] 粘贴
function M.paste()
  if not clipboard.path or not clipboard.action then
    utils.notify("⚠️ 剪贴板为空", vim.log.levels.WARN)
    return
  end

  local target_ref_path, _ = utils.get_path_under_cursor()
  local target_dir
  if target_ref_path then
    target_dir = utils.get_dir_from_path(target_ref_path)
  else
    local line = vim.api.nvim_get_current_line()
    if line:match("^##%s+") then
       utils.notify("⚠️ 请将光标移到目标目录下的【任意文件】上", vim.log.levels.WARN)
       return
    else
       utils.notify("⚠️ 无法确定粘贴位置，请移到目标文件上", vim.log.levels.WARN)
       return
    end
  end

  local dest_path = target_dir .. "/" .. clipboard.filename

  if vim.fn.filereadable(dest_path) == 1 then
    utils.input("文件已存在，重命名为: ", "copy_" .. clipboard.filename, function(new_name)
      if new_name and new_name ~= "" then
        local new_dest = target_dir .. "/" .. new_name
        execute_paste(new_dest)
      end
    end)
  else
    execute_paste(dest_path)
  end
end

-- [r] 重命名
function M.rename()
  local path, name = utils.get_path_under_cursor()
  if not path then return end

  utils.input("重命名: ", name, function(new_name)
    if not new_name or new_name == "" or new_name == name then return end
    
    local dir = utils.get_dir_from_path(path)
    local new_path = dir .. "/" .. new_name
    
    local success, err = os.rename(path, new_path)
    if success then
      utils.notify("✏️ 重命名成功")
      M.update()
    else
      utils.notify("❌ 重命名失败: " .. (err or ""), vim.log.levels.ERROR)
    end
  end)
end

-- [n] 新建
function M.create()
  local target_ref_path, _ = utils.get_path_under_cursor()
  local base_dir = target_ref_path and utils.get_dir_from_path(target_ref_path) or "."

  utils.input("新建 (输入 x.md 或 dir/x.md): ", "", function(input_name)
    if not input_name or input_name == "" then return end
    
    local full_path = base_dir .. "/" .. input_name
    
    if input_name:match("/$") then
       if vim.fn.isdirectory(full_path) == 1 then
         utils.notify("目录已存在", vim.log.levels.WARN)
       else
         vim.fn.mkdir(full_path, "p")
         utils.notify("📁 目录已创建: " .. full_path)
         M.update()
       end
       return
    end

    local parent_dir = vim.fn.fnamemodify(full_path, ":h")
    if vim.fn.isdirectory(parent_dir) == 0 then
      vim.fn.mkdir(parent_dir, "p")
    end

    if vim.fn.filereadable(full_path) == 1 then
      utils.notify("⚠️ 文件已存在", vim.log.levels.WARN)
      return
    end

    local file = io.open(full_path, "w")
    if file then
      file:write("# " .. vim.fn.fnamemodify(full_path, ":t:r") .. "\n")
      file:close()
      utils.notify("✅ 文件已创建: " .. input_name)
      M.update()
    else
      utils.notify("❌ 创建失败", vim.log.levels.ERROR)
    end
  end)
end

return M
