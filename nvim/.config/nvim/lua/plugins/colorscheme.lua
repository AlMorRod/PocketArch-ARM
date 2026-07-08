-- Tema Material Monokai. Paleta fuente única de verdad: CLAUDE.md (repo raíz
-- de PocketArch). No existe un port literal de "Material Monokai" con estos
-- hexes exactos (se investigó: material-monokai.nvim en sourcehut no calza -
-- fondo/texto/keyword distintos). El filtro "classic" de monokai-pro.nvim SÍ
-- coincide exacto en los 6 acentos (es la paleta clásica de Monokai/Sublime),
-- así que se usa como base y solo se sobreescribe fondo/superficie/texto/tenue.
return {
  { "LazyVim/LazyVim", opts = { colorscheme = "monokai-pro" } },
  {
    "loctvl842/monokai-pro.nvim",
    lazy = false,
    priority = 1000,
    init = function()
      -- monokai-pro deriva los ANSI black/blue de dark1/accent2 internamente
      -- (no expuesto vía override_palette). CLAUDE.md pide black=fondo base
      -- y blue=cian; se fuerza tras aplicar el colorscheme.
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "monokai-pro",
        callback = function()
          vim.g.terminal_color_0 = "#1e2327"
          vim.g.terminal_color_8 = "#67757c"
          vim.g.terminal_color_4 = "#66d9ef"
          vim.g.terminal_color_12 = "#66d9ef"
        end,
      })
    end,
    opts = {
      filter = "classic",
      override_palette = function()
        return {
          background = "#1e2327", -- Fondo base
          dark1 = "#232a2e", -- Superficie (sidebar/tabs)
          dark2 = "#2c353a", -- Superficie alta (statusbar)
          text = "#f8f8f2", -- Texto
          accent1 = "#f92672", -- Rosa/rojo (keyword)
          accent2 = "#fd971f", -- Naranja (constante)
          accent3 = "#e6db74", -- Amarillo (string)
          accent4 = "#a6e22e", -- Verde (función)
          accent5 = "#66d9ef", -- Cian (tipo)
          accent6 = "#ae81ff", -- Púrpura (número)
          -- CLAUDE.md define un único tono "tenue/comentarios"; se aplica
          -- uniforme a los 4 niveles de texto atenuado de monokai-pro.
          dimmed1 = "#67757c",
          dimmed2 = "#67757c",
          dimmed3 = "#67757c",
          dimmed4 = "#67757c",
          -- dimmed5 es fondo de popups/hover/notify (no texto): reusa
          -- "superficie alta" en vez de inventar un tono no documentado.
          dimmed5 = "#2c353a",
        }
      end,
      -- El filtro "classic" mapea @constant a accent6 (púrpura); CLAUDE.md
      -- pide naranja para "constante". Se corrige puntualmente.
      override = function()
        return {
          ["@constant"] = { fg = "#fd971f" },
          ["@constant.builtin"] = { fg = "#fd971f" },
          ["@constant.macro"] = { fg = "#fd971f" },
        }
      end,
    },
  },
}
