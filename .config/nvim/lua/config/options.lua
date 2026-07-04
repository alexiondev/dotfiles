vim.g.mapleader = " "

local opt = vim.opt

-- Clipboard: use neovim's built-in OSC 52 provider, no external binary needed.
vim.g.clipboard = "osc52"
opt.clipboard = "unnamedplus"

opt.number = true
opt.relativenumber = true

opt.shiftwidth = 2
opt.tabstop = 2
opt.expandtab = true

opt.mouse = "a"

-- Neovim's built-in default colors paint their own dark/light background even
-- without a colorscheme; clear it so the terminal's own background shows through.
for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "SignColumn" }) do
  vim.api.nvim_set_hl(0, group, { bg = "none" })
end

opt.undofile = true

opt.ignorecase = true
opt.smartcase = true

opt.splitright = true
opt.splitbelow = true

opt.wrap = false

opt.scrolloff = 8
opt.cursorline = true

vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
