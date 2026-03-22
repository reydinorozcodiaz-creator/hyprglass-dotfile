local project = require("config.project")
local obsidian_path = project.obsidian_path()

return {
  {
    "OXY2DEV/markview.nvim",
    ft = { "markdown", "md" },
    submodules = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("markview").setup({
        preview = {
          enable = true,
          filetypes = { "markdown", "md" },
          modes = { "n", "no", "c" },
          hybrid_modes = { "n" },
        },
      })
    end,
  },

  {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown" },
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<CR>", desc = "Toggle Markdown preview" },
    },
    build = function()
      if vim.fn.executable("npm") == 1 then
        vim.fn["mkdp#util#install"]()
      end
    end,
  },

  {
    "epwalsh/obsidian.nvim",
    enabled = project.feature_enabled("notes") and obsidian_path ~= nil,
    version = "*",
    ft = "markdown",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    keys = {
      { "<leader>of", "<cmd>ObsidianQuickSwitch<CR>", desc = "Notes: find note" },
      { "<leader>on", "<cmd>ObsidianNew<CR>", desc = "Notes: new note" },
      { "<leader>os", "<cmd>ObsidianSearch<CR>", desc = "Notes: search" },
      { "<leader>ob", "<cmd>ObsidianBacklinks<CR>", desc = "Notes: backlinks" },
      { "<leader>ot", "<cmd>ObsidianTemplate<CR>", desc = "Notes: template" },
      { "<leader>oc", "<cmd>ObsidianToggleCheckbox<CR>", desc = "Notes: toggle checkbox" },
    },
    opts = {
      workspaces = {
        {
          name = "personal",
          path = obsidian_path,
        },
      },
      completion = { nvim_cmp = true, min_chars = 2 },
      mappings = {},
      new_notes_location = "current_dir",
      wiki_link_func = "use_alias_only",
      templates = { subdir = "templates", date_format = "%Y-%m-%d" },
      ui = {
        enable = true,
        update_debounce = 200,
        checkboxes = {
          [" "] = { char = "[ ]", hl_group = "ObsidianTodo" },
          ["x"] = { char = "[x]", hl_group = "ObsidianDone" },
          [">"] = { char = "[>]", hl_group = "ObsidianRightArrow" },
        },
        bullets = { char = "-", hl_group = "ObsidianBullet" },
        hl_groups = {
          ObsidianTodo = { bold = true, fg = "#f78c6c" },
          ObsidianDone = { bold = true, fg = "#89ddff" },
          ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
          ObsidianBullet = { bold = true, fg = "#89ddff" },
          ObsidianRefText = { underline = true, fg = "#c792ea" },
          ObsidianExtLinkIcon = { fg = "#c792ea" },
          ObsidianTag = { italic = true, fg = "#89ddff" },
          ObsidianHighlightText = { bg = "#75662e" },
        },
      },
    },
  },
}
