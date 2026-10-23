-- PocketArch — instala en headless los parsers de Treesitter y los paquetes
-- de Mason que pide la configuración, y espera a que terminen. Lo ejecuta
-- install.sh después de sincronizar los plugins:
--
--   nvim --headless "+Lazy! sync" "+luafile scripts/nvim-bootstrap.lua"
--
-- Un parser sin instalar sale con error (cquit 1). Un paquete de Mason sin
-- instalar solo avisa: LazyVim lo reintenta al abrir nvim.
--
-- nvim-treesitter va en la rama main: install() devuelve una tarea async con
-- :wait(). Compila con `tree-sitter build`, que usa $CC (install.sh: gcc).

local TIMEOUT = 30 * 60 * 1000

local function say(msg)
  io.stdout:write(msg .. "\n")
end

local function warn(msg)
  io.stderr:write(msg .. "\n")
end

require("lazy").load({
  plugins = { "nvim-treesitter", "mason.nvim", "mason-lspconfig.nvim", "nvim-lspconfig" },
})

-- --- Treesitter ---
local parsers = {}
for _, lang in ipairs(LazyVim.opts("nvim-treesitter").ensure_installed or {}) do
  if not vim.tbl_contains(parsers, lang) then
    parsers[#parsers + 1] = lang
  end
end

local TS = require("nvim-treesitter")
say(("==> Treesitter: %d parsers"):format(#parsers))
local ok, err = pcall(function()
  TS.install(parsers, { summary = true }):wait(TIMEOUT)
end)
if not ok then
  warn("Treesitter: " .. tostring(err))
end

local have = {}
for _, lang in ipairs(TS.get_installed("parsers")) do
  have[lang] = true
end
local missing_ts = vim.tbl_filter(function(lang)
  return not have[lang]
end, parsers)

-- --- Mason ---
-- Herramientas de mason.nvim más los servidores LSP que LazyVim instala con
-- mason-lspconfig (mismo criterio que lazyvim/plugins/lsp/init.lua).
local tools = vim.deepcopy(LazyVim.opts("mason.nvim").ensure_installed or {})
local to_package = require("mason-lspconfig").get_mappings().lspconfig_to_package
local servers = LazyVim.opts("nvim-lspconfig").servers or {}
local lsp = vim.deepcopy(LazyVim.opts("mason-lspconfig.nvim").ensure_installed or {})
for name, sopts in pairs(servers) do
  sopts = sopts == true and {} or sopts
  if name ~= "*" and type(sopts) == "table" and sopts.enabled ~= false and sopts.mason ~= false then
    lsp[#lsp + 1] = name
  end
end
for _, name in ipairs(lsp) do
  if to_package[name] then
    tools[#tools + 1] = to_package[name]
  end
end

local registry = require("mason-registry")
local refreshed = false
registry.refresh(function()
  refreshed = true
end)
vim.wait(TIMEOUT, function()
  return refreshed
end, 500)

local pkgs, seen = {}, {}
for _, name in ipairs(tools) do
  if not seen[name] and registry.has_package(name) then
    seen[name] = true
    local p = registry.get_package(name)
    pkgs[#pkgs + 1] = p
    if not p:is_installed() and not p:is_installing() then
      p:install()
    end
  end
end
say(("==> Mason: %d paquetes"):format(#pkgs))
vim.wait(TIMEOUT, function()
  for _, p in ipairs(pkgs) do
    if p:is_installing() then
      return false
    end
  end
  return true
end, 1000)

local missing_mason = {}
for _, p in ipairs(pkgs) do
  if not p:is_installed() then
    missing_mason[#missing_mason + 1] = p.name
  end
end

-- --- Resultado ---
if #missing_mason > 0 then
  warn("AVISO: Mason sin instalar (se reintenta al abrir nvim): " .. table.concat(missing_mason, ", "))
end
if #missing_ts > 0 then
  warn("ERROR: parsers de Treesitter sin instalar: " .. table.concat(missing_ts, ", "))
  vim.cmd("cquit 1")
end
say(("==> Treesitter: %d/%d parsers instalados"):format(#parsers, #parsers))
vim.cmd("qall!")
