-- Editor enhancements
return {
  -- Floating terminal — use <C-\> to toggle, or <leader>tt / <leader>ai
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      open_mapping = [[<C-\>]],
      direction = "float",
      float_opts = { border = "curved" },
      shell = vim.o.shell,
      -- Persist terminal sessions across toggles
      persist_mode = true,
    },
  },

  -- Better file explorer (LazyVim includes neo-tree; just tweaking defaults)
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          visible = true,       -- show hidden files (dimmed)
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
    },
  },

  -- Git signs in the gutter
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,          -- inline git blame
      current_line_blame_opts = {
        delay = 500,
      },
    },
  },
}
