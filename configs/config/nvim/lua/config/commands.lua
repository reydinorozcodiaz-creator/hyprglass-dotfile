local project = require("config.project")

local function has_executable(bin)
  return vim.fn.executable(bin) == 1
end

local function yes_no(value)
  return value and "yes" or "no"
end

local function add_line(lines, prefix, message)
  table.insert(lines, string.format("%-7s %s", prefix, message))
end

local function config_health_lines()
  local settings = project.get()
  local lines = {
    "# Config Health",
    "",
    "## Features",
  }

  local feature_names = { "ai", "database", "debug", "notes", "ui_fx", "wakatime" }
  for _, name in ipairs(feature_names) do
    add_line(lines, project.feature_enabled(name) and "[ok]" or "[off]", name)
  end

  table.insert(lines, "")
  table.insert(lines, "## Paths")

  local theme_file = settings.theme_file
  if theme_file and vim.uv.fs_stat(theme_file) then
    add_line(lines, "[ok]", "theme file: " .. theme_file)
  else
    add_line(lines, "[warn]", "theme file missing: " .. tostring(theme_file))
  end

  local obsidian_path = project.obsidian_path()
  if project.get().features.notes ~= false then
    if project.path_exists(obsidian_path) then
      add_line(lines, "[ok]", "obsidian path: " .. obsidian_path)
    else
      add_line(lines, "[warn]", "notes enabled but obsidian_path is missing or invalid")
    end
  else
    add_line(lines, "[off]", "notes disabled")
  end

  table.insert(lines, "")
  table.insert(lines, "## Environment")

  local adapters = {
    settings.ai.chat_adapter,
    settings.ai.inline_adapter,
    settings.ai.agent_adapter,
  }
  local needs_anthropic = vim.tbl_contains(adapters, "anthropic")
  local needs_openai = vim.tbl_contains(adapters, "openai")

  if project.feature_enabled("ai") then
    if needs_anthropic then
      add_line(lines, os.getenv("ANTHROPIC_API_KEY") and "[ok]" or "[warn]", "ANTHROPIC_API_KEY")
    end
    if needs_openai then
      add_line(lines, os.getenv("OPENAI_API_KEY") and "[ok]" or "[warn]", "OPENAI_API_KEY")
    end
    if has_executable("gh") then
      add_line(lines, "[ok]", "gh available for Copilot-based flows")
    else
      add_line(lines, "[info]", "gh not found (only relevant for some Copilot flows)")
    end
  else
    add_line(lines, "[off]", "AI disabled")
  end

  table.insert(lines, "")
  table.insert(lines, "## Executables")

  local executables = {
    { "git", true },
    { "make", true },
    { "npm", true },
    { "lazygit", true },
    { "ollama", project.feature_enabled("ai") },
    { "stylua", true },
    { "prettier", true },
    { "black", true },
    { "shfmt", true },
  }

  for _, item in ipairs(executables) do
    local bin, relevant = item[1], item[2]
    if relevant then
      add_line(lines, has_executable(bin) and "[ok]" or "[warn]", bin)
    end
  end

  table.insert(lines, "")
  table.insert(lines, "## Summary")
  add_line(lines, "[info]", "theme variant: " .. project.theme_variant())
  add_line(lines, "[info]", "wakatime enabled: " .. yes_no(project.enable_wakatime()))
  add_line(lines, "[info]", "database enabled: " .. yes_no(project.enable_database()))

  return lines
end

local function open_report(lines)
  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "text"
  vim.api.nvim_buf_set_name(buf, "ConfigHealth")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

vim.api.nvim_create_user_command("ConfigHealth", function()
  open_report(config_health_lines())
end, {
  desc = "Run a health check for this Neovim config",
})
