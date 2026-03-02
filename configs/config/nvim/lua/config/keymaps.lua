-- VS Code-style keymaps

-- Save: Ctrl+S
vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<Esc>:w<CR>", { silent = true, desc = "Save file" })

-- Undo/Redo: Ctrl+Z / Ctrl+Y (insert & normal)
vim.keymap.set("n", "<C-z>", "u", { silent = true, desc = "Undo" })
vim.keymap.set("i", "<C-z>", "<Esc>ui", { silent = true, desc = "Undo" })
vim.keymap.set("n", "<C-y>", "<C-r>", { silent = true, desc = "Redo" })

-- Select All: Ctrl+A
vim.keymap.set("n", "<C-a>", "ggVG", { silent = true, desc = "Select all" })

-- Cut/Copy/Paste with system clipboard (already handled by unnamedplus, but explicit)
vim.keymap.set("v", "<C-c>", '"+y', { silent = true, desc = "Copy to clipboard" })
vim.keymap.set("v", "<C-x>", '"+d', { silent = true, desc = "Cut to clipboard" })
vim.keymap.set({ "n", "i", "v" }, "<C-v>", '<Esc>"+P', { silent = true, desc = "Paste from clipboard" })

-- Close buffer: Ctrl+W
vim.keymap.set("n", "<C-w>q", ":bd<CR>", { silent = true, desc = "Close buffer" })

-- New file: Ctrl+N
vim.keymap.set("n", "<C-n>", ":enew<CR>", { silent = true, desc = "New buffer" })

-- Switch between buffers: Ctrl+Tab / Ctrl+Shift+Tab (like VS Code tabs)
vim.keymap.set("n", "<C-Tab>", ":bnext<CR>", { silent = true, desc = "Next buffer" })
vim.keymap.set("n", "<C-S-Tab>", ":bprev<CR>", { silent = true, desc = "Previous buffer" })

-- Move lines up/down: Alt+Up / Alt+Down (VS Code classic)
vim.keymap.set("n", "<A-Up>", ":m .-2<CR>==", { silent = true, desc = "Move line up" })
vim.keymap.set("n", "<A-Down>", ":m .+1<CR>==", { silent = true, desc = "Move line down" })
vim.keymap.set("v", "<A-Up>", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move selection up" })
vim.keymap.set("v", "<A-Down>", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move selection down" })

-- Duplicate line: Alt+Shift+Down (VS Code)
vim.keymap.set("n", "<A-S-Down>", "yyp", { silent = true, desc = "Duplicate line down" })
vim.keymap.set("v", "<A-S-Down>", "y'>p", { silent = true, desc = "Duplicate selection down" })

-- Comment line: Ctrl+/ (requires Comment.nvim, set up in editor.lua)
-- (handled by Comment.nvim plugin below)

-- Toggle terminal: Ctrl+` (backtick, like VS Code)
vim.keymap.set({ "n", "t" }, "<C-`>", function()
  local found = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "terminal" then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then
          vim.api.nvim_win_close(win, false)
          found = true
        end
      end
    end
  end
  if not found then
    vim.cmd("botright 15split | terminal")
    vim.cmd("startinsert")
  end
end, { silent = true, desc = "Toggle terminal" })

-- Exit terminal mode with Esc (like VS Code integrated terminal)
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { silent = true, desc = "Exit terminal mode" })

-- Find in file: Ctrl+F (goes to / search)
vim.keymap.set("n", "<C-f>", "/", { desc = "Find in file" })

-- Clear search highlight: Escape in normal mode
vim.keymap.set("n", "<Esc>", ":nohl<CR>", { silent = true, desc = "Clear search highlight" })

-- Indent/dedent in visual mode keeping selection: Tab / Shift+Tab
vim.keymap.set("v", "<Tab>", ">gv", { silent = true, desc = "Indent selection" })
vim.keymap.set("v", "<S-Tab>", "<gv", { silent = true, desc = "Dedent selection" })

-- Delete/Backspace in visual mode actually deletes selection (VS Code behavior)
vim.keymap.set("v", "<Del>", '"_d', { silent = true, desc = "Delete selection" })
vim.keymap.set("v", "<BS>", '"_d', { silent = true, desc = "Delete selection" })
