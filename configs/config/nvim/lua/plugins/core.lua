return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    config = function()
      local ok, configs = pcall(require, "nvim-treesitter.configs")
      if not ok then
        return
      end

      configs.setup({
        ensure_installed = {
          "bash",
          "c",
          "css",
          "html",
          "javascript",
          "json",
          "lua",
          "markdown",
          "markdown_inline",
          "python",
          "query",
          "typescript",
          "vim",
          "vimdoc",
          "yaml",
          "hyprlang",
        },
        sync_install = false,
        auto_install = false,
        highlight = { enable = true },
        indent = { enable = true },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = { query = "@function.outer", desc = "Select outer function" },
              ["if"] = { query = "@function.inner", desc = "Select inner function" },
              ["ac"] = { query = "@class.outer", desc = "Select outer class" },
              ["ic"] = { query = "@class.inner", desc = "Select inner class" },
              ["aa"] = { query = "@parameter.outer", desc = "Select outer argument" },
              ["ia"] = { query = "@parameter.inner", desc = "Select inner argument" },
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = {
              ["]f"] = "@function.outer",
              ["]c"] = "@class.outer",
            },
            goto_previous_start = {
              ["[f"] = "@function.outer",
              ["[c"] = "@class.outer",
            },
          },
        },
      })
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    keys = {
      {
        "<leader>p",
        function()
          require("telescope.builtin").find_files()
        end,
        desc = "Find files",
      },
      {
        "<C-p>",
        function()
          require("telescope.builtin").find_files()
        end,
        desc = "Find files",
      },
      {
        "<leader>fg",
        function()
          require("telescope.builtin").live_grep()
        end,
        desc = "Live grep",
      },
    },
    config = function()
      local telescope = require("telescope")

      telescope.setup({
        defaults = {
          path_display = { "smart" },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
        },
      })

      pcall(telescope.load_extension, "fzf")
    end,
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
  },

  {
    "windwp/nvim-ts-autotag",
    ft = {
      "astro",
      "html",
      "javascriptreact",
      "svelte",
      "typescriptreact",
      "vue",
    },
    config = function()
      require("nvim-ts-autotag").setup()
    end,
  },

  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup()
    end,
  },

  {
    "folke/flash.nvim",
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump()
        end,
        desc = "Flash jump",
      },
      {
        "S",
        mode = { "n", "x", "o" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash treesitter",
      },
    },
    opts = {},
  },

  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ft", "<cmd>TodoTelescope<CR>", desc = "Find TODOs" },
    },
    config = function()
      require("todo-comments").setup()
    end,
  },

  {
    "nvim-pack/nvim-spectre",
    cmd = "Spectre",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<C-S-h>",
        function()
          require("spectre").open()
        end,
        desc = "Find and replace in project",
      },
      {
        "<leader>fw",
        function()
          require("spectre").open_visual({ select_word = true })
        end,
        desc = "Find word in project",
      },
    },
    config = function()
      require("spectre").setup()
    end,
  },

  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    keys = {
      {
        "<leader>qs",
        function()
          require("persistence").load()
        end,
        desc = "Restore session",
      },
      {
        "<leader>ql",
        function()
          require("persistence").load({ last = true })
        end,
        desc = "Restore last session",
      },
    },
    config = function()
      require("persistence").setup()
    end,
  },

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    keys = {
      { "<C-S-m>", "<cmd>Trouble diagnostics toggle<CR>", desc = "Toggle problems panel" },
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", desc = "Toggle diagnostics" },
      { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Buffer diagnostics" },
    },
    config = function()
      require("trouble").setup({
        use_diagnostic_signs = true,
      })
    end,
  },

  {
    "stevearc/aerial.nvim",
    cmd = { "AerialOpen", "AerialClose", "AerialToggle" },
    keys = {
      { "<leader>lo", "<cmd>AerialToggle!<CR>", desc = "Toggle outline" },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("aerial").setup({
        layout = {
          min_width = 28,
        },
        show_guides = true,
      })
    end,
  },

  {
    "kevinhwang91/nvim-ufo",
    event = "BufReadPost",
    dependencies = { "kevinhwang91/promise-async" },
    init = function()
      vim.o.foldcolumn = "1"
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
    end,
    opts = {
      provider_selector = function()
        return { "treesitter", "indent" }
      end,
    },
    keys = {
      {
        "zR",
        function()
          require("ufo").openAllFolds()
        end,
        desc = "Open all folds",
      },
      {
        "zM",
        function()
          require("ufo").closeAllFolds()
        end,
        desc = "Close all folds",
      },
    },
  },

  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    keys = {
      {
        "<leader>re",
        mode = "v",
        function()
          require("refactoring").refactor("Extract Function")
        end,
        desc = "Extract function",
      },
      {
        "<leader>rv",
        mode = "v",
        function()
          require("refactoring").refactor("Extract Variable")
        end,
        desc = "Extract variable",
      },
      {
        "<leader>ri",
        mode = "n",
        function()
          require("refactoring").refactor("Inline Variable")
        end,
        desc = "Inline variable",
      },
    },
    config = function()
      require("refactoring").setup()
    end,
  },

  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("illuminate").configure({
        delay = 200,
        under_cursor = true,
        providers = { "lsp", "treesitter", "regex" },
      })
    end,
  },

  {
    "numToStr/Comment.nvim",
    keys = {
      { "<C-/>", mode = "n", desc = "Toggle comment" },
      { "<C-/>", mode = "v", desc = "Toggle comment" },
    },
    config = function()
      require("Comment").setup({
        toggler = { line = "<C-/>" },
        opleader = { line = "<C-/>" },
      })
    end,
  },

  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<leader>ha",
        function()
          require("harpoon"):list():add()
        end,
        desc = "Harpoon: add file",
      },
      {
        "<leader>hh",
        function()
          local harpoon = require("harpoon")
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,
        desc = "Harpoon: menu",
      },
      {
        "<leader>h1",
        function()
          require("harpoon"):list():select(1)
        end,
        desc = "Harpoon: file 1",
      },
      {
        "<leader>h2",
        function()
          require("harpoon"):list():select(2)
        end,
        desc = "Harpoon: file 2",
      },
      {
        "<leader>h3",
        function()
          require("harpoon"):list():select(3)
        end,
        desc = "Harpoon: file 3",
      },
      {
        "<leader>h4",
        function()
          require("harpoon"):list():select(4)
        end,
        desc = "Harpoon: file 4",
      },
    },
    config = function()
      require("harpoon"):setup()
    end,
  },

  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    dependencies = { "stevearc/dressing.nvim" },
    opts = {
      input_buffer_type = "dressing",
    },
  },

  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    config = function()
      require("bqf").setup({
        preview = {
          winblend = 0,
          border = "rounded",
        },
      })
    end,
  },

  {
    "chrisgrieser/nvim-spider",
    keys = {
      {
        "w",
        function()
          require("spider").motion("w")
        end,
        mode = { "n", "o", "x" },
        desc = "Spider-w",
      },
      {
        "e",
        function()
          require("spider").motion("e")
        end,
        mode = { "n", "o", "x" },
        desc = "Spider-e",
      },
      {
        "b",
        function()
          require("spider").motion("b")
        end,
        mode = { "n", "o", "x" },
        desc = "Spider-b",
      },
      {
        "ge",
        function()
          require("spider").motion("ge")
        end,
        mode = { "n", "o", "x" },
        desc = "Spider-ge",
      },
    },
  },

  {
    "michaelb/sniprun",
    build = "sh install.sh",
    cmd = { "SnipRun", "SnipClose", "SnipReset" },
    keys = {
      { "<leader>rr", "<cmd>SnipRun<CR>", mode = { "n", "v" }, desc = "Run snippet" },
      { "<leader>rR", "<cmd>SnipReset<CR>", desc = "Reset SnipRun" },
      { "<leader>rc", "<cmd>SnipClose<CR>", desc = "Close SnipRun output" },
    },
    opts = {
      display = { "NvimNotify" },
      display_options = { notify_timeout = 5 },
      repl_enable = {},
    },
  },

  {
    "echasnovski/mini.bufremove",
    version = "*",
    keys = {
      {
        "<C-w>q",
        function()
          require("mini.bufremove").delete(0, false)
        end,
        desc = "Close buffer",
      },
    },
    config = function()
      require("mini.bufremove").setup()
    end,
  },
}
