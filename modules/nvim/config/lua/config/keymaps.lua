-- Custom keymaps (LazyVim defaults: https://www.lazyvim.org/keymaps)
-- Add your own below — LazyVim handles most common mappings already.

local map = vim.keymap.set

-- Quick escape from terminal mode
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Open a floating terminal (for Claude Code CLI etc.)
map("n", "<leader>tt", "<cmd>ToggleTerm direction=float<cr>", { desc = "Toggle floating terminal" })
map("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", { desc = "Toggle horizontal terminal" })

-- Claude Code shortcut — opens terminal with claude pre-typed (you hit enter)
map("n", "<leader>ai", function()
  local Terminal = require("toggleterm.terminal").Terminal
  local claude = Terminal:new({ cmd = "claude", direction = "float", hidden = true })
  claude:toggle()
end, { desc = "Open Claude Code" })
