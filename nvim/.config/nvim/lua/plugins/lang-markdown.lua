-- Markdown: marksman (LSP).
-- Origen: Mason (ARM64 nativo). marksman es un binario .NET (CoreCLR); bajo
-- este contenedor PRoot el GC de CoreCLR falla al reservar heap con el límite
-- por defecto ("GC heap initialization failed", error 0x8007000E). Se fuerza
-- un límite de heap explícito vía cmd_env para que arranque. Formatter
-- (prettier/markdownlint) se cablea en el paso de Extras.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        marksman = {
          cmd_env = { DOTNET_GCHeapHardLimit = "0x10000000" },
        },
      },
    },
  },
}
