return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    keys = {
      {
        "<leader>fe",
        "<cmd>Neotree toggle float<cr>",
        desc = "Explorer (Float)",
      },
    },
    opts = {
      window = {
        position = "float",
        width = 35,
        height = 25,
        border = "rounded",
      },
      filesystem = {
        follow_current_file = true,
        hijack_netrw_behavior = "open_current",
        use_libuv_file_watcher = true,
      },
      buffers = {
        follow_current_file = true,
      },
      git_status = {
        window = {
          position = "float",
        },
      },
    },
  },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics" },
      { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics" },
      { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Symbols" },
    },
    opts = {
      win = {
        position = "bottom",
        size = 15,
      },
      focus = true,
      auto_close = true,
      auto_preview = true,
      auto_fold = false,
      keys = {
        ["<esc>"] = "close",
        ["<cr>"] = "jump_close",
        ["<tab>"] = "next",
        ["<s-tab>"] = "prev",
      },
    },
  },
}

