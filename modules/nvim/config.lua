-- Imperative configuration that has no typed nixvim option: the colorscheme
-- call and two autocmds. Everything expressible as Nix lives in ./nvim.nix.

-- gbprod/nord.nvim, provided as an extra plugin from nixpkgs.
require("nord").setup({
  transparent = true,
})
vim.cmd.colorscheme("nord")

-- Conceal markdown syntax in markdown buffers (previously an after/ftplugin).
-- conceallevel is window-local, so it is set with opt_local when the filetype
-- is applied to the buffer's window.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.conceallevel = 2
  end,
})

-- Turn line blame off again once the Neogit status buffer is closed.
vim.api.nvim_create_autocmd("BufUnload", {
  callback = function(args)
    if vim.bo[args.buf].filetype == "NeogitStatus" then
      require("gitsigns").toggle_current_line_blame(false)
    end
  end,
})
