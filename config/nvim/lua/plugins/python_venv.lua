return {
  {
    "linux-cultist/venv-selector.nvim",
    branch = "regexp",
    ft = "python",
    dependencies = {
      "neovim/nvim-lspconfig",
    },
    opts = {
      settings = {
        options = {
          notify_user_on_venv_activation = false,
          enable_cached_venvs = true,
          cached_venv_automatic_activation = true,
        },
      },
    },
    keys = {
      { "<leader>cv", "<cmd>VenvSelect<cr>", desc = "Select Python venv", ft = "python" },
    },
  },
}
