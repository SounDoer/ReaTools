-- @description ReaToolUI - Design System Gallery (Development)
-- @author ReaTools contributors
-- @about
--   Development-only design-system reference environment. It does not connect
--   to product services or mutate REAPER project data.

local source = debug.getinfo(1, "S").source:sub(2)
local gallery_dir = source:match("^(.*)[/\\]")
local root = gallery_dir and gallery_dir:match("^(.*)[/\\]gallery$")
if not root then
  reaper.ShowMessageBox("Could not resolve the repository path.", "Design System Gallery", 0)
  return
end

package.path = root .. "/lib/?.lua;" .. root .. "/gallery/?.lua;" .. package.path
if not reaper.ImGui_GetBuiltinPath then
  reaper.ShowMessageBox("ReaImGui is required.", "Design System Gallery", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua;" .. package.path
local ok_imgui, ImGui = pcall(function() return require("imgui")("0.9") end)
if not ok_imgui then
  reaper.ShowMessageBox(tostring(ImGui), "Design System Gallery", 0)
  return
end

local ctx = ImGui.CreateContext("ReaToolUI Design System Gallery",
  ImGui.ConfigFlags_NavEnableKeyboard)
local gallery = require("design_system_gallery")
local platform = reaper.GetOS and reaper.GetOS() or "unknown"

local function create_shell(section, theme, preview)
  return gallery.create({
    ImGui = ImGui,
    ctx = ctx,
    section = section,
    theme = theme,
    preview = preview,
    platform = platform,
    scroll_y = tonumber(os.getenv("REATOOLUI_GALLERY_SCROLL_Y") or ""),
    scenario = os.getenv("REATOOLUI_GALLERY_SCENARIO"),
  })
end

local smoke_path = os.getenv("REATOOLUI_GALLERY_SMOKE_RESULT")
local batch_smoke = os.getenv("REATOOLUI_GALLERY_SMOKE_BATCH") == "1"
local initial_ok, shell = pcall(create_shell,
  os.getenv("REATOOLUI_GALLERY_SECTION"),
  os.getenv("REATOOLUI_GALLERY_THEME"),
  os.getenv("REATOOLUI_GALLERY_PREVIEW"))
if not initial_ok then
  if smoke_path then
    local file = io.open(smoke_path, "w")
    if file then
      file:write("FAIL\nGallery initialization\n" .. tostring(shell) .. "\n")
      file:close()
    end
  else
    reaper.ShowMessageBox(tostring(shell), "Design System Gallery error", 0)
  end
  return
end
local batch_scenarios = {}

if batch_smoke then
  for _, section in ipairs({
    "Foundations", "Components", "Patterns", "Cross-product Scenarios", "Diagnostics",
  }) do
    for _, theme in ipairs({ "light", "dark" }) do
      for _, preview in ipairs({ "compact", "standard", "wide" }) do
        batch_scenarios[#batch_scenarios + 1] = {
          section = section,
          theme = theme,
          preview = preview,
        }
      end
    end
  end
  local first = batch_scenarios[1]
  shell = create_shell(first.section, first.theme, first.preview)
end
local batch_index = 1

local function finish_smoke(ok, err)
  local file = io.open(smoke_path, "w")
  if file then
    local pass_message = batch_smoke and
      ("PASS Design System Gallery matrix (" .. #batch_scenarios .. " scenarios)\n") or
      "PASS Design System Gallery frame\n"
    file:write(ok and pass_message or
      ("FAIL\n" .. tostring(err) .. "\n"))
    file:close()
  end
  shell.open = false
  reaper.Main_OnCommand(40004, 0)
end

local function loop()
  local ok, err = xpcall(shell.draw, debug.traceback)
  if smoke_path and batch_smoke then
    if not ok then
      local scenario = batch_scenarios[batch_index]
      finish_smoke(false, string.format("%s / %s / %s\n%s",
        scenario.section, scenario.theme, scenario.preview, tostring(err)))
      return
    end
    if batch_index == #batch_scenarios then
      finish_smoke(true)
      return
    end
    batch_index = batch_index + 1
    local scenario = batch_scenarios[batch_index]
    shell = create_shell(scenario.section, scenario.theme, scenario.preview)
    reaper.defer(loop)
    return
  elseif smoke_path then
    finish_smoke(ok, err)
    return
  end
  if not ok then
    reaper.ShowConsoleMsg("Design System Gallery error:\n" .. tostring(err) .. "\n")
    reaper.ShowMessageBox(tostring(err), "Design System Gallery error", 0)
    return
  end
  if shell.open then reaper.defer(loop) end
end

reaper.atexit(function()
  if ctx and reaper.ImGui_DestroyContext then reaper.ImGui_DestroyContext(ctx) end
  ctx = nil
end)
reaper.defer(loop)
