return {
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
}
