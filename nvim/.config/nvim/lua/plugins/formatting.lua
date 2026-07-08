-- Formatter general: prettier para JSON/YAML/Markdown.
-- Origen: Mason (npm, sin binario nativo). Bash/Python/SQL ya tienen su
-- formatter dedicado en sus respectivos lang-*.lua (shfmt/ruff_format/sqlfluff).
return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "prettier" } },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        json = { "prettier" },
        jsonc = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        ["markdown.mdx"] = { "prettier" },
      },
    },
  },
}
