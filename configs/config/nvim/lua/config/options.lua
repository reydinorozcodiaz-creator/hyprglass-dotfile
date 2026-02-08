-- Vim Options for VS Code feel
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.scrolloff = 8

-- Cursor styles
-- n-v-c-sm: block cursor with blinking
-- i-ci-ve: ver25 (vertical bar) cursor with blinking
-- r-cr-o: hor20 (horizontal underline) cursor with blinking
vim.opt.guicursor = "n-v-c-sm:block-blinkwait700-blinkon400-blinkoff250,i-ci-ve:ver25-blinkwait700-blinkon400-blinkoff250,r-cr-o:hor20-blinkwait700-blinkon400-blinkoff250"