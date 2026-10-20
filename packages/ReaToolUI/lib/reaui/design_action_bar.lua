local button_module = require("reaui.design_button")
local layout_module = require("reaui.design_layout")

local M = {}

function M.create(ImGui, ctx, adapter, button, layout)
  button = button or button_module.create(ImGui, ctx, adapter)
  layout = layout or layout_module.create(ImGui, ctx, adapter)
  local component = {}

  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end

  local function validate(options)
    if type(options.id) ~= "string" or options.id == "" then error("action bar id is required") end
    if type(options.actions) ~= "table" then error("action bar actions must be a table") end
    if #options.actions == 0 and options.context == nil then
      error("action bar needs actions or context")
    end
    for index, action in ipairs(options.actions) do
      if action.variant == "primary" and index ~= #options.actions then
        error("the primary action must be last")
      end
    end
  end

  local function draw_context(renderer)
    with_text("label", function()
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, adapter.resolve("semantic.color.text.secondary"))
      renderer()
      ImGui.PopStyleColor(ctx)
    end)
  end

  local function pack_rows(widths, gap, available)
    local rows, row, row_width = {}, {}, 0
    for index, width in ipairs(widths) do
      if #row > 0 and row_width + gap + width > available then
        table.insert(rows, { indices = row, width = row_width })
        row, row_width = {}, 0
      end
      row_width = #row > 0 and row_width + gap + width or width
      table.insert(row, index)
    end
    if #row > 0 then table.insert(rows, { indices = row, width = row_width }) end
    return rows
  end

  function component.draw(options)
    options = options or {}
    validate(options)
    local actions = options.actions
    local result = { events = {}, action = nil }
    local gap = layout.gap()
    local widths, total = {}, 0
    for index, action in ipairs(actions) do
      widths[index] = layout.button_width(action.label)
      total = total + widths[index] + (index > 1 and gap or 0)
    end
    local available = ImGui.GetContentRegionAvail(ctx)

    local function draw_action(index)
      local action = actions[index]
      local event = button.draw({
        id = options.id .. "-" .. action.id, label = action.label,
        variant = action.variant, disabled = action.disabled,
      })
      if event and not action.disabled then
        result.action = action.id
        table.insert(result.events, { type = "action_bar.activated", id = options.id, action = action.id })
      end
    end

    local function draw_row(indices)
      for position, index in ipairs(indices) do
        if position > 1 then ImGui.SameLine(ctx, 0, gap) end
        draw_action(index)
      end
    end

    if options.context then
      local context_width = with_text("label", function() return ImGui.CalcTextSize(ctx, options.context) end)
      if #actions > 0 and context_width + gap + total <= available then
        draw_context(function()
          ImGui.AlignTextToFramePadding(ctx)
          ImGui.Text(ctx, options.context)
        end)
        layout.trailing(total)
        local all = {}
        for index in ipairs(actions) do all[index] = index end
        draw_row(all)
        return result
      end
      draw_context(function() ImGui.TextWrapped(ctx, options.context) end)
    end

    for _, row in ipairs(pack_rows(widths, gap, available)) do
      ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + math.max(0, available - row.width))
      draw_row(row.indices)
    end
    return result
  end

  return component
end

return M
