-- Python: pyright (LSP) + ruff (lint/format, LSP nativo).
-- Origen: Mason (ambos ARM64 nativos). ruff necesitó `python`/`python-pip` del
-- sistema (pacman) para que el venv de Mason no cayera sobre el python de
-- Termux filtrado por PATH; ver packages.txt.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {},
        ruff = {
          cmd_env = { RUFF_TRACE = "messages" },
          init_options = {
            settings = { logLevel = "error" },
          },
        },
      },
      setup = {
        ruff = function()
          -- el hover lo maneja pyright; ruff solo lint/format
          Snacks.util.lsp.on({ name = "ruff" }, function(_, client)
            client.server_capabilities.hoverProvider = false
          end)
        end,
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        python = { "ruff_format" },
      },
    },
  },
}
