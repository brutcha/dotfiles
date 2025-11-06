return {
  {
    "nvim-lua/plenary.nvim",
    lazy = false,
    priority = 52,
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<leader>ff",
        "<cmd>Telescope find_files<cr>",
        desc = "Telescope Find Files (Root Dir)",
      },
      {
        "<leader>fg",
        "<cmd>Telescope live_grep<cr>",
        desc = "Telescope Live Grep (Root Dir)",
      },
      {
        "<leader>fb",
        "<cmd>Telescope buffers<cr>",
        desc = "Telescope Buffers",
      },
      {
        "<leader>fh",
        "<cmd>Telescope help_tags<cr>",
        desc = "Telescope help tags",
      },
    },
    opts = {
      pickers = {
        find_files = {
          find_command = { "fd", "--type", "f", "--color", "never" },
        },
        live_grep = {
          find_command = { "rg" },
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    priority = 52,
    build = function()
      require("nvim-treesitter.install").update({ with_sync = true })()
    end,
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
    },
    spec = {
      {
        mode = { "n", "v" },
        { "<leader>c", group = "[C]ode" },
        { "<leader>f", group = "[F]ind" },
        { "<leader>s", group = "[S]ystem" },
        { "<leader>x", group = "Diagnostics [X]" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Keymaps (which-key)",
      },
      {
        "<c-w><space>",
        function()
          require("which-key").show({ keys = "<c-w>", loop = true })
        end,
        desc = "Window Hydra Mode (which-key)",
      },
    },
  },
}
