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

opt.undofile = true

opt.ignorecase = true
opt.smartcase = true

opt.splitright = true
opt.splitbelow = true

opt.wrap = false

opt.scrolloff = 8
opt.cursorline = true
