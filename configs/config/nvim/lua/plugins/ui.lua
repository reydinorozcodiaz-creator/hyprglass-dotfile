return {
  -- File Explorer (VS Code Sidebar)
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>e", ":NvimTreeToggle<CR>", silent = true, desc = "File explorer" },
    },
    config = function()
      require("nvim-tree").setup({
        view = {
            width = 30,
        },
        renderer = {
            group_empty = true,
        },
        filters = {
            dotfiles = false,
        },
      })
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
        mappings = {'<C-u>', '<C-d>', '<C-b>', '<C-y>', '<C-e>', 'zt', 'zz', 'zb'},
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
  },

  -- Gitsigns: indicadores git en el gutter (líneas verde/rojo/amarillo como VS Code)
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add          = { text = "▎" },
          change       = { text = "▎" },
          delete       = { text = "" },
          topdelete    = { text = "" },
          changedelete = { text = "▎" },
          untracked    = { text = "▎" },
        },
        current_line_blame = true,           -- muestra blame inline como VS Code GitLens
        current_line_blame_opts = {
          delay = 500,
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local map = function(mode, l, r, desc)
            vim.keymap.set(mode, l, r, { buffer = bufnr, silent = true, desc = desc })
          end
          map("n", "]g", gs.next_hunk, "Next git hunk")
          map("n", "[g", gs.prev_hunk, "Prev git hunk")
          map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
          map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
          map("n", "<leader>gb", gs.blame_line, "Blame line")
        end,
      })
    end,
  },

  -- Indent Blankline: guías de indentación verticales (VS Code style)
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("ibl").setup({
        indent = { char = "│" },
        scope  = { enabled = true, show_start = false },
      })
    end,
  },

  -- Which-key: muestra menú con sugerencias al presionar <leader>
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      local wk = require("which-key")
      wk.setup({
        preset = "modern",
        delay = 300,
        win = { border = "rounded" },
      })
      wk.add({
        { "<leader>f",  group = "Format / Find" },
        { "<leader>fg", desc = "Live grep" },
        { "<leader>ft", desc = "Find TODOs" },
        { "<leader>fw", desc = "Find word in project" },
        { "<leader>p",  desc = "Find files" },
        { "<leader>e",  desc = "File explorer" },
        { "<leader>o",  desc = "Toggle Outline" },
        { "<leader>rn", desc = "Rename symbol" },
        { "<leader>ca", desc = "Code action" },
        { "<leader>g",  group = "Git" },
        { "<leader>gg", desc = "Open LazyGit" },
        { "<leader>gp", desc = "Preview hunk" },
        { "<leader>gr", desc = "Reset hunk" },
        { "<leader>gb", desc = "Blame line" },
        { "<leader>q",  group = "Session" },
        { "<leader>qs", desc = "Restore session" },
        { "<leader>ql", desc = "Restore last session" },
        { "<leader>x",  group = "Diagnostics" },
        { "<leader>xx", desc = "Toggle diagnostics panel" },
        { "<leader>xb", desc = "Buffer diagnostics" },
        { "<leader>d",  group = "Debug" },
        { "<leader>db", desc = "Toggle breakpoint" },
        { "<leader>dc", desc = "Continue" },
        { "<leader>du", desc = "Toggle debug UI" },
        { "<leader>dt", desc = "Terminate" },
        { "<leader>r",  group = "Refactor" },
        { "<leader>re", desc = "Extract function" },
        { "<leader>rv", desc = "Extract variable" },
        { "<leader>ri", desc = "Inline variable" },
        { "<leader>m",  group = "Markdown" },
        { "<leader>mp", desc = "Toggle preview" },
        { "<leader>w",  group = "Window" },
        { "<leader>b",  group = "Buffer" },
      })
    end,
  },

  -- Noice: cmdline flotante + sugerencias de comando (VS Code command palette)
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    config = function()
      require("noice").setup({
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
          signature = { enabled = false },
        },
        presets = {
          bottom_search = false,
          command_palette = true,
          long_message_to_split = true,
          inc_rename = true,
        },
        cmdline = {
          enabled = true,
          view = "cmdline_popup",
          format = {
            cmdline     = { icon = ">" },
            search_down = { icon = "🔍" },
            search_up   = { icon = "🔍" },
            filter      = { icon = "$" },
            lua         = { icon = "☽" },
            help        = { icon = "?" },
          },
        },
        views = {
          cmdline_popup = {
            border = { style = "rounded" },
            position = { row = "40%", col = "50%" },
            size = { width = 60, height = "auto" },
          },
          popupmenu = {
            relative = "editor",
            position = { row = "43%", col = "50%" },
            size = { width = 60, height = 10 },
            border = { style = "rounded" },
          },
        },
      })
      require("notify").setup({
        background_colour = "NONE",
        render = "compact",
        timeout = 3000,
        top_down = false,
      })
    end,
  },

  -- Dashboard: pantalla de inicio con accesos recientes (VS Code Welcome)
  {
    "nvimdev/dashboard-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("dashboard").setup({
        theme = "hyper",
        config = {
          header = {
            "",
            "  ██╗  ██╗██╗   ██╗██████╗ ██████╗  ██████╗ ██╗      █████╗ ███████╗███████╗",
            "  ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔════╝ ██║     ██╔══██╗██╔════╝██╔════╝",
            "  ███████║ ╚████╔╝ ██████╔╝██████╔╝██║  ███╗██║     ███████║███████╗███████╗",
            "  ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║   ██║██║     ██╔══██║╚════██║╚════██║",
            "  ██║  ██║   ██║   ██║     ██║  ██║╚██████╔╝███████╗██║  ██║███████║███████║",
            "  ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝",
            "",
          },
          shortcut = {
            { desc = "  New File",      action = "enew",                        key = "n" },
            { desc = "  Find File",     action = "Telescope find_files",         key = "f" },
            { desc = "  Recent Files",  action = "Telescope oldfiles",           key = "r" },
            { desc = "  Find Word",     action = "Telescope live_grep",          key = "g" },
            { desc = "  Restore Session", action = function() require("persistence").load() end, key = "s" },
            { desc = "  Quit",          action = "qa",                          key = "q" },
          },
          footer = { "", "  HyprGlass Neovim" },
        },
      })
    end,
  },

  -- Fidget: spinner de carga LSP en la esquina (como VS Code statusbar)
  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    config = function()
      require("fidget").setup({
        notification = { window = { winblend = 0 } },
      })
    end,
  },

  -- Dressing: mejora vim.ui.input y vim.ui.select con popups bonitos
  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    config = function()
      require("dressing").setup({
        input = {
          border = "rounded",
          win_options = { winblend = 0 },
        },
        select = {
          backend = { "telescope", "builtin" },
        },
      })
    end,
  },
}