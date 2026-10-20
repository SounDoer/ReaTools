local card_module = require("reaui.design_card")

local M = {}

local function copy(source)
  local target = {}
  for key, value in pairs(source) do target[key] = value end
  return target
end

function M.create(ImGui, ctx, adapter, card)
  card = card or card_module.create(ImGui, ctx, adapter)
  local component = {}
  -- Tallest card height of the previous frame, keyed by row id. Recomputed
  -- every frame so a row shrinks when its content shrinks.
  local row_max = {}

  function component.draw(options)
    options = options or {}
    if type(options.id) ~= "string" or options.id == "" then error("card row id is required") end
    if type(options.cards) ~= "table" or #options.cards == 0 then error("card row needs cards") end
    local count = #options.cards
    local available = ImGui.GetContentRegionAvail(ctx)
    local gap = adapter.resolve("semantic.space.block.gap")
    local stacked = available < adapter.resolve("semantic.layout.card_row.stack_below")
    local width = (available - gap * (count - 1)) / count
    local result = { events = {}, actions = {}, stacked = stacked }
    local tallest = 0

    for index, entry in ipairs(options.cards) do
      local card_options = copy(entry.options)
      if stacked then
        if index > 1 then
          local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
          ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - spacing_y + gap)
        end
      else
        if index > 1 then ImGui.SameLine(ctx, 0, gap) end
        card_options.width = width
        card_options.min_height = row_max[options.id]
      end
      local card_result = card.draw(card_options, entry.render_body)
      tallest = math.max(tallest, card_result.natural_height or 0)
      result.actions[card_options.id] = card_result.action
      for _, event in ipairs(card_result.events) do table.insert(result.events, event) end
    end

    row_max[options.id] = not stacked and tallest or nil
    return result
  end

  return component
end

return M
