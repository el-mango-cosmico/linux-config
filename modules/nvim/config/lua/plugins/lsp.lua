-- LSP, Treesitter, and Mason configuration
return {
  -- Treesitter: syntax highlighting and text objects
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "lua",
        "luadoc",
        "python",
        "typescript",
        "javascript",
        "tsx",
        "json",
        "jsonc",
        "yaml",
        "toml",
        "markdown",
        "markdown_inline",
        "regex",
        "vim",
        "vimdoc",
      },
    },
  },

  -- LSP servers
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},     -- Bash
        lua_ls = {},     -- Lua (nvim config)
        pyright = {},    -- Python
        ts_ls = {},      -- TypeScript / JavaScript
      },
    },
  },

  -- Mason: auto-install LSPs and formatters
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "bash-language-server",
        "lua-language-server",
        "pyright",
        "typescript-language-server",
        -- Formatters
        "prettier",
        "stylua",
        "shfmt",
        "black",
      },
    },
  },
}
