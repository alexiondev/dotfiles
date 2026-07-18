return {
  {
    "gbprod/nord.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true,
    },
    config = function(_, opts)
      require("nord").setup(opts)
      vim.cmd.colorscheme("nord")
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {},
  },
  {
    "folke/which-key.nvim",
    lazy = false,
    config = true,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "markdown",
        "markdown_inline",
        "lua",
        "bash",
        "fish",
        "rust",
        "javascript",
        "typescript",
        "java",
        "kotlin",
        "c",
        "cpp",
        "html",
        "css",
        "python",
      },
      auto_install = false,
      highlight = { enable = true },
      indent = { enable = true },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
