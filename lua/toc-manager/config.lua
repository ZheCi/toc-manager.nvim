local M = {}

M.defaults = {
  filename = "toc.md",
  title = "📖 笔记目录",
  
  keymaps = {
    copy    = "yy",   -- 复制 (加入剪贴板)
    cut     = "dd",   -- 剪切 (加入剪贴板，视觉上删除行)
    paste   = "p",    -- 粘贴
    
    delete  = "x",    -- 物理删除 (弹出确认)
    
    rename  = "r",    -- 重命名
    create  = "n",    -- 新建文件/目录
    refresh = "R",    -- 刷新
  }
}

M.options = {}

return M
