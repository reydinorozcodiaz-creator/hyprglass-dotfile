return {
  -- Mason: Installer for LSPs, Formatters, Linters
  {
      "williamboman/mason.nvim",
      config = function()
        require("mason").setup()
      end
  },
  
  -- Mason-LSPConfig
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
        require("mason-lspconfig").setup({
            ensure_installed = { "lua_ls", "ts_ls", "pyright", "html", "cssls" },
        })
    end
  },

  -- LSP Configuration & Integration
  {
      "neovim/nvim-lspconfig",
      dependencies = {
          "williamboman/mason.nvim",
          "williamboman/mason-lspconfig.nvim",
          "hrsh7th/cmp-nvim-lsp",
      },
      config = function()
          local lspconfig = require("lspconfig")
          local capabilities = require("cmp_nvim_lsp").default_capabilities()
          local mason_lspconfig = require("mason-lspconfig")

          -- Common Keybindings for LSP
          vim.keymap.set("n", "K", vim.lsp.buf.hover, {}) -- Hover doc
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, {}) -- Go to definition
          vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, {}) -- Code action

          -- Configure handlers
          mason_lspconfig.setup_handlers({
               -- The first entry (without a key) will be the default handler
               -- and will be called for each installed server that doesn_t have
               -- a dedicated handler.
               function (server_name) -- default handler (optional)
                   require("lspconfig")[server_name].setup {
                       capabilities = capabilities
                   }
               end,
               -- Next, you can provide a dedicated handler for specific servers.
               ["lua_ls"] = function ()
                   require("lspconfig").lua_ls.setup {
                       capabilities = capabilities,
                       settings = {
                           Lua = {
                               diagnostics = {
                                   globals = { "vim" }
                               }
                           }
                       }
                   }
               end,
          })
      end
  },

  -- Autocompletion Engine (The dropdown menu)
  {
      "hrsh7th/nvim-cmp",
      dependencies = {
        "hrsh7th/cmp-nvim-lsp",     -- LSP source
        "hrsh7th/cmp-buffer",       -- Buffer text source
        "hrsh7th/cmp-path",         -- Filesystem paths source
        "hrsh7th/cmp-cmdline",      -- Cmdline source
        "L3MON4D3/LuaSnip",         -- Snippet engine
        "saadparwaiz1/cmp_luasnip", -- Snippet source
        "rafamadriz/friendly-snippets", -- VS Code-like snippets
      },
      config = function()
          local cmp = require("cmp")
          local luasnip = require("luasnip")
          
          -- Load VS Code style snippets
          require("luasnip.loaders.from_vscode").lazy_load()

          cmp.setup({
              snippet = {
                  expand = function(args)
                      luasnip.lsp_expand(args.body)
                  end,
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
                  { name = "nvim_lsp" }, -- Sugerencias inteligentes del LSP
                  { name = "luasnip" },  -- Snippets
              }, {
                  { name = "buffer" },   -- Texto del archivo actual
                  { name = "path" },     -- Rutas de archivos
              })
          })
      end
  }
}
