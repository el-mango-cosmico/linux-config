-- AI integrations
--
-- Two options configured here:
--
-- 1. Avante (requires ANTHROPIC_API_KEY env var)
--    Full in-editor AI: chat sidebar, inline edits, code review
--    Keymaps: <leader>aa (ask), <leader>ae (edit), <leader>ar (refresh)
--
-- 2. Claude Code CLI via ToggleTerm (works with Claude Pro — no API key needed)
--    Keymap: <leader>ai  (defined in keymaps.lua)
--    Just opens your terminal with `claude` running

return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
    build = "make",
    opts = {
      provider = "claude",
      claude = {
        endpoint = "https://api.anthropic.com",
        model = "claude-sonnet-4-6",
        timeout = 30000,
        temperature = 0,
        max_tokens = 8096,
      },
      behaviour = {
        auto_suggestions = false,  -- keep it manual to avoid noise
        auto_apply_diff_after_generation = false,
        support_paste_from_clipboard = true,
      },
      hints = { enabled = true },
    },
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      {
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = { insert_mode = true },
          },
        },
      },
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = { file_types = { "markdown", "Avante" } },
        ft = { "markdown", "Avante" },
      },
    },
  },
}
