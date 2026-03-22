-- VS Code-style keymaps

-- File
vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<Esc><cmd>w<CR>", { silent = true, desc = "Save file" })
vim.keymap.set("n", "<C-n>", "<cmd>enew<CR>", { silent = true, desc = "New buffer" })

-- Edit
vim.keymap.set("n", "<C-z>", "u", { silent = true, desc = "Undo" })
vim.keymap.set("i", "<C-z>", "<Esc>ui", { silent = true, desc = "Undo" })
vim.keymap.set("n", "<C-y>", "<C-r>", { silent = true, desc = "Redo" })
vim.keymap.set("n", "<C-a>", "ggVG", { silent = true, desc = "Select all" })

vim.keymap.set("v", "<C-c>", '"+y', { silent = true, desc = "Copy to clipboard" })
vim.keymap.set("v", "<C-x>", '"+d', { silent = true, desc = "Cut to clipboard" })
vim.keymap.set("n", "<C-v>", '"+p', { silent = true, desc = "Paste from clipboard" })
vim.keymap.set("i", "<C-v>", "<C-r>+", { silent = true, desc = "Paste from clipboard" })
vim.keymap.set("v", "<C-v>", '"+P', { silent = true, desc = "Paste from clipboard" })

vim.keymap.set("n", "<A-Up>", "<cmd>m .-2<CR>==", { silent = true, desc = "Move line up" })
vim.keymap.set("n", "<A-Down>", "<cmd>m .+1<CR>==", { silent = true, desc = "Move line down" })
vim.keymap.set("v", "<A-Up>", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move selection up" })
vim.keymap.set("v", "<A-Down>", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move selection down" })

vim.keymap.set("n", "<A-S-Down>", "yyp", { silent = true, desc = "Duplicate line down" })
vim.keymap.set("v", "<A-S-Down>", "y'>p", { silent = true, desc = "Duplicate selection down" })

vim.keymap.set("v", "<Tab>", ">gv", { silent = true, desc = "Indent selection" })
vim.keymap.set("v", "<S-Tab>", "<gv", { silent = true, desc = "Dedent selection" })
vim.keymap.set("v", "<Del>", '"_d', { silent = true, desc = "Delete selection" })
vim.keymap.set("v", "<BS>", '"_d', { silent = true, desc = "Delete selection" })

-- Navigation
vim.keymap.set("n", "<C-Tab>", "<cmd>bnext<CR>", { silent = true, desc = "Next buffer" })
vim.keymap.set("n", "<C-S-Tab>", "<cmd>bprev<CR>", { silent = true, desc = "Previous buffer" })
vim.keymap.set("n", "<C-f>", "/", { desc = "Find in file" })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })

-- Terminal
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { silent = true, desc = "Exit terminal mode" })
