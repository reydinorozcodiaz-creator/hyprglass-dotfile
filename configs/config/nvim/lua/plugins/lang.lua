return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "luvit-meta/library", words = { "vim%.uv" } },
      },
    },
  },

  { "Bilal2453/luvit-meta", lazy = true },
  { "b0o/SchemaStore.nvim", lazy = true },

  {
    "rmagatti/goto-preview",
    event = "LspAttach",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("goto-preview").setup({
        width = 120,
        height = 25,
        default_mappings = false,
        references = {
          telescope = require("telescope.themes").get_dropdown({ hide_preview = false }),
        },
      })

      local gp = require("goto-preview")
      vim.keymap.set("n", "gpd", gp.goto_preview_definition, { desc = "Preview: definition" })
      vim.keymap.set("n", "gpt", gp.goto_preview_type_definition, { desc = "Preview: type definition" })
      vim.keymap.set("n", "gpi", gp.goto_preview_implementation, { desc = "Preview: implementation" })
      vim.keymap.set("n", "gpr", gp.goto_preview_references, { desc = "Preview: references" })
      vim.keymap.set("n", "gP", gp.close_all_win, { desc = "Preview: close all" })
    end,
  },

  {
    "Wansmer/symbol-usage.nvim",
    event = "LspAttach",
    config = function()
      require("symbol-usage").setup({
        vt_position = "end_of_line",
        request_pending_text = false,
        references = { enabled = true, include_declaration = false },
        definition = { enabled = false },
        implementation = { enabled = true },
        text_format = function(symbol)
          local result = {}
          if not symbol.references or symbol.references == 0 then
            return result
          end

          local usage = symbol.references == 1 and "ref" or "refs"
          table.insert(result, { "  " .. tostring(symbol.references) .. " " .. usage, "Comment" })

          if symbol.implementation and symbol.implementation > 0 then
            table.insert(result, { " | " .. tostring(symbol.implementation) .. " impl", "Comment" })
          end

          return result
        end,
      })
    end,
  },

  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "LspAttach",
    config = function()
      require("tiny-inline-diagnostic").setup({
        preset = "modern",
        hi = {
          error = "DiagnosticError",
          warn = "DiagnosticWarn",
          info = "DiagnosticInfo",
          hint = "DiagnosticHint",
        },
        blend = { factor = 0.27 },
        options = {
          show_source = false,
          use_icons_from_diagnostic = false,
          show_all_diags_on_cursorline = true,
          throttle = 20,
          multilines = {
            enabled = true,
            always_show = false,
          },
        },
      })
    end,
  },

  {
    "ray-x/lsp_signature.nvim",
    event = "LspAttach",
    opts = {
      bind = true,
      handler_opts = { border = "rounded" },
      hint_enable = true,
      hint_prefix = "=> ",
      hi_parameter = "LspSignatureActiveParameter",
      toggle_key = "<C-k>",
      floating_window = true,
      floating_window_above_cur_line = true,
      transparency = 10,
      shadow_blend = 36,
    },
  },

  {
    "williamboman/mason.nvim",
    lazy = false,
    build = ":MasonUpdate",
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            package_installed = "+",
            package_pending = ">",
            package_uninstalled = "-",
          },
        },
      })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "b0o/SchemaStore.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      vim.diagnostic.config({
        virtual_text = false,
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "E",
            [vim.diagnostic.severity.WARN] = "W",
            [vim.diagnostic.severity.INFO] = "I",
            [vim.diagnostic.severity.HINT] = "H",
          },
        },
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = { border = "rounded", source = "if_many" },
      })

      local lsp_group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true })
      vim.api.nvim_create_autocmd("LspAttach", {
        group = lsp_group,
        callback = function(event)
          local buf = event.buf
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, {
              buffer = buf,
              noremap = true,
              silent = true,
              desc = desc,
            })
          end

          map("n", "K", vim.lsp.buf.hover, "Hover documentation")
          map("n", "gd", vim.lsp.buf.definition, "Go to definition")
          map("n", "gr", vim.lsp.buf.references, "Find references")
          map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
          map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("n", "[d", vim.diagnostic.goto_prev, "Previous diagnostic")
          map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
          map("i", "<C-k>", vim.lsp.buf.signature_help, "Signature help")

          vim.keymap.set("n", "<leader>rn", function()
            return ":IncRename " .. vim.fn.expand("<cword>")
          end, {
            buffer = buf,
            noremap = true,
            expr = true,
            desc = "Rename symbol",
          })
        end,
      })

      local function configure(server, opts)
        vim.lsp.config(server, opts or {})
        vim.lsp.enable(server)
      end

      local servers = { "bashls", "cssls", "eslint", "html", "pyright" }
      for _, server in ipairs(servers) do
        configure(server, {
          capabilities = capabilities,
        })
      end

      configure("jsonls", {
        capabilities = capabilities,
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      })

      configure("lua_ls", {
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
          },
        },
      })
    end,
  },

  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "L3MON4D3/LuaSnip",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "rafamadriz/friendly-snippets",
      "saadparwaiz1/cmp_luasnip",
      "zbirenbaum/copilot-cmp",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        preselect = cmp.PreselectMode.Item,
        completion = {
          completeopt = "menu,menuone,noinsert",
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "copilot", priority = 110 },
          { name = "nvim_lsp", priority = 100 },
          { name = "luasnip", priority = 90 },
        }, {
          { name = "buffer", keyword_length = 3 },
          { name = "path" },
        }),
      })

      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" },
        },
      })

      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = "path" },
        }, {
          { name = "cmdline", option = { ignore_cmds = { "Man", "!" } } },
        }),
        matching = { disallow_symbol_nonprefix_matching = false },
      })
    end,
  },

  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    keys = {
      {
        "<leader>f",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        desc = "Format file",
      },
    },
    config = function()
      local conform = require("conform")
      local formatters_by_ft = {
        bash = { "shfmt" },
        css = { "prettier" },
        html = { "prettier" },
        javascript = { "prettier" },
        json = { "prettier" },
        lua = { "stylua" },
        python = { "black" },
        sh = { "shfmt" },
        typescript = { "prettier" },
      }

      conform.setup({
        formatters_by_ft = formatters_by_ft,
        format_on_save = function(bufnr)
          if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return
          end

          if not formatters_by_ft[vim.bo[bufnr].filetype] then
            return
          end

          return {
            timeout_ms = 750,
            lsp_format = "fallback",
          }
        end,
      })

      vim.api.nvim_create_user_command("FormatDisable", function(args)
        if args.bang then
          vim.g.disable_autoformat = true
        else
          vim.b.disable_autoformat = true
        end
      end, { bang = true, desc = "Disable autoformat-on-save" })

      vim.api.nvim_create_user_command("FormatEnable", function()
        vim.g.disable_autoformat = false
        vim.b.disable_autoformat = false
      end, { desc = "Enable autoformat-on-save" })
    end,
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local lint = require("lint")
      local linters_by_ft = {
        javascript = { "eslint_d" },
        python = { "pylint" },
        typescript = { "eslint_d" },
      }

      lint.linters_by_ft = linters_by_ft

      local lint_group = vim.api.nvim_create_augroup("UserLinting", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        group = lint_group,
        callback = function(args)
          if vim.bo[args.buf].buftype ~= "" then
            return
          end

          if not linters_by_ft[vim.bo[args.buf].filetype] then
            return
          end

          pcall(lint.try_lint)
        end,
      })
    end,
  },
}
