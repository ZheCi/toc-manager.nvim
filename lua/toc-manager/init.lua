local M = {}
local config = require("toc-manager.config")
local core = require("toc-manager.core")
local utils = require("toc-manager.utils")

local function warn_readonly()
  utils.notify("🔒 视图只读。按 '?' 查看快捷键。", vim.log.levels.WARN)
end

local function setup_buffer_keymaps(bufnr)
  local keys = config.options.keymaps
  local opts = { buffer = bufnr, silent = true, noremap = true, nowait = true }
  local function map(lhs, func, desc)
    if lhs and func then vim.keymap.set('n', lhs, func, vim.tbl_extend("force", opts, { desc = desc })) end
  end

  map(keys.refresh, core.refresh,      "Refresh TOC")
  map(keys.delete,  core.action_delete,"Move to Trash")
  map(keys.restore, core.action_restore,"Restore Last Deleted")
  map(keys.copy,    core.action_yank,  "Yank File")
  map(keys.paste,   core.action_paste, "Paste File")
  map(keys.create,  core.create_new,   "Create New")
  map(keys.rename,  core.rename_item,  "Rename")
  
  map(keys.help, function() 
    utils.notify("dd:删 u:恢复 yy/p:复制 a:建 r:改名") 
  end, "Help")

  -- [修改] 增加 J 到禁用列表
  local banned_keys = { 
    "i", "I", "a", "A", "O", 
    "c", "cc", "C", "s", "S", 
    "o", "J" -- 禁用 Join
  }
  
  local functional_keys = {
    [keys.refresh]=true, [keys.delete]=true, [keys.restore]=true,
    [keys.copy]=true, [keys.paste]=true, [keys.create]=true, [keys.rename]=true
  }
  
  for _, key in ipairs(banned_keys) do
    if not functional_keys[key] then
      vim.keymap.set('n', key, warn_readonly, opts)
    end
  end
end

function M.open()
  local filepath = core.cwd .. "/" .. config.options.filename
  if vim.fn.filereadable(filepath) == 0 then
    local f = io.open(filepath, "w"); if f then f:close() end
  end
  vim.cmd("edit " .. vim.fn.fnameescape(filepath))
  
  core.refresh(true)
end

function M.setup(opts)
  config.options = vim.tbl_deep_extend("force", config.defaults, opts or {})
  
  vim.api.nvim_create_user_command('TOC', function() M.open() end, {})
  vim.keymap.set('n', '<leader>t', function() M.open() end, { desc = "Open TOC" })

  local group = vim.api.nvim_create_augroup("TOCManager", { clear = true })
  
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*" .. config.options.filename,
    callback = function(args)
      vim.bo[args.buf].filetype = "markdown"
      vim.bo[args.buf].modifiable = false 
      setup_buffer_keymaps(args.buf)
      -- 每次进入重建 line_map
      vim.schedule(function() core.refresh(true) end)
    end
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    pattern = "*" .. config.options.filename,
    callback = function(args)
      vim.bo[args.buf].modified = false
      utils.notify("无需保存 (实时同步)")
    end
  })
end

return M
