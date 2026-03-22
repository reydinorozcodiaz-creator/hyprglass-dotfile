local project = require("config.project")
local settings = project.get().ai

if not project.feature_enabled("ai") then
  return {}
end

return {
  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
      filetypes = { ["*"] = true },
    },
  },

  {
    "zbirenbaum/copilot-cmp",
    event = "InsertEnter",
    dependencies = { "zbirenbaum/copilot.lua" },
    config = function()
      require("copilot_cmp").setup()
    end,
  },

  {
    "olimorris/codecompanion.nvim",
    cmd = { "CodeCompanion", "CodeCompanionActions", "CodeCompanionChat" },
    dependencies = {
      "MunifTanjim/nui.nvim",
      "hrsh7th/nvim-cmp",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    keys = {
      { "<leader>ac", "<cmd>CodeCompanionChat<CR>", mode = { "n", "v" }, desc = "AI: chat" },
      { "<leader>aa", "<cmd>CodeCompanionActions<CR>", mode = { "n", "v" }, desc = "AI: actions" },
      { "<leader>ai", "<cmd>CodeCompanion<CR>", mode = "v", desc = "AI: inline edit" },
    },
    opts = function()
      return {
        strategies = {
          chat = { adapter = settings.chat_adapter },
          inline = { adapter = settings.inline_adapter },
          agent = { adapter = settings.agent_adapter },
        },
        adapters = {
          anthropic = function()
            return require("codecompanion.adapters").extend("anthropic", {
              env = { api_key = "ANTHROPIC_API_KEY" },
            })
          end,
          openai = function()
            return require("codecompanion.adapters").extend("openai", {
              env = { api_key = "OPENAI_API_KEY" },
              schema = {
                model = { default = settings.openai_model },
              },
            })
          end,
        },
        display = {
          chat = {
            window = {
              layout = "vertical",
              width = 0.35,
              border = "rounded",
            },
          },
        },
      }
    end,
  },

  {
    "David-Kunz/gen.nvim",
    cmd = "Gen",
    keys = {
      { "<leader>ao", "<cmd>Gen<CR>", mode = { "n", "v" }, desc = "AI: local model" },
    },
    opts = {
      model = settings.ollama_model,
      host = settings.ollama_host,
      port = settings.ollama_port,
      display_mode = "float",
      show_prompt = true,
      show_model = true,
      no_auto_close = false,
    },
  },
}
