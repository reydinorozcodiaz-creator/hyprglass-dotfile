return {
  {
    "pmizio/typescript-tools.nvim",
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("typescript-tools").setup({
        settings = {
          tsserver_file_preferences = {
            includeInlayEnumMemberValueHints = true,
            includeInlayFunctionParameterTypeHints = true,
            includeInlayParameterNameHints = "all",
            includeInlayVariableTypeHints = true,
          },
          expose_as_code_action = {
            "fix_all",
            "add_missing_imports",
            "remove_unused_imports",
            "organize_imports",
          },
        },
      })

      vim.keymap.set("n", "<leader>To", "<cmd>TSToolsOrganizeImports<CR>", { silent = true, desc = "TS: Organize imports" })
      vim.keymap.set("n", "<leader>Ti", "<cmd>TSToolsAddMissingImports<CR>", { silent = true, desc = "TS: Add missing imports" })
      vim.keymap.set("n", "<leader>Tu", "<cmd>TSToolsRemoveUnusedImports<CR>", { silent = true, desc = "TS: Remove unused imports" })
      vim.keymap.set("n", "<leader>Tf", "<cmd>TSToolsFixAll<CR>", { silent = true, desc = "TS: Fix all" })
    end,
  },

  {
    "dmmulroy/ts-error-translator.nvim",
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    opts = {
      auto_override_publish_diagnostics = true,
    },
  },

  {
    "dmmulroy/tsc.nvim",
    cmd = "TSC",
    keys = {
      { "<leader>Tc", "<cmd>TSC<CR>", desc = "TS: Type-check project" },
    },
    opts = {
      auto_open_qflist = true,
      auto_close_qflist = false,
      auto_focus_qflist = false,
      auto_start_watch_mode = false,
      use_trouble_qflist = true,
      spinner = { "-", "\\", "|", "/" },
    },
  },
}
