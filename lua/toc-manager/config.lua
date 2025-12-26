local M = {}

M.defaults = {
  filename = "toc.md",
  title = "# 🗃️ 知识库索引",

  behavior = {
    filters = {
      show_hidden = false,
      exclude_dirs = { ".git", "node_modules", ".obsidian", ".trash", ".delete" },
    },
    tags = { enable = true, prefix = " `🏷️ " },
    trash_dir = ".delete",
  },
  
  icons = { dir = "📂 ", file = "📄 " },

  keymaps = {
    refresh     = "R",
    delete      = "dd",
    copy        = "yy",
    paste       = "p",
    restore     = "u",
    create      = "a",
    rename      = "r",
    help        = "?",
    
    -- [关键] 显式定义打开键，配合 init.lua 使用
    open        = "o",
  }
}

M.options = {}

return M
