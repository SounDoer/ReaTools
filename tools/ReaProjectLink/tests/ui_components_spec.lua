local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = assert(source:match("^(.*)[/\\]"))
local root = assert(tests_dir:match("^(.*)[/\\]tests$"))
package.path = root .. "/ReaProjectLink/lib/?.lua;" .. root .. "/ReaProjectLink/lib/?/init.lua;" .. package.path

local components = require("reaprojectlink.ui.components")

local tests = {}

function tests.clipped_lists_reuse_one_attached_clipper()
  local created, attached = 0, 0
  local ImGui = {}

  function ImGui.CreateListClipper(ctx)
    created = created + 1
    return { ctx = ctx }
  end

  function ImGui.Attach(ctx, clipper)
    assert(clipper.ctx == ctx, "clipper attached to its context")
    attached = attached + 1
  end

  function ImGui.ListClipper_Begin(clipper, count)
    clipper.count = count
    clipper.pending = true
  end

  function ImGui.ListClipper_Step(clipper)
    if not clipper.pending then return false end
    clipper.pending = false
    return true
  end

  function ImGui.ListClipper_GetDisplayRange(clipper)
    return 0, clipper.count
  end

  local c = components.create(ImGui, "context", {
    adapter = {}, components = {}, patterns = {},
  })
  local drawn = {}
  c.clipped(2, function(index) table.insert(drawn, index) end)
  c.clipped(1, function(index) table.insert(drawn, index) end)

  assert(created == 1, "one clipper is created for repeated list draws")
  assert(attached == 1, "the clipper is attached to the UI context")
  assert(table.concat(drawn, ",") == "1,2,1", "both lists are drawn")
end

function tests.toast_rises_above_review_footer()
  local ImGui = {}
  local y
  function ImGui.CreateListClipper() return {} end
  function ImGui.Attach() end
  function ImGui.GetWindowPos() return 0, 0 end
  function ImGui.GetWindowSize() return 1000, 700 end
  function ImGui.SetCursorScreenPos(_, _, cursor_y) y = cursor_y end
  function ImGui.GetItemRectSize() return 400, 50 end
  local tokens = {
    ["semantic.space.section.default"] = 20,
    ["semantic.layout.toast.max_width"] = 520,
    ["component.review_shell.footer.height"] = 60,
  }
  local c = components.create(ImGui, "context", {
    adapter = { resolve = function(id) return (assert(tokens[id], id)) end },
    components = { notice = { draw = function() return {} end } },
    patterns = {},
  })
  local toast = { text = "Done", is_error = false }

  c.toast_overlay(toast)
  c.toast_overlay(toast)
  assert(y == 630, "toast sits at the window bottom: " .. tostring(y))
  c.toast_overlay(toast, true)
  assert(y == 570, "toast clears the Review footer: " .. tostring(y))
end

function tests.dropdown_popup_uses_inset_padding_instead_of_page_padding()
  local ImGui = { StyleVar_FramePadding = 1, StyleVar_WindowPadding = 2 }
  local pushed, popped, window_padding = 0, 0, nil
  function ImGui.CreateListClipper() return {} end
  function ImGui.Attach() end
  function ImGui.SetNextItemWidth() end
  function ImGui.PushStyleColor() end
  function ImGui.PopStyleColor() end
  function ImGui.GetStyleVar() return 8, 4 end
  function ImGui.GetFontSize() return 14 end
  function ImGui.PushStyleVar(_, var, x, y)
    pushed = pushed + 1
    if var == ImGui.StyleVar_WindowPadding then window_padding = { x, y } end
  end
  function ImGui.PopStyleVar(_, count) popped = popped + (count or 1) end
  function ImGui.BeginCombo() return true end
  function ImGui.Selectable() return false end
  function ImGui.Separator() end
  function ImGui.EndCombo() end
  local tokens = {
    ["semantic.size.control.medium"] = 32,
    ["semantic.space.inset.padding_x"] = 12,
    ["semantic.space.inset.padding_y"] = 8,
  }
  local c = components.create(ImGui, "context", {
    adapter = { resolve = function(id) return tokens[id] or 0 end },
    components = {}, patterns = {},
  })

  c.dropdown("lane", "New Track", { { id = "create", label = "New Track" }, { separator = true } })

  assert(window_padding, "popup padding is set")
  assert(window_padding[1] == 12 and window_padding[2] == 8, "popup uses inset padding")
  assert(popped == pushed, "style var stack is balanced")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
