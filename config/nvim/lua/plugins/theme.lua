return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight")
    end,
  },
  {
    "cormacrelf/dark-notify",
    lazy = false,
    priority = 1001,
    enabled = vim.fn.has("mac") == 1,
    config = function()
      require("dark_notify").run({
        schemes = {
          dark = "tokyonight",
          light = "tokyonight-day",
        },
      })
    end,
  },
}
