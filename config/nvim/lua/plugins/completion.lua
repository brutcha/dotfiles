return {
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
    config = function()
      local cmp = require("cmp")

      -- Simple cmp setup
       cmp.setup({
         mapping = {
           -- Navigation with arrow keys (your preference)
           ['<Down>'] = cmp.mapping.select_next_item(),
           ['<Up>'] = cmp.mapping.select_prev_item(),

           -- Alternative navigation (j/k still available)
           -- ['j'] = cmp.mapping.select_next_item(),
           -- ['k'] = cmp.mapping.select_prev_item(),

           -- Acceptance
           ['<Tab>'] = cmp.mapping.confirm({ select = true }),
           ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Enter as alternative

           -- Cancellation (Esc your preference, plus alternatives)
           ['<Esc>'] = cmp.mapping.abort(),
           -- ['<C-c>'] = cmp.mapping.abort(),
           -- ['<C-e>'] = cmp.mapping.abort(),

           -- Manual completion trigger
           ['<C-Space>'] = cmp.mapping.complete(),

           -- Documentation scrolling
           -- ['<C-b>'] = cmp.mapping.scroll_docs(-4),
           -- ['<C-f>'] = cmp.mapping.scroll_docs(4),
         },
         sources = {
           { name = 'nvim_lsp' },
           { name = 'buffer' },
           { name = 'path' },
         }
       })
    end,
  },
}
