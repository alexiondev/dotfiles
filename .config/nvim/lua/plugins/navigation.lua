return {
  {
    "stevearc/oil.nvim",
    lazy = false,
    opts = {
      view_options = { show_hidden = true },
    },
    keys = {
      { "<leader>e", "<cmd>Oil<CR>", desc = "Open file browser" },
    },
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      picker = { enabled = true },
      notifier = { enabled = true },
      input = { enabled = true },
    },
    keys = {
      { "<leader>f", function() require("snacks").picker.files() end, desc = "Find files" },
      { "<leader>s", function() require("snacks").picker.grep() end, desc = "Search text" },
      { "<leader>b", function() require("snacks").picker.buffers() end, desc = "Switch buffer" },
    },
  },
}
