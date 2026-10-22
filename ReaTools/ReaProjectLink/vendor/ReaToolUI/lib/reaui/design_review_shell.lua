local header_module = require("reaui.design_review_header")
local footer_module = require("reaui.design_review_footer")
local stale_module = require("reaui.design_stale_review")
local layout_module = require("reaui.design_layout")
local section_heading_module = require("reaui.design_section_heading")

local M = {}
local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, header, footer, stale_review)
  header = header or header_module.create(ImGui, ctx, adapter)
  footer = footer or footer_module.create(ImGui, ctx, adapter)
  stale_review = stale_review or stale_module.create(ImGui, ctx, adapter)
  local layout = layout_module.create(ImGui, ctx, adapter)
  local section_heading = section_heading_module.create(ImGui, ctx, adapter, layout)
  local pattern = {}
  -- Body cursor right below the header of the current shell draw. Content
  -- drawn below it gets a section gap; the header already supplies its own.
  local content_top = 0
  local function append(target, result)
    for _, event in ipairs((result and result.events) or {}) do table.insert(target, event) end
  end

  function pattern.section(options, render)
    options = options or {}
    if type(render) ~= "function" then error("review section renderer must be a function") end
    return section_heading.draw({
      id = options.id, title = options.title, gap_above = ImGui.GetCursorPosY(ctx) > content_top,
    }, render)
  end

  function pattern.draw(options)
    options = options or {}
    required_string(options.id, "review shell id")
    if type(options.header) ~= "table" then error("review shell header is required") end
    if type(options.footer) ~= "table" then error("review shell footer is required") end
    if options.stale == nil and type(options.render_body) ~= "function" then
      error("review shell render_body is required when review is current")
    end
    if options.stale ~= nil and type(options.stale) ~= "table" then
      error("review shell stale must be a table or nil")
    end

    local available_width, available_height = ImGui.GetContentRegionAvail(ctx)
    local width = math.min(available_width, adapter.resolve("component.review_shell.content.max_width"))
    local indent = math.max(0, (available_width - width) / 2)
    local footer_height = adapter.resolve("component.review_shell.footer.height")
    local body_height = math.max(1, available_height - footer_height)
    local events = {}
    local body_result

    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + indent)
    local body_visible = ImGui.BeginChild(ctx, "##review-shell-" .. options.id .. "-body", width, body_height)
    local ok, err = true, nil
    if body_visible then
      local header_options = {}
      for key, value in pairs(options.header) do header_options[key] = value end
      header_options.id = options.id
      append(events, header.draw(header_options))
      content_top = ImGui.GetCursorPosY(ctx)
      if options.stale then
        local stale_options = {}
        for key, value in pairs(options.stale) do stale_options[key] = value end
        stale_options.id = options.id
        append(events, stale_review.draw(stale_options))
      else
        ok, body_result = pcall(options.render_body)
        if ok then append(events, body_result) else err = body_result end
      end
      if ok then layout.settle() end
    end
    if body_visible then ImGui.EndChild(ctx) end
    if not ok then error(err, 0) end

    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + indent)
    local footer_visible = ImGui.BeginChild(ctx, "##review-shell-" .. options.id .. "-footer",
      width, 0, 0, ImGui.WindowFlags_NoScrollbar)
    if footer_visible then
      local footer_options = {}
      for key, value in pairs(options.footer) do footer_options[key] = value end
      footer_options.id = options.id
      if options.stale then footer_options.enabled = false end
      append(events, footer.draw(footer_options))
    end
    if footer_visible then ImGui.EndChild(ctx) end
    layout.settle()
    return { stale = options.stale ~= nil, body_result = body_result, events = events }
  end
  return pattern
end
return M
