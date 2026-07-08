-- YAML: yaml-language-server (yamlls), con validación por schema.
-- Origen: Mason, paquete "yaml-language-server" (ARM64/npm, sin binario nativo).
return {
  {
    "b0o/SchemaStore.nvim",
    lazy = true,
    version = false,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        yamlls = {
          settings = {
            yaml = {
              schemaStore = {
                enable = false, -- lo maneja SchemaStore.nvim
                url = "",
              },
              schemas = function()
                return require("schemastore").yaml.schemas()
              end,
            },
          },
        },
      },
    },
  },
}
