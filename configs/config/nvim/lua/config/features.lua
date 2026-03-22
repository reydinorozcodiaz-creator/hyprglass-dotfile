local project = require("config.project")

local M = {}

function M.get()
  return project.get().features or {}
end

function M.enabled(name)
  return project.feature_enabled(name)
end

return M
