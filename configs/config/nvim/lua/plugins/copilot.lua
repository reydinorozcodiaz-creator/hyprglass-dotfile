return {
  -- GitHub Copilot
  {
    "github/copilot.vim",
    event = "InsertEnter",
    config = function()
      -- Disable default Tab mapping (we handle it in cmp)
      vim.g.copilot_no_tab_map = true

      -- Accept suggestion with Ctrl+J (keeps Tab free for cmp)
      vim.keymap.set("i", "<C-j>", 'copilot#Accept("\\<CR>")', {
        expr = true,
        replace_keycodes = false,
        silent = true,
        desc = "Copilot: Accept suggestion",
      })

      -- Navigate suggestions
      vim.keymap.set("i", "<C-]>", "<Plug>(copilot-next)", { silent = true, desc = "Copilot: Next suggestion" })
      vim.keymap.set("i", "<M-[>", "<Plug>(copilot-prev)", { silent = true, desc = "Copilot: Prev suggestion" })

      -- Dismiss suggestion
      vim.keymap.set("i", "<M-e>", "<Plug>(copilot-dismiss)", { silent = true, desc = "Copilot: Dismiss" })
    end,
  },
}
