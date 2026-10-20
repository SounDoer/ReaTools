local M = {}

function M.display_name(is_development)
  return is_development and "ReaProjectLink [Dev]" or "ReaProjectLink"
end

return M
