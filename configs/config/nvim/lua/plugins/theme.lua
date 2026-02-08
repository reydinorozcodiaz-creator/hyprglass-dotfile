return {
  -- Theme: Ayu
  {
    "Shatur/neovim-ayu",
    lazy = false,
    priority = 1000,
    config = function()
      -- Configure ayu options
      require('ayu').setup({
        mirage = false, 
        overrides = {
             -- Manual transparency overrides if needed
             Normal = { bg = "none" },
             ColorColumn = { bg = "none" },
             SignColumn = { bg = "none" },
             Folded = { bg = "none" },
             FoldColumn = { bg = "none" },
             CursorLine = { bg = "none" },
             CursorColumn = { bg = "none" },
             WhichKeyFloat = { bg = "none" },
             VertSplit = { bg = "none" },
        },
      })
      
      -- Load the colorscheme
      vim.cmd.colorscheme "ayu"

      -- Force transparency on top of the theme
      vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
      vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
      vim.api.nvim_set_hl(0, "Pmenu", { bg = "none" })
      
      -- Additional transparency for standard groups
      vim.cmd([[
        hi Normal guibg=NONE ctermbg=NONE
        hi LineNr guibg=NONE ctermbg=NONE
        hi SignColumn guibg=NONE ctermbg=NONE
        hi EndOfBuffer guibg=NONE ctermbg=NONE
      ]])
    end,
  },
}