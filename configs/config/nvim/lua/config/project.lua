local M = {}

local defaults = {
  theme = nil,
  theme_file = nil,
  obsidian_path = nil,
  features = {
    ai = true,
    database = true,
    debug = true,
    notes = true,
    ui_fx = true,
    wakatime = true,
  },
  ai = {
    chat_adapter = "anthropic",
    inline_adapter = "copilot",
    agent_adapter = "anthropic",
    openai_model = "gpt-4o",
    ollama_model = "llama3",
    ollama_host = "127.0.0.1",
    ollama_port = "11434",
  },
  integrations = {
    enable_wakatime = true,
    enable_database = true,
  },
}

M.root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")

local ok, local_settings = pcall(require, "config.local")
M.settings = vim.tbl_deep_extend("force", defaults, ok and local_settings or {})

if not M.settings.theme_file then
  M.settings.theme_file = M.root .. "/current-theme.txt"
end

function M.get()
  return M.settings
end

function M.expand(path)
  if not path or path == "" then
    return nil
  end

  return vim.fn.expand(path)
end

function M.read_first_line(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local line = file:read("*l")
  file:close()

  return line and vim.trim(line) or nil
end

function M.path_exists(path)
  return path ~= nil and vim.uv.fs_stat(path) ~= nil
end

function M.theme_variant()
  local requested = M.settings.theme or M.read_first_line(M.settings.theme_file) or "ayu-dark"
  local variants = {
    ["ayu-dark"] = "dark",
    ["ayu-mirage"] = "mirage",
    ["ayu-light"] = "light",
  }

  return variants[requested] or "dark"
end

function M.obsidian_path()
  return M.expand(M.settings.obsidian_path)
end

function M.feature_enabled(name)
  local features = M.settings.features or {}
  local value = features[name]

  if value ~= nil then
    if name == "notes" and value then
      return M.path_exists(M.obsidian_path())
    end

    return value
  end

  if name == "database" then
    return M.settings.integrations.enable_database ~= false
  end

  if name == "wakatime" then
    return M.settings.integrations.enable_wakatime ~= false
  end

  if name == "notes" then
    return M.path_exists(M.obsidian_path())
  end

  return true
end

function M.enable_wakatime()
  return M.feature_enabled("wakatime")
end

function M.enable_database()
  return M.feature_enabled("database")
end

return M
