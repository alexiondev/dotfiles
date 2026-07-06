return {
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
    },
    keys = {
      {
        "<leader>g",
        function()
          require("gitsigns").toggle_current_line_blame(true)
          require("neogit").open()
        end,
        desc = "Open git (Neogit)",
      },
    },
    config = function()
      require("neogit").setup()
      vim.api.nvim_create_autocmd("BufUnload", {
        callback = function(args)
          if vim.bo[args.buf].filetype == "NeogitStatus" then
            require("gitsigns").toggle_current_line_blame(false)
          end
        end,
      })
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = "BufWinEnter",
    opts = {
      current_line_blame = false,
    },
  },
}
