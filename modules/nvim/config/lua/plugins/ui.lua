-- UI / theme configuration
return {
  -- Colorscheme: tokyonight (LazyVim default, just configuring it)
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      transparent = false,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
    },
  },

  -- Dashboard: show on empty nvim launch
  {
    "nvimdev/dashboard-nvim",
    opts = {
      config = {
        header = {
          "                                          ",
          "  ███╗   ██╗██╗   ██╗██╗███╗   ███╗    ",
          "  ████╗  ██║██║   ██║██║████╗ ████║    ",
          "  ██╔██╗ ██║██║   ██║██║██╔████╔██║    ",
          "  ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║    ",
          "  ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║    ",
          "  ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝    ",
          "                                          ",
        },
      },
    },
  },
}
