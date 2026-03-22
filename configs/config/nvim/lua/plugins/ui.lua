local project = require("config.project")
local features = require("config.features")

return {
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeFindFile", "NvimTreeFocus", "NvimTreeToggle" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>e", "<cmd>NvimTreeToggle<CR>", desc = "File explorer" },
    },
    opts = {
      disable_netrw = true,
      hijack_netrw = true,
      view = {
        width = 30,
      },
      renderer = {
        group_empty = true,
      },
      filters = {
        dotfiles = false,
      },
      git = { enable = true },
    },
  },

  {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          style_preset = require("bufferline").style_preset.minimal,
          always_show_bufferline = true,
          separator_style = "thin",
          numbers = "ordinal",
        },
      })

      for i = 1, 9 do
        vim.keymap.set("n", "<leader>" .. i, function()
          require("bufferline").go_to(i, true)
        end, { silent = true, desc = "Go to buffer " .. i })
      end
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local mode_colors = {
        n = { bg = "#39BAE6", fg = "#0D1017" },
        i = { bg = "#7FD962", fg = "#0D1017" },
        v = { bg = "#FFB454", fg = "#0D1017" },
        V = { bg = "#FFB454", fg = "#0D1017" },
        ["\22"] = { bg = "#FFB454", fg = "#0D1017" },
        c = { bg = "#D2A6FF", fg = "#0D1017" },
        R = { bg = "#F07178", fg = "#0D1017" },
        s = { bg = "#F07178", fg = "#0D1017" },
      }

      require("lualine").setup({
        options = {
          theme = "ayu",
          component_separators = "|",
          section_separators = "",
        },
        sections = {
          lualine_a = {
            {
              "mode",
              color = function()
                return mode_colors[vim.fn.mode():sub(1, 1)] or { bg = "#39BAE6", fg = "#0D1017" }
              end,
            },
          },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })
    end,
  },

  {
    "karb94/neoscroll.nvim",
    enabled = features.enabled("ui_fx"),
    event = "VeryLazy",
    opts = {
      mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-y>", "<C-e>", "zt", "zz", "zb" },
      hide_cursor = true,
      stop_eof = true,
      respect_scrolloff = false,
      cursor_scrolls_alone = true,
      easing_function = "quadratic",
    },
  },

  {
    "sphamba/smear-cursor.nvim",
    enabled = features.enabled("ui_fx"),
    event = "VeryLazy",
    opts = {},
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "|" },
      scope = { enabled = true, show_start = false },
    },
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      local wk = require("which-key")
      local entries = {
        { "<leader>fg", desc = "Live grep" },
        { "<leader>ft", desc = "Find TODOs" },
        { "<leader>fw", desc = "Find word in project" },
        { "<leader>p", desc = "Find files" },
        { "<leader>e", desc = "File explorer" },
        { "<leader>f", desc = "Format file" },
        { "<leader>lo", desc = "Toggle outline" },
        { "<leader>rn", desc = "Rename symbol" },
        { "<leader>ca", desc = "Code action" },
        { "<leader>q", group = "Session" },
        { "<leader>qs", desc = "Restore session" },
        { "<leader>ql", desc = "Restore last session" },
        { "<leader>x", group = "Diagnostics" },
        { "<leader>xx", desc = "Toggle diagnostics" },
        { "<leader>xb", desc = "Buffer diagnostics" },
        { "<leader>g", group = "Git" },
        { "<leader>gg", desc = "Open LazyGit" },
        { "<leader>gd", desc = "Git diff view" },
        { "<leader>gh", desc = "Git file history" },
        { "<leader>gD", desc = "Close diff view" },
        { "<leader>gp", desc = "Preview hunk" },
        { "<leader>gr", desc = "Reset hunk" },
        { "<leader>gb", desc = "Blame line" },
        { "<leader>gB", desc = "Toggle blame" },
        { "<leader>h", group = "Harpoon" },
        { "<leader>ha", desc = "Harpoon add file" },
        { "<leader>hh", desc = "Harpoon menu" },
        { "<leader>h1", desc = "Harpoon file 1" },
        { "<leader>h2", desc = "Harpoon file 2" },
        { "<leader>h3", desc = "Harpoon file 3" },
        { "<leader>h4", desc = "Harpoon file 4" },
        { "<leader>r", group = "Refactor / Run" },
        { "<leader>re", desc = "Extract function" },
        { "<leader>rv", desc = "Extract variable" },
        { "<leader>ri", desc = "Inline variable" },
        { "<leader>rr", desc = "Run snippet" },
        { "<leader>rR", desc = "Reset SnipRun" },
        { "<leader>rc", desc = "Close SnipRun output" },
        { "<leader>t", group = "Test / Terminal" },
        { "<leader>tt", desc = "Run nearest test" },
        { "<leader>tf", desc = "Run file tests" },
        { "<leader>ts", desc = "Toggle test summary" },
        { "<leader>to", desc = "Open test output" },
        { "<leader>tS", desc = "Stop tests" },
        { "<leader>tF", desc = "Open floating terminal" },
        { "<leader>tw", desc = "Toggle Twilight" },
        { "<leader>T", group = "TypeScript" },
        { "<leader>To", desc = "TS: organize imports" },
        { "<leader>Ti", desc = "TS: add missing imports" },
        { "<leader>Tu", desc = "TS: remove unused imports" },
        { "<leader>Tf", desc = "TS: fix all" },
        { "<leader>Tc", desc = "TS: type-check project" },
        { "<leader>a", group = "AI" },
        { "<leader>ac", desc = "AI: chat" },
        { "<leader>aa", desc = "AI: actions" },
        { "<leader>ai", desc = "AI: inline edit" },
        { "<leader>ao", desc = "AI: local model" },
        { "<leader>n", group = "NPM / Package" },
        { "<leader>np", desc = "Package: toggle versions" },
        { "<leader>nu", desc = "Package: update" },
        { "<leader>nd", desc = "Package: delete" },
        { "<leader>ni", desc = "Package: install" },
        { "<leader>R", group = "HTTP Requests" },
        { "<leader>Rr", desc = "HTTP: run request" },
        { "<leader>Ra", desc = "HTTP: run all" },
        { "<leader>Rs", desc = "HTTP: scratchpad" },
        { "<leader>Ri", desc = "HTTP: inspect" },
        { "<leader>Rn", desc = "HTTP: next request" },
        { "<leader>Rp", desc = "HTTP: previous request" },
        { "<leader>cp", desc = "Color picker" },
        { "<leader>z", desc = "Toggle Zen Mode" },
        { "<leader>.", desc = "Scratch buffer" },
        { "<leader>S", desc = "Select scratch" },
        { "gpd", desc = "Preview definition" },
        { "gpt", desc = "Preview type definition" },
        { "gpi", desc = "Preview implementation" },
        { "gpr", desc = "Preview references" },
        { "gP", desc = "Close previews" },
      }

      if project.enable_database() then
        vim.list_extend(entries, {
          { "<leader>D", group = "Database" },
          { "<leader>Db", desc = "DB: toggle UI" },
          { "<leader>Da", desc = "DB: add connection" },
          { "<leader>Df", desc = "DB: find buffer" },
        })
      end

      if project.obsidian_path() then
        vim.list_extend(entries, {
          { "<leader>o", group = "Notes" },
          { "<leader>of", desc = "Notes: find note" },
          { "<leader>on", desc = "Notes: new note" },
          { "<leader>os", desc = "Notes: search" },
          { "<leader>ob", desc = "Notes: backlinks" },
          { "<leader>ot", desc = "Notes: template" },
          { "<leader>oc", desc = "Notes: toggle checkbox" },
        })
      end

      wk.setup({
        preset = "modern",
        delay = 300,
        win = { border = "rounded" },
      })
      wk.add(entries)
    end,
  },

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
            ["cmp.entry.get_documentation"] = true,
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
          },
          signature = { enabled = false },
        },
        presets = {
          bottom_search = false,
          command_palette = true,
          inc_rename = true,
          long_message_to_split = true,
        },
        cmdline = {
          enabled = true,
          view = "cmdline_popup",
        },
        views = {
          cmdline_popup = {
            border = { style = "rounded" },
            position = { row = "40%", col = "50%" },
            size = { width = 60, height = "auto" },
          },
          popupmenu = {
            border = { style = "rounded" },
            position = { row = "43%", col = "50%" },
            relative = "editor",
            size = { width = 60, height = 10 },
          },
        },
      })

      require("notify").setup({
        background_colour = "#0D1017",
        render = "compact",
        timeout = 3000,
        top_down = false,
      })
    end,
  },

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
            "  HyprGlass Neovim",
            "",
          },
          shortcut = {
            { desc = "  New File", action = "enew", key = "n" },
            { desc = "  Find File", action = "Telescope find_files", key = "f" },
            { desc = "  Recent Files", action = "Telescope oldfiles", key = "r" },
            { desc = "  Find Word", action = "Telescope live_grep", key = "g" },
            {
              desc = "  Restore Session",
              action = function()
                require("lazy").load({ plugins = { "persistence.nvim" } })
                require("persistence").load()
              end,
              key = "s",
            },
            { desc = "  Quit", action = "qa", key = "q" },
          },
          footer = { "", "  HyprGlass Neovim" },
        },
      })
    end,
  },

  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    opts = {
      notification = { window = { winblend = 0 } },
    },
  },

  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = {
      input = {
        border = "rounded",
        win_options = { winblend = 0 },
      },
      select = {
        backend = { "telescope", "builtin" },
      },
    },
  },

  {
    "NvChad/nvim-colorizer.lua",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("colorizer").setup({
        filetypes = { "*" },
        user_default_options = {
          RGB = true,
          RRGGBB = true,
          css = true,
          css_fn = true,
          mode = "background",
          names = false,
          tailwind = true,
        },
      })
    end,
  },

  {
    "folke/twilight.nvim",
    enabled = features.enabled("ui_fx"),
    cmd = { "Twilight", "TwilightDisable", "TwilightEnable" },
    keys = {
      { "<leader>tw", "<cmd>Twilight<CR>", desc = "Toggle Twilight" },
    },
    opts = {
      dimming = { alpha = 0.25 },
      context = 15,
    },
  },

  {
    "folke/zen-mode.nvim",
    enabled = features.enabled("ui_fx"),
    cmd = "ZenMode",
    keys = {
      { "<leader>z", "<cmd>ZenMode<CR>", desc = "Toggle Zen Mode" },
    },
    opts = {
      window = {
        backdrop = 0.93,
        width = 100,
        options = {
          number = false,
          relativenumber = false,
          signcolumn = "no",
        },
      },
      plugins = {
        gitsigns = { enabled = false },
        twilight = { enabled = true },
      },
    },
  },

  {
    "HiPhish/rainbow-delimiters.nvim",
    enabled = features.enabled("ui_fx"),
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local rainbow = require("rainbow-delimiters")
      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rainbow.strategy["global"],
        },
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
        },
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
    end,
  },

  {
    "petertriho/nvim-scrollbar",
    enabled = features.enabled("ui_fx"),
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("scrollbar").setup({
        handle = { color = "#3E4B59" },
        marks = {
          Error = { text = { "E" } },
          Warn = { text = { "W" } },
          Info = { text = { "I" } },
          Hint = { text = { "H" } },
          GitAdd = { text = "|" },
          GitChange = { text = "|" },
          GitDelete = { text = "_" },
        },
        handlers = {
          gitsigns = true,
          search = false,
        },
      })
    end,
  },

  {
    "echasnovski/mini.animate",
    enabled = features.enabled("ui_fx"),
    version = "*",
    event = "VeryLazy",
    config = function()
      require("mini.animate").setup({
        scroll = { enable = false },
        cursor = { enable = false },
        resize = { enable = true },
        open = { enable = true },
        close = { enable = true },
      })
    end,
  },

  {
    "uga-rosa/ccc.nvim",
    enabled = features.enabled("ui_fx"),
    cmd = { "CccConvert", "CccHighlighterToggle", "CccPick" },
    keys = {
      { "<leader>cp", "<cmd>CccPick<CR>", desc = "Color picker" },
    },
    config = function()
      require("ccc").setup({
        highlighter = {
          auto_enable = false,
          lsp = true,
        },
      })
    end,
  },

  {
    "akinsho/toggleterm.nvim",
    version = "*",
    cmd = { "TermExec", "ToggleTerm" },
    keys = {
      { "<C-`>", desc = "Toggle terminal" },
      {
        "<leader>tF",
        function()
          require("toggleterm.terminal").Terminal:new({ direction = "float" }):toggle()
        end,
        desc = "Open floating terminal",
      },
    },
    opts = {
      size = 15,
      open_mapping = [[<C-`>]],
      direction = "horizontal",
      shade_terminals = false,
      persist_size = true,
      close_on_exit = true,
      shell = vim.o.shell,
      float_opts = { border = "rounded" },
      winbar = { enabled = false },
    },
  },

  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = { enabled = true },
      input = { enabled = false },
      scratch = { enabled = true },
      words = { enabled = false },
      scroll = { enabled = false },
      notifier = { enabled = false },
      statuscolumn = { enabled = true },
      indent = { enabled = false },
      dashboard = { enabled = false },
    },
    keys = {
      {
        "<leader>.",
        function()
          require("snacks").scratch()
        end,
        desc = "Scratch buffer",
      },
      {
        "<leader>S",
        function()
          require("snacks").scratch.select()
        end,
        desc = "Select scratch",
      },
    },
  },
}
