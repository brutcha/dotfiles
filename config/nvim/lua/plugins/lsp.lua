return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "hrsh7th/nvim-cmp",
    },
    opts = function()
      ---@class PluginLspOpts
      local ret = {
        -- options for vim.diagnostic.config()
        ---@type vim.diagnostic.Opts
        diagnostics = {
          underline = true,
          update_in_insert = false,
          virtual_text = {
            spacing = 4,
            source = "if_many",
            prefix = "●",
          },
          severity_sort = true,
          -- TODO: setup properly signs = {
          -- 	text = {
          -- 		[vim.diagnostic.severity.ERROR] = "E",
          -- 		[vim.diagnostic.severity.WARN] = "W",
          -- 		[vim.diagnostic.severity.HINT] = "H",
          -- 		[vim.diagnostic.severity.INFO] = "I",
          -- 	},
          -- },
        },
        -- Enable this to enable the builtin LSP inlay hints on Neovim.
        -- Be aware that you also will need to properly configure your LSP server to
        -- provide the inlay hints.
        inlay_hints = {
          enabled = true,
          exclude = { "vue" }, -- filetypes for which you don't want to enable inlay hints
        },
        -- Enable this to enable the builtin LSP code lenses on Neovim.
        -- Be aware that you also will need to properly configure your LSP server to
        -- provide the code lenses.
        codelens = {
          enabled = false,
        },
        -- Enable this to enable the builtin LSP folding on Neovim.
        -- Be aware that you also will need to properly configure your LSP server to
        -- provide the folds.
        folds = {
          enabled = true,
        },
        -- add any global capabilities here
        capabilities = {
          workspace = {
            fileOperations = {
              didRename = true,
              willRename = true,
            },
          },
        },
        -- options for vim.lsp.buf.format
        -- `bufnr` and `filter` is handled by the LazyVim formatter,
        -- but can be also overridden when specified
        format = {
          formatting_options = nil,
          timeout_ms = nil,
        },
        -- LSP Server Settings
        ---@alias lazyvim.lsp.Config vim.lsp.Config|{mason?:boolean, enabled?:boolean}
        ---@type table<string, lazyvim.lsp.Config|boolean>
        servers = {
          ts_ls = {},
          cssls = {},
          basedpyright = {},
          dockerls = {},
          jsonls = {},
          yamlls = {},
          taplo = {},
          html = {},
          eslint = {
            settings = {
              experimental = {
                useFlatConfig = true,
              },
            },
          },
          tailwindcss = {},
          marksman = {},
          bashls = {},
          nil_ls = {},
          lua_ls = {
            settings = {
              Lua = {
                workspace = {
                  checkThirdParty = false,
                  library = vim.api.nvim_get_runtime_file("", true),
                },
                runtime = {
                  version = "LuaJIT",
                },
                telemetry = {
                  enable = false,
                },
                codeLens = {
                  enable = true,
                },
                completion = {
                  callSnippet = "Replace",
                },
                doc = {
                  privateName = { "^_" },
                },
                hint = {
                  enable = true,
                  setType = false,
                  paramType = true,
                  paramName = "Disable",
                  semicolon = "Disable",
                  arrayIndex = "Disable",
                },
              },
            },
          },
        },
        -- you can do any additional lsp server setup here
        -- return true if you don't want this server to be setup with lspconfig
        ---@type table<string, fun(server:string, opts: vim.lsp.Config):boolean?>
        setup = {
          -- example to setup with typescript.nvim
          -- tsserver = function(_, opts)
          --   require("typescript").setup({ server = opts })
          --   return true
          -- end,
          -- Specify * to use this function as a fallback for any server
          -- ["*"] = function(server, opts) end,
        },
      }
      return ret
    end,

    config = function(_, opts)
      -- Setup diagnostics
      vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

      -- Setup capabilities (use cmp capabilities if available)
      local capabilities = vim.tbl_deep_extend(
        "force",
        {},
        vim.lsp.protocol.make_client_capabilities(),
        vim.g.cmp_capabilities or {},
        opts.capabilities or {}
      )

      -- Setup LSP keymaps on attach
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local bufnr = args.buf
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then
            return
          end

          -- Keymaps
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(
              mode,
              lhs,
              rhs,
              { buffer = bufnr, desc = "LSP: " .. desc }
            )
          end

          map("n", "gd", vim.lsp.buf.definition, "Go to definition")
          map("n", "gr", vim.lsp.buf.references, "Show references")
          map("n", "gI", vim.lsp.buf.implementation, "Go to implementation")
          map("n", "gy", vim.lsp.buf.type_definition, "Go to type definition")
          map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
          map("n", "K", vim.lsp.buf.hover, "Hover documentation")
          map("n", "gK", vim.lsp.buf.signature_help, "Signature help")
          map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("n", "<leader>cr", vim.lsp.buf.rename, "Rename")
          -- map("n", "<leader>cf", vim.lsp.buf.format, "Format")

          -- Inlay hints
          if opts.inlay_hints.enabled and vim.lsp.inlay_hint then
            if client and client:supports_method("textDocument/inlayHint") then
              vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
            end
          end

          -- Code lens
          if opts.codelens and opts.codelens.enabled then
            if client and client:supports_method("textDocument/codeLens") then
              vim.lsp.codelens.refresh()
              vim.api.nvim_create_autocmd(
                { "BufEnter", "CursorHold", "InsertLeave" },
                {
                  buffer = bufnr,
                  callback = vim.lsp.codelens.refresh,
                }
              )
            end
          end
        end,
      })

      local servers = opts.servers

      local function setup_server(server_name, server_opts)
        server_opts = vim.tbl_deep_extend("force", {
          capabilities = vim.deepcopy(vim.g.cmp_capabilities or capabilities),
        }, server_opts or {})

        if opts.setup[server_name] then
          if opts.setup[server_name](server_name, server_opts) then
            return
          end
        elseif opts.setup["*"] then
          if opts.setup["*"](server_name, server_opts) then
            return
          end
        end

        vim.lsp.config(server_name, server_opts)
        vim.lsp.enable(server_name)
      end

      for server_name, server_opts in pairs(servers) do
        setup_server(server_name, server_opts)
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    lazy = true,
    cmd = "ConformInfo",
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ timeout_ms = 500 })
        end,
        mode = { "n", "v" },
        desc = "Format buffer",
      },
    },
    opts = {
      default_format_opts = {
        timeout_ms = 500,
        async = false,
        quiet = false,
        lsp_format = "fallback",
      },
      formatters_by_ft = {
        -- Lua
        lua = { "stylua" },

        -- Web development
        javascript = { "prettierd" },
        javascriptreact = { "prettierd" },
        typescript = { "prettierd" },
        typescriptreact = { "prettierd" },
        css = { "prettierd" },
        html = { "prettierd" },
        json = { "prettierd" },
        jsonc = { "prettierd" },
        yaml = { "prettierd" },
        markdown = { "prettierd" },

        -- Python
        python = { "black", "isort" },

        -- Shell
        sh = { "shfmt" },
        bash = { "shfmt" },

        -- Configuration files
        toml = { "taplo" },

        -- Nix
        nix = { "nixpkgs-fmt" },
      },
      format_on_save = { timeout_ms = 500 },
    },
  },
}
