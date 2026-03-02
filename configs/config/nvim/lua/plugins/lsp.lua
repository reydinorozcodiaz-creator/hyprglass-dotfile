return {
  -- Mason: Installer for LSPs, Formatters, Linters
  {
      "williamboman/mason.nvim",
      build = ":MasonUpdate",
      config = function()
        local mason = require("mason")
        mason.setup({
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗"
                }
            }
        })
        
        -- Setup tool installers with auto-install
        require("mason-tool-installer").setup({
            ensure_installed = {
                "lua_ls", "ts_ls", "pyright", "html", "cssls", "eslint",
                "prettier", "black", "stylua", "eslint_d", "pylint",
                "bash-language-server", "shfmt",
            },
            auto_update = false,
            run_on_start = false,
        })
      end,
      dependencies = {
          "WhoIsSethDaniel/mason-tool-installer.nvim",
      }
  },
  
  -- Mason-LSPConfig
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
        "williamboman/mason.nvim",
    },
    config = function()
        require("mason-lspconfig").setup({
            ensure_installed = { "lua_ls", "ts_ls", "pyright", "html", "cssls", "eslint", "bashls" },
            automatic_installation = true,
        })
    end
  },

  -- LSP Configuration & Integration
  {
      "neovim/nvim-lspconfig",
      dependencies = {
          "hrsh7th/cmp-nvim-lsp",
      },
      config = function()
          local capabilities = require("cmp_nvim_lsp").default_capabilities()
          local function configure_server(server, opts)
              vim.lsp.config(server, opts or {})
              vim.lsp.enable(server)
          end
          
          -- Enable signature help in insert mode
          capabilities.signatureHelpProvider = true

          -- Configure diagnostics appearance
          vim.diagnostic.config({
              virtual_text = true,
              signs = true,
              underline = true,
              update_in_insert = false,
              severity_sort = true,
          })

          -- Common Keybindings for LSP (only active when an LSP server attaches)
          vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(event)
              local buf = event.buf
              local map = function(mode, lhs, rhs, desc)
                vim.keymap.set(mode, lhs, rhs, { buffer = buf, noremap = true, silent = true, desc = desc })
              end
              map("n", "K",          vim.lsp.buf.hover,          "Hover doc")
              map("n", "gd",         vim.lsp.buf.definition,     "Go to definition")
              map("n", "gr",         vim.lsp.buf.references,     "Find references")
              map("n", "gi",         vim.lsp.buf.implementation, "Go to implementation")
              map("n", "<leader>rn", vim.lsp.buf.rename,         "Rename symbol")
              map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
              map("n", "[d",         vim.diagnostic.goto_prev,   "Previous diagnostic")
              map("n", "]d",         vim.diagnostic.goto_next,   "Next diagnostic")
              map("i", "<C-k>",      vim.lsp.buf.signature_help, "Signature help")
            end,
          })

          -- Default setup for all servers
          local servers = { "ts_ls", "pyright", "html", "cssls", "bashls", "eslint" }
          for _, server in ipairs(servers) do
              configure_server(server, {
                  capabilities = capabilities,
              })
          end

          -- Lua LS with special config
          configure_server("lua_ls", {
              capabilities = capabilities,
              settings = {
                  Lua = {
                      diagnostics = {
                          globals = { "vim" }
                      }
                  }
              }
          })

      end
  },

  -- Autocompletion Engine (The dropdown menu)
  {
      "hrsh7th/nvim-cmp",
      dependencies = {
        "hrsh7th/cmp-nvim-lsp",     -- LSP source
        "hrsh7th/cmp-nvim-lsp-signature-help", -- Signature help source
        "hrsh7th/cmp-buffer",       -- Buffer text source
        "hrsh7th/cmp-path",         -- Filesystem paths source
        "hrsh7th/cmp-cmdline",      -- Cmdline source
        "L3MON4D3/LuaSnip",         -- Snippet engine
        "saadparwaiz1/cmp_luasnip", -- Snippet source
        "rafamadriz/friendly-snippets", -- VS Code-style snippets collection
      },
      config = function()
          local cmp = require("cmp")
          local luasnip = require("luasnip")

          -- Load VS Code-style snippets from friendly-snippets
          require("luasnip.loaders.from_vscode").lazy_load()

          cmp.setup({
              snippet = {
                  expand = function(args)
                      luasnip.lsp_expand(args.body)
                  end,
              },
              preselect = cmp.PreselectMode.Item,
              completion = {
                  completeopt = "menu,menuone,preview",
              },
              window = {
                  completion = cmp.config.window.bordered(),
                  documentation = cmp.config.window.bordered(),
              },
              mapping = cmp.mapping.preset.insert({
                  ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                  ["<C-f>"] = cmp.mapping.scroll_docs(4),
                  ["<C-Space>"] = cmp.mapping.complete(), -- Open menu manually
                  ["<C-e>"] = cmp.mapping.abort(),
                  ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Enter to confirm
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
                  { name = "nvim_lsp", priority = 100 },
                  { name = "nvim_lsp_signature_help", priority = 90 },
                  { name = "luasnip", priority = 80 },
              }, {
                  { name = "buffer", keyword_length = 3 },
                  { name = "path" },
              })
          })

          -- Autocompletado en cmdline "/" y "?" (buscar en buffer)
          cmp.setup.cmdline({ "/", "?" }, {
              mapping = cmp.mapping.preset.cmdline(),
              sources = {
                  { name = "buffer" },
              },
          })

          -- Autocompletado en cmdline ":" (comandos de Neovim)
          cmp.setup.cmdline(":", {
              mapping = cmp.mapping.preset.cmdline(),
              sources = cmp.config.sources({
                  { name = "path" },
              }, {
                  { name = "cmdline", option = { ignore_cmds = { "Man", "!" } } },
              }),
              matching = { disallow_symbol_nonprefix_matching = false },
          })
      end
  },

  -- Formatter Integration
  {
      "stevearc/conform.nvim",
      config = function()
          local conform = require("conform")
          
          conform.setup({
              formatters_by_ft = {
                  lua = { "stylua" },
                  javascript = { "prettier" },
                  typescript = { "prettier" },
                  html = { "prettier" },
                  css = { "prettier" },
                  json = { "prettier" },
                  python = { "black" },
                  bash = { "shfmt" },
                  sh = { "shfmt" },
              },
              format_on_save = {
                  timeout_ms = 500,
                  lsp_format = "fallback",
              },
          })
          
          -- Format with <leader>f (unified keybind via conform)
          vim.keymap.set({ "n", "v" }, "<leader>f", function()
              conform.format({ async = true, lsp_fallback = true })
          end, { silent = true, desc = "Format file" })
      end
  },

  -- Linting
  {
      "mfussenegger/nvim-lint",
      config = function()
          local lint = require("lint")
          
          lint.linters_by_ft = {
              javascript = { "eslint_d" },
              typescript = { "eslint_d" },
              python = { "pylint" },
          }
          
          -- Auto-lint on save
          vim.api.nvim_create_autocmd({ "BufWritePost" }, {
              callback = function()
                  lint.try_lint()
              end,
          })
      end
  },
}
