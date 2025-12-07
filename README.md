# 📖 Mark-TOC.nvim

A lightweight, Vim-like file manager specifically designed for Markdown notes.  
专为 Markdown 笔记打造的、符合 Vim 直觉的轻量级文件管理器。

Turn your `toc.md` (Table of Contents) into an interactive dashboard. Manage your notes (Create, Delete, Rename, Cut, Copy, Paste) without leaving the buffer.

将你的 `toc.md`（目录文件）变身为交互式管理面板。无需离开当前文件，即可完成笔记的增删改查、复制粘贴等操作。

## ✨ Features (功能特性)

- **Auto Generation**: Recursively scan directory and generate a categorized TOC.
  - **自动生成**: 递归扫描目录，自动生成分类好的目录树。
- **Vim-like Operations**: Use `yy`, `dd`, `p` to manage files just like text.
  - **Vim 式操作**: 像编辑文本一样使用 `yy`, `dd`, `p` 来管理文件。
- **Safety First**: `dd` performs a "visual cut" (soft delete), while `x` triggers a physical delete with confirmation.
  - **安全第一**: `dd` 仅执行“视觉剪切”（软删除），`x` 才会触发带确认的物理删除。
- **Read-Only Dashboard**: Blocks Insert Mode to prevent accidental modification of the TOC structure.
  - **只读面板**: 锁定插入模式，防止误触破坏目录结构。
- **Native & Fast**: Zero dependencies. Written in pure Lua.
  - **原生极速**: 零依赖，纯 Lua 编写。

## ⚡ Requirements (依赖)

- Neovim >= 0.9.0
- **Optional but Recommended (推荐搭配):**
  - [stevearc/dressing.nvim](https://github.com/stevearc/dressing.nvim) (Better UI for input/confirm)
  - [rcarriga/nvim-notify](https://github.com/rcarriga/nvim-notify) (Beautiful notifications)

## 📦 Installation (安装)

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "ZheCi/toc-manager.nvim",
  dependencies = {
    "stevearc/dressing.nvim", -- Optional
    "rcarriga/nvim-notify",   -- Optional
  },
  config = function()
    require("toc-manager").setup({
      -- Your custom config here
    })
  end
}
