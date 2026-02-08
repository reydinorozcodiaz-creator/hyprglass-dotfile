return {
  -- File Explorer (VS Code Sidebar)
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = {
            width = 30,
        },
        renderer = {
            group_empty = true,
        },
        filters = {
            dotfiles = true,
        },
      })
      -- Open file explorer with <leader>e
      vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { silent = true })
    end,
  },

  -- Tabs (VS Code Tabs)
  {
    'akinsho/bufferline.nvim', 
    version = "*", 
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
        require("bufferline").setup({
            options = {
                style_preset = require("bufferline").style_preset.minimal,
                always_show_bufferline = true,
                -- Attempt to match ayu theme or keep transparent
                separator_style = "thin",
            }
        })
    end
  },

  -- Status Line (VS Code bottom bar style)
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
        require('lualine').setup({
            options = {
                theme = 'ayu', -- Use ayu theme for status line too
                component_separators = '|',
                section_separators = '',
            }
        })
    end
  },

  -- Smooth Scrolling (VS Code style)
  {
    "karb94/neoscroll.nvim",
    config = function()
      require('neoscroll').setup({
        -- All these keys will be mapped to their corresponding default scrolling animation
        mappings = {'<C-u>', '<C-d>', '<C-b>', '<C-f>', '<C-y>', '<C-e>', 'zt', 'zz', 'zb'},
        hide_cursor = true,          -- Hide cursor while scrolling
        stop_eof = true,             -- Stop at <EOF>
        respect_scrolloff = false,   -- Stop scrolling when the cursor reaches the scrolloff margin of the file
        cursor_scrolls_alone = true, -- The cursor will keep on scrolling even if the window cannot scroll further
        easing_function = "quadratic", -- Default easing function
      })
    end
  },

  -- Smooth Cursor Trail (VS Code smooth cursor effect)
  {
      "sphamba/smear-cursor.nvim",
      opts = {},
  }
}