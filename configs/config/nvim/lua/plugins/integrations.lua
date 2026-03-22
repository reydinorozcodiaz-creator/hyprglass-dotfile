local project = require("config.project")
local features = require("config.features")

local function with_package_info(callback)
  return function()
    if vim.fn.expand("%:t") ~= "package.json" then
      vim.notify("package-info.nvim is meant for package.json files.", vim.log.levels.WARN)
      return
    end

    callback(require("package-info"))
  end
end

return {
  {
    "tpope/vim-dadbod",
    enabled = features.enabled("database"),
    cmd = { "DB", "DBUI", "DBUIToggle", "DBUIAddConnection" },
  },

  {
    "kristijanhusak/vim-dadbod-ui",
    enabled = features.enabled("database"),
    dependencies = {
      "tpope/vim-dadbod",
      { "kristijanhusak/vim-dadbod-completion", ft = { "mysql", "plsql", "sql" }, lazy = true },
    },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    keys = {
      { "<leader>Db", "<cmd>DBUIToggle<CR>", desc = "DB: toggle UI" },
      { "<leader>Da", "<cmd>DBUIAddConnection<CR>", desc = "DB: add connection" },
      { "<leader>Df", "<cmd>DBUIFindBuffer<CR>", desc = "DB: find buffer" },
    },
    init = function()
      vim.g.db_ui_force_echo_notifications = 1
      vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_win_position = "left"
      vim.g.db_ui_winwidth = 35
    end,
  },

  {
    "mistweaverco/kulala.nvim",
    ft = { "http", "rest" },
    keys = {
      {
        "<leader>Rr",
        function()
          require("kulala").run()
        end,
        desc = "HTTP: run request",
      },
      {
        "<leader>Ra",
        function()
          require("kulala").run_all()
        end,
        desc = "HTTP: run all",
      },
      {
        "<leader>Rs",
        function()
          require("kulala").scratchpad()
        end,
        desc = "HTTP: scratchpad",
      },
      {
        "<leader>Ri",
        function()
          require("kulala").inspect()
        end,
        desc = "HTTP: inspect",
      },
      {
        "<leader>Rn",
        function()
          require("kulala").jump_next()
        end,
        desc = "HTTP: next request",
      },
      {
        "<leader>Rp",
        function()
          require("kulala").jump_prev()
        end,
        desc = "HTTP: previous request",
      },
    },
    opts = {
      default_view = "body",
      default_env = "dev",
      debug = false,
      display_mode = "float",
      split_direction = "vertical",
      icons = {
        inlay = {
          loading = "*",
          done = "v",
        },
        lualine = "HTTP",
      },
    },
  },

  {
    "vuki656/package-info.nvim",
    ft = "json",
    dependencies = { "MunifTanjim/nui.nvim" },
    keys = {
      {
        "<leader>np",
        with_package_info(function(package_info)
          package_info.toggle()
        end),
        desc = "Package: toggle versions",
      },
      {
        "<leader>nu",
        with_package_info(function(package_info)
          package_info.update()
        end),
        desc = "Package: update",
      },
      {
        "<leader>nd",
        with_package_info(function(package_info)
          package_info.delete()
        end),
        desc = "Package: delete",
      },
      {
        "<leader>ni",
        with_package_info(function(package_info)
          package_info.install()
        end),
        desc = "Package: install",
      },
    },
    config = function()
      require("package-info").setup({
        autostart = false,
        colors = {
          up_to_date = "#3C4048",
          outdated = "#F07178",
        },
      })
    end,
  },

  {
    "wakatime/vim-wakatime",
    enabled = features.enabled("wakatime"),
    event = "VimEnter",
  },
}
