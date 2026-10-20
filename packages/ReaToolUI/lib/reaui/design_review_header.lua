local page_header_module = require("reaui.design_page_header")

local M = {}
local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, page_header)
  page_header = page_header or page_header_module.create(ImGui, ctx, adapter)
  local pattern = {}
  function pattern.draw(options)
    options = options or {}
    required_string(options.id, "review header id")
    required_string(options.title, "review header title")
    local summary = options.summary
    if summary == "" then summary = nil end
    local result = page_header.draw({
      id = options.id, title = options.title, summary = summary,
      back_label = options.back_label or "Back", back_disabled = options.disabled,
    })
    local events = {}
    if result.back_requested then table.insert(events, { type = "review.back_requested", id = options.id }) end
    return { events = events, back_requested = result.back_requested == true }
  end
  return pattern
end
return M
