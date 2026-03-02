return {
  -- Treesitter for better syntax highlighting (VS Code style syntax)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    config = function () 
      local status_ok, configs = pcall(require, "nvim-treesitter.configs")
      if not status_ok then
        return
      end
      
      configs.setup({
          ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "javascript", "typescript", "html", "css", "json", "python", "bash", "yaml", "markdown", "markdown_inline" },
          sync_install = false,
          highlight = { enable = true },
          indent = { enable = true },
          textobjects = {
            select = {
              enable = true,
              lookahead = true,
              keymaps = {
                ["af"] = { query = "@function.outer", desc = "Select outer function" },
                ["if"] = { query = "@function.inner", desc = "Select inner function" },
                ["ac"] = { query = "@class.outer",    desc = "Select outer class" },
                ["ic"] = { query = "@class.inner",    desc = "Select inner class" },
                ["aa"] = { query = "@parameter.outer", desc = "Select outer argument" },
                ["ia"] = { query = "@parameter.inner", desc = "Select inner argument" },
              },
            },
            move = {
              enable = true,
              set_jumps = true,
              goto_next_start     = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
              goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
            },
          },
      })
    end
  },

  -- Telescope (VS Code Ctrl+P style file search)
  {
    'nvim-telescope/telescope.nvim', branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    config = function()
        local telescope = require('telescope')
        local builtin = require('telescope.builtin')
        telescope.setup({
          extensions = { fzf = {} },
        })
        telescope.load_extension('fzf')
        vim.keymap.set('n', '<leader>p',  builtin.find_files, { silent = true, desc = "Find files" })
        vim.keymap.set('n', '<C-p>',      builtin.find_files, { silent = true, desc = "Find files" })
        vim.keymap.set('n', '<leader>fg', builtin.live_grep,  { silent = true, desc = "Live grep" })
    end
  },

  -- Auto-close brackets and quotes
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = true
  },

  -- Auto-close/rename HTML/JSX tags
  {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("nvim-ts-autotag").setup()
    end,
  },

  -- Surround: selecciona texto y rodéalo con (), [], "", etc. (VS Code behavior)
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup()
    end,
  },

  -- Flash: saltar a cualquier lugar del código con 2 letras
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    config = function()
      require("flash").setup()
    end,
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash jump" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash treesitter" },
    },
  },

  -- TODO comments: resalta TODO, FIXME, NOTE, etc.
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("todo-comments").setup()
      vim.keymap.set("n", "<leader>ft", ":TodoTelescope<CR>", { silent = true, desc = "Find TODOs" })
    end,
  },

  -- Spectre: buscar y reemplazar en todo el proyecto (Ctrl+Shift+H de VS Code)
  {
    "nvim-pack/nvim-spectre",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("spectre").setup()
      vim.keymap.set("n", "<C-S-h>", function() require("spectre").open() end, { silent = true, desc = "Find & Replace in project" })
      vim.keymap.set("n", "<leader>fw", function() require("spectre").open_visual({ select_word = true }) end, { silent = true, desc = "Find word in project" })
    end,
  },

  -- Persistence: guarda y restaura sesión automáticamente
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    config = function()
      require("persistence").setup()
      vim.keymap.set("n", "<leader>qs", function() require("persistence").load() end, { desc = "Restore session" })
      vim.keymap.set("n", "<leader>ql", function() require("persistence").load({ last = true }) end, { desc = "Restore last session" })
    end,
  },

  -- Lazygit: git visual completo dentro de Neovim (<leader>gg)
  {
    "kdheepak/lazygit.nvim",
    cmd = "LazyGit",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      vim.keymap.set("n", "<leader>gg", ":LazyGit<CR>", { silent = true, desc = "Open LazyGit" })
    end,
  },

  -- Trouble: panel de errores/warnings del proyecto (VS Code "Problems" Ctrl+Shift+M)
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("trouble").setup()
      vim.keymap.set("n", "<C-S-m>", ":Trouble diagnostics toggle<CR>", { silent = true, desc = "Toggle Problems panel" })
      vim.keymap.set("n", "<leader>xx", ":Trouble diagnostics toggle<CR>", { silent = true, desc = "Toggle diagnostics" })
      vim.keymap.set("n", "<leader>xb", ":Trouble diagnostics toggle filter.buf=0<CR>", { silent = true, desc = "Buffer diagnostics" })
    end,
  },

  -- Aerial: outline del archivo (funciones/clases) como VS Code Outline
  {
    "stevearc/aerial.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("aerial").setup({
        on_attach = function(bufnr)
          vim.keymap.set("n", "<leader>o", "<cmd>AerialToggle!<CR>", { buffer = bufnr, desc = "Toggle Outline" })
        end,
      })
      vim.keymap.set("n", "<leader>o", "<cmd>AerialToggle!<CR>", { desc = "Toggle Outline" })
    end,
  },

  -- UFO: folding moderno (colapsar/expandir funciones)
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    config = function()
      vim.o.foldcolumn = "1"
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true

      require("ufo").setup({
        provider_selector = function()
          return { "treesitter", "indent" }
        end,
      })

      vim.keymap.set("n", "zR", require("ufo").openAllFolds,  { desc = "Open all folds" })
      vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })
    end,
  },

  -- Refactoring: extraer funciones/variables desde selección visual
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("refactoring").setup()
      vim.keymap.set("v", "<leader>re", function() require("refactoring").refactor("Extract Function") end, { desc = "Extract Function" })
      vim.keymap.set("v", "<leader>rv", function() require("refactoring").refactor("Extract Variable") end, { desc = "Extract Variable" })
      vim.keymap.set("n", "<leader>ri", function() require("refactoring").refactor("Inline Variable") end, { desc = "Inline Variable" })
    end,
  },

  -- Markdown Preview: preview en el navegador en tiempo real
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function() vim.fn["mkdp#util#install"]() end,
    config = function()
      vim.keymap.set("n", "<leader>mp", ":MarkdownPreviewToggle<CR>", { silent = true, desc = "Toggle Markdown Preview" })
    end,
  },

  -- Illuminate: resalta ocurrencias de la palabra bajo el cursor
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("illuminate").configure({
        delay = 200,
        under_cursor = true,
        providers = { "lsp", "treesitter", "regex" },
      })
    end,
  },

  -- Comment lines: Ctrl+/ (VS Code style)
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("Comment").setup({
        toggler = { line = "<C-/>" },
        opleader = { line = "<C-/>" },
      })
    end,
  },
}