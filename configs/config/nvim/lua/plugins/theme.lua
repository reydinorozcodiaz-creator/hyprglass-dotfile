local project = require("config.project")

return {
  {
    "Shatur/neovim-ayu",
    lazy = false,
    priority = 1000,
    config = function()
      local variant = project.theme_variant()
      vim.o.background = variant == "light" and "light" or "dark"

      require("ayu").setup({
        mirage = variant == "mirage",
        overrides = {
          ColorColumn = { bg = "none" },
          CursorColumn = { bg = "none" },
          CursorLine = { bg = "none" },
          FoldColumn = { bg = "none" },
          Folded = { bg = "none" },
          Normal = { bg = "none" },
          SignColumn = { bg = "none" },
          VertSplit = { bg = "none" },
          WhichKeyFloat = { bg = "none" },
        },
      })

      vim.cmd.colorscheme("ayu")

      vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
      vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
      vim.api.nvim_set_hl(0, "Pmenu", { bg = "none" })
    end,
  },
}
