local map = vim.keymap.set

map("n", "<C-h>", "<C-w>h", { desc = "Move focus left" })
map("n", "<C-j>", "<C-w>j", { desc = "Move focus down" })
map("n", "<C-k>", "<C-w>k", { desc = "Move focus up" })
map("n", "<C-l>", "<C-w>l", { desc = "Move focus right" })

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

map("n", "<leader>e", "<cmd>Lexplore<CR>", { desc = "Toggle file explorer" })
