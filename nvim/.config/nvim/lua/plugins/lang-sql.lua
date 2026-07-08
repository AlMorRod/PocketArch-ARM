-- SQL: sin LSP completo. `sqls` (LSP real con autocompletado) requiere
-- compilar con `go`, que el plan descarta explícitamente (Fase 8). Se usa
-- sqlfluff para lint + format en su lugar.
-- Origen: Mason, paquete "sqlfluff" (Python puro; necesitó `python`/`python-pip`
-- del sistema por el mismo motivo que ruff, ver lang-python.lua).
local sql_ft = { "sql", "mysql", "plsql" }

return {
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = { ensure_installed = { "sql" } },
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "sqlfluff" } },
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      for _, ft in ipairs(sql_ft) do
        opts.linters_by_ft[ft] = opts.linters_by_ft[ft] or {}
        table.insert(opts.linters_by_ft[ft], "sqlfluff")
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      -- El formatter base de conform.nvim para sqlfluff exige un marcador de
      -- proyecto (.sqlfluff, pyproject.toml, setup.cfg, tox.ini) en el cwd;
      -- sin uno, format-on-save no hace nada (comportamiento de conform.nvim,
      -- no un bug). El linter (nvim-lint, abajo) no tiene esa restricción.
      opts.formatters.sqlfluff = {
        args = { "format", "--dialect=ansi", "-" },
      }
      for _, ft in ipairs(sql_ft) do
        opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
        table.insert(opts.formatters_by_ft[ft], "sqlfluff")
      end
    end,
  },
}
