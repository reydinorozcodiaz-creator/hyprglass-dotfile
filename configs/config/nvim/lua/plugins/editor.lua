return {
  -- Treesitter for better syntax highlighting (VS Code style syntax)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPre", "BufNewFile" },
    config = function () 
      local status_ok, configs = pcall(require, "nvim-treesitter.configs")
      if not status_ok then
        return
      end
      
      configs.setup({
          ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "javascript", "html", "python" },
          sync_install = false,
          highlight = { enable = true },
          indent = { enable = true },  
      })
    end
  },

  -- Telescope (VS Code Ctrl+P style file search)
  {
    'nvim-telescope/telescope.nvim', tag = '0.1.6',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>p', builtin.find_files, {}) -- Visualmente similar a Ctrl+p
        vim.keymap.set('n', '<C-p>', builtin.find_files, {}) -- Mapeo real de Ctrl+p
        vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
    end
  },

  -- Auto-close brackets and quotes
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = true
    -- use opts = {} for passing setup options
    -- this is equivalent to setup({}) function
  }
}