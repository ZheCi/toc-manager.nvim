local M = {}
local config = require("toc-manager.config")
local core = require("toc-manager.core")

function M.setup(opts)
  config.options = vim.tbl_deep_extend("force", config.defaults, opts or {})

  vim.api.nvim_create_user_command('GenerateTOC', function()
    core.update()
  end, { desc = "Generate/Update TOC manually" })

  local group = vim.api.nvim_create_augroup("TOCManager", { clear = true })

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
    group = group,
    pattern = config.options.filename,
    callback = function()
      vim.schedule(core.update)

      local keys = config.options.keymaps
      local map_opts = { buffer = true, silent = true, noremap = true }
      local set = vim.keymap.set

      -- 1. 禁用所有进入插入模式的按键
      local ban_keys = { "i", "I", "a", "A", "o", "O", "c", "C", "s", "S", "cc" }
      local warn_func = function()
        vim.notify("🔒 TOC 文件为只读管理面板，请使用快捷键操作", vim.log.levels.WARN)
      end
      
      for _, key in ipairs(ban_keys) do
        set("n", key, warn_func, map_opts)
      end

      -- 2. 绑定功能按键
      if keys.copy    then set('n', keys.copy,    core.yank,   map_opts) end
      if keys.cut     then set('n', keys.cut,     core.cut,    map_opts) end
      if keys.delete  then set('n', keys.delete,  core.delete, map_opts) end
      if keys.paste   then set('n', keys.paste,   core.paste,  map_opts) end
      if keys.rename  then set('n', keys.rename,  core.rename, map_opts) end
      if keys.refresh then set('n', keys.refresh, core.update, map_opts) end
      if keys.create  then set('n', keys.create,  core.create, map_opts) end
    end,
  })
end

return M
