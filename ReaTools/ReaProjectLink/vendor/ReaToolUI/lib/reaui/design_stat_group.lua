local M = {}

function M.create(ImGui, ctx, adapter)
  local component = {}

  local function resolve(id) return adapter.resolve(id) end
  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end

  local function validate(options)
    if type(options.id) ~= "string" or options.id == "" then error("stat group id is required") end
    local stats = options.stats
    if type(stats) ~= "table" or #stats < 2 or #stats > 4 then
      error("stat group needs two to four stats")
    end
    for _, stat in ipairs(stats) do
      if type(stat.label) ~= "string" or stat.label == "" then error("stat label is required") end
      if type(stat.value) ~= "string" and type(stat.value) ~= "number" then
        error("stat value must be a string or number")
      end
    end
  end

  function component.draw(options)
    options = options or {}
    validate(options)
    local stats = options.stats
    local available = ImGui.GetContentRegionAvail(ctx)
    local gap = resolve("semantic.space.list.gap")
    local padding_x = resolve("semantic.space.inset.padding_x")
    local padding_y = resolve("semantic.space.inset.padding_y")
    local tile_width = (available - gap * (#stats - 1)) / #stats
    local metric_height = with_text("metric", function() return ImGui.GetTextLineHeight(ctx) end)
    local label_height = with_text("metadata", function() return ImGui.GetTextLineHeight(ctx) end)
    local tile_height = metric_height + label_height + padding_y * 2
    local x, y = ImGui.GetCursorScreenPos(ctx)
    local draw_list = ImGui.GetWindowDrawList(ctx)
    local background = resolve("component.stat_group.background")
    local value_color = resolve("semantic.color.text.primary")
    local label_color = resolve("component.stat_group.label")
    local radius = resolve("semantic.radius.control")

    for index, stat in ipairs(stats) do
      local left = x + (index - 1) * (tile_width + gap)
      ImGui.DrawList_AddRectFilled(draw_list, left, y, left + tile_width, y + tile_height, background, radius)
      ImGui.DrawList_PushClipRect(draw_list, left, y, left + tile_width - padding_x / 2, y + tile_height, true)
      with_text("metric", function()
        ImGui.DrawList_AddText(draw_list, left + padding_x, y + padding_y, value_color, tostring(stat.value))
      end)
      with_text("metadata", function()
        ImGui.DrawList_AddText(draw_list, left + padding_x, y + padding_y + metric_height, label_color, stat.label)
      end)
      ImGui.DrawList_PopClipRect(draw_list)
    end
    ImGui.Dummy(ctx, available, tile_height)
    return { events = {} }
  end

  return component
end

return M
