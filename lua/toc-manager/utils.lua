local M = {}
-- [关键] 只引用 config，切勿引用 core，防止循环依赖
local config = require("toc-manager.config")

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "TOC Manager" })
end

function M.get_stem(filename)
  return filename:match("(.+)%.%w+$") or filename
end

function M.ensure_trash_dir(cwd)
  local trash = cwd .. "/" .. config.options.behavior.trash_dir
  if vim.fn.isdirectory(trash) == 0 then vim.fn.mkdir(trash, "p") end
  return trash
end

-- 获取相对路径
function M.get_relative_path(base, target)
  if base:sub(-1) ~= "/" then base = base .. "/" end
  local start, finish = target:find(base, 1, true)
  if start == 1 then
    return "./" .. target:sub(finish + 1)
  end
  return target
end

-- 解析行信息
function M.parse_info_from_line(line)
  if not line or line == "" then return nil, nil end
  -- 文件匹配: [Label](URL)
  local url = line:match("%[.-%]%((.-)%)")
  if url then
    local path = url:gsub("%%20", " ")
    if path:sub(1, 2) ~= "./" then path = "./" .. path end
    return path, "file"
  end
  -- 目录匹配: 📂 Name/
  local dir_name = line:match("[📂📁]%s*(.+)//$")
  if dir_name then return dir_name, "dir" end
  return nil, nil
end

function M.input(prompt, default, cb) vim.ui.input({ prompt = prompt, default = default }, cb) end

function M.copy_file(src, dest)
  if vim.fn.filereadable(src) == 0 then return false end
  local content = vim.fn.readfile(src)
  vim.fn.writefile(content, dest)
  return true
end

function M.extract_tags(filepath)
  local f = io.open(filepath, "r"); if not f then return {} end
  local lines = {}; local c=0; for l in f:lines() do table.insert(lines, l); c=c+1; if c>50 then break end end; f:close()
  local tags = {}; local seen = {}
  for _, line in ipairs(lines) do
    local content = line:match("^[Tt]ag:%s*(.+)$")
    if content then
      content = content:gsub("，", ",")
      for t in content:gmatch("[^,]+") do
        local clean = t:match("^%s*(.-)%s*$")
        if clean and clean~="" and not seen[clean] then table.insert(tags, clean); seen[clean]=true end
      end
    end
  end
  return tags
end

return M
