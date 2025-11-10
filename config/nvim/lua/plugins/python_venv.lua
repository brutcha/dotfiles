return {
  {
    "1A7432/nvim-python-venv",
    ft = "python",
    config = function()
      require("nvim-python-venv").setup({
        auto_detect = true,
        auto_activate = true,
        auto_restart_lsp = true,
        managers = {
          priority = {
            "uv",
            "poetry",
            "pipenv",
            "conda",
            "pyenv",
            "local_venv",
            "virtualenvwrapper",
          },
          enabled = {
            uv = true,
            poetry = true,
            pipenv = true,
            conda = true,
            pyenv = true,
            local_venv = true,
            virtualenvwrapper = true,
          },
        },
        lsp = {
          servers = { "basedpyright", "pyright", "pylsp", "jedi_language_server" },
          restart_on_venv_change = true,
          timeout = 5000,
        },
        ui = {
          selector = false,
          notify = false,
          statusline = false,
        },
      })
    end,
  },
}
