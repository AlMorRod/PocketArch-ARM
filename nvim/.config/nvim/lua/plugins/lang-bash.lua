-- Bash: bash-language-server (LSP) + shfmt (formatter).
-- Origen: Mason (ambos ARM64 nativos, shfmt ya venía verificado desde la Fase 4 base).
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        sh = { "shfmt" },
        bash = { "shfmt" },
      },
    },
  },
}
