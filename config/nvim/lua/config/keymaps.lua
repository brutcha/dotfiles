local map = vim.keymap.set
-- local lsp_buff = vim.lsp.buff

-- system
map("n", "<leader>sr", function()
  -- Clear loaded modules cache
  for name, _ in pairs(package.loaded) do
    if name:match("^config") or name:match("^plugins") then
      package.loaded[name] = nil
    end
  end
  -- Reload init.lua
  dofile(vim.env.MYVIMRC)
  vim.notify("Config reloaded!", vim.log.levels.INFO)
end, { desc = "Reload config" })

map("n", "<leader>sl", "<cmd>Lazy<cr>", { desc = "Lazy plugin manager" })

-- See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = "Clear search highlights" })
