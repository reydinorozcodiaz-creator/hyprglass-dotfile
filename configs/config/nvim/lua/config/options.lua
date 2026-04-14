-- Vim Options for VS Code feel
vim.g.mapleader = " "

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Mouse: fully enabled (click, scroll, resize splits like VS Code)
vim.opt.mouse = "a"
vim.opt.mousemoveevent = true   -- track mouse movement for hover
vim.opt.mousemodel = "extend"   -- right-click extends selection (VS Code behavior)

-- Clipboard: sync with system clipboard (Ctrl+C/V works across apps)
vim.opt.clipboard = "unnamedplus"

-- Colors & visuals
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"       -- always show sign column (no layout shift)
vim.opt.colorcolumn = ""         -- no color column

-- Indentation (VS Code defaults: 2 spaces)
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.autoindent = true

-- Scrolling
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Split behavior (VS Code: new splits open to the right/below)
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Performance
vim.opt.updatetime = 100         -- faster CursorHold (LSP hover, etc.)
vim.opt.timeoutlen = 300

-- Layout & UI (Project HyprGlass)
vim.opt.cmdheight = 0            -- hide command line when not used
vim.opt.laststatus = 3           -- global statusline (single bar at the bottom)
vim.opt.showmode = false         -- hide mode (lualine handles it)
vim.opt.showcmd = false          -- hide showing commands
vim.opt.shortmess:append("scI")  -- hide startup screen and extra info
vim.opt.fillchars = {
  eob = " ",                     -- hide ~ at end of buffer
  vert = " ",                    -- vertical split separator
  horiz = " ",                   -- horizontal split separator
  diff = " ",
  msgsep = " ",                  -- hide message separator
  fold = " ",
}

-- Misc
vim.opt.wrap = false             -- no line wrap (VS Code default)
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true          -- persistent undo history
vim.opt.conceallevel = 0

-- Cursor styles
-- n-v-c-sm: block cursor with blinking
-- i-ci-ve: ver25 (vertical bar) cursor with blinking
-- r-cr-o: hor20 (horizontal underline) cursor with blinking
vim.opt.guicursor = "n-v-c-sm:block-blinkwait700-blinkon400-blinkoff250,i-ci-ve:ver25-blinkwait700-blinkon400-blinkoff250,r-cr-o:hor20-blinkwait700-blinkon400-blinkoff250"

-- Nightly: silence specific noisy deprecation warnings
local suppressed_deprecations = {
  ["client.is_stopped"] = true,
  ["vim.highlight"] = true,
  ["vim.str_utfindex"] = true,
  ["vim.validate"] = true,
}

local original_deprecate = vim.deprecate
vim.deprecate = function(name, alternative, version, ...)
  if suppressed_deprecations[name] or (name and name:find("vim.validate")) then
    return
  end
  return original_deprecate(name, alternative, version, ...)
end

