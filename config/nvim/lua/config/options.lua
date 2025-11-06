local g = vim.g
local o = vim.o
local opt = vim.opt
local api = vim.api

-- Auto-reload files changed externally
o.autoread = true
o.updatetime = 4000

-- Check for file changes on focus/buffer enter
api.nvim_create_autocmd({"FocusGained", "BufEnter"}, {
  command = "checktime"
})

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  o.clipboard = "unnamedplus"
end)

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
-- Already set in config/lazy.lua before lazy.nvim is loaded
-- g.mapleader = " "
-- g.maplocalleader = " "

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
o.confirm = true

g.have_nerd_font = true -- Enable nerd font integration
opt.cursorline = true -- enable highlighting of current line
opt.number = true -- show line number
opt.relativenumber = true -- use relative line numbers
opt.scrolloff = 10 -- Number of lines to keep above/below cursor

-- Indentation settings
opt.tabstop = 2 -- number of spaces a tab character displays as
opt.shiftwidth = 2 -- number of spaces to use for each indent level
opt.expandtab = true -- convert tabs to spaces
opt.smartindent = true -- smart autoindenting when starting a new line
