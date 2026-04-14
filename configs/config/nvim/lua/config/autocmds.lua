local general = vim.api.nvim_create_augroup("UserGeneralAutocmds", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = general,
  desc = "Highlight yanked text",
  callback = function()
    vim.highlight.on_yank({ higroup = "Visual", timeout = 200 })
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = general,
  desc = "Auto-resize splits on window resize",
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  group = general,
  desc = "Remove trailing whitespace on save",
  pattern = {
    "*.lua",
    "*.py",
    "*.sh",
    "*.bash",
    "*.zsh",
    "*.js",
    "*.jsx",
    "*.ts",
    "*.tsx",
    "*.html",
    "*.css",
    "*.scss",
    "*.json",
    "*.yaml",
    "*.yml",
  },
  callback = function(args)
    if vim.bo[args.buf].buftype ~= "" or vim.bo[args.buf].binary then
      return
    end

    local excluded = {
      diff = true,
      markdown = true,
      text = true,
    }

    if excluded[vim.bo[args.buf].filetype] then
      return
    end

    local view = vim.fn.winsaveview()
    vim.api.nvim_buf_call(args.buf, function()
      vim.cmd([[keeppatterns %s/\s\+$//e]])
    end)
    vim.fn.winrestview(view)
  end,
})

vim.api.nvim_create_autocmd("BufEnter", {
  group = general,
  desc = "Auto-close NvimTree if last window",
  callback = function()
    if vim.api.nvim_win_get_config(0).relative ~= "" then
      return
    end

    local wins = vim.api.nvim_list_wins()
    local normal_wins = vim.tbl_filter(function(win)
      return vim.api.nvim_win_get_config(win).relative == ""
    end, wins)

    if #normal_wins == 1 and vim.bo.filetype == "NvimTree" then
      vim.cmd("quit")
    end
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = general,
  desc = "Restore cursor position",
  callback = function(args)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(args.buf) then
        return
      end

      if vim.bo[args.buf].filetype == "gitcommit" then
        return
      end

      local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
      local line_count = vim.api.nvim_buf_line_count(args.buf)

      if mark[1] > 0 and mark[1] <= line_count then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
    end)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = general,
  desc = "Set local options for writing buffers",
  pattern = { "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "es,en"
  end,
})

-- UI Transformation (Project HyprGlass)
local hyprglass = vim.api.nvim_create_augroup("HyprGlassUI", { clear = true })
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = hyprglass,
  callback = function()
    local highlights = {
      Normal = { bg = "none", ctermbg = "none" },
      NormalFloat = { bg = "none", ctermbg = "none" },
      FloatBorder = { fg = "#39BAE6", bg = "none" },
      Pmenu = { bg = "#0D1017", blend = 10 },
      PmenuSel = { bg = "#39BAE6", fg = "#0D1017" },
      LineNr = { fg = "#3E4B59", bg = "none" },
      CursorLineNr = { fg = "#39BAE6", bg = "none", bold = true },
      SignColumn = { bg = "none" },
      FoldColumn = { bg = "none" },
      StatusLine = { bg = "none" },
      StatusLineNC = { bg = "none" },
      WinSeparator = { fg = "#1F2430", bg = "none" },
      EndOfBuffer = { fg = "#0D1017", bg = "none" },
    }

    for group, opts in pairs(highlights) do
      vim.api.nvim_set_hl(0, group, opts)
    end
  end,
})
