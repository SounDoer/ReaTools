-- @description ReaAssetFlow
-- @version 0.1.0
-- @author ReaTools contributors
-- @changelog
--   Establish the ReaAssetFlow product identity and ReaPack package boundary.
-- @about
--   Name, render, preview, and transfer game-audio assets from REAPER to Wwise.
--
--   Requires ReaImGui, Python 3.8 or newer, and the Python dependencies listed
--   in requirements.txt. Optional LLM features additionally require Ollama.
-- @provides
--   [nomain] lib/reaassetflow/*.lua
--   [nomain] scripts/wwise_import.py
--   [nomain] scripts/llm_assist.py
--   [nomain] requirements.txt
--   [nomain] setup.bat
--   [nomain] setup-llm.bat
--   [nomain] README.md
--   [nomain] LICENSE

--[[
  ReaAssetFlow - ReaAssetFlow.lua
  主工作流脚本，将选中 item 渲染后直接导入 Wwise。

  使用流程：
    1. 命名 item：在 Transfer Panel 的 Auto name 区完成
    2. 选中要导入的 item
    3. 运行本脚本（Reaper 中只需 ReaScript: Load ReaAssetFlow.lua；Python wwise_import.py 仍由本脚本按路径调用）
    4. 填写 Wwise 目标路径，点 OK
    5. 在弹出的渲染对话框中点 Render（输出目录已预设为系统 temp）
    6. 渲染完成关闭对话框后，自动导入 Wwise 并清理 temp 文件
]]

local function script_path()
    local info = debug.getinfo(1, "S").source:sub(2)
    return info:match("(.*[\\/])") or "./"
end

local function repo_root()
    return script_path()
end

package.path = repo_root() .. "lib\\?.lua;" .. package.path
local storage = require("reaassetflow.storage").create(
    reaper,
    repo_root(),
    os.getenv("REAASSETFLOW_DATA_ROOT")
)
local migration = storage.migrate_legacy()
if #migration.errors > 0 and reaper.ShowConsoleMsg then
    reaper.ShowConsoleMsg("ReaAssetFlow user-data migration warning:\n" ..
        table.concat(migration.errors, "\n") .. "\n")
end

-- Code-level debug switch (no UI):
-- 1) default off; set to true for local troubleshooting.
-- 2) can be overridden by environment variable RTW_DEBUG=1.
local DEBUG_MODE_DEFAULT = false

local function is_debug_mode_enabled()
    local v = tostring(os.getenv("RTW_DEBUG") or ""):lower()
    if v == "1" or v == "true" or v == "yes" or v == "on" then
        return true
    end
    if v == "0" or v == "false" or v == "no" or v == "off" then
        return false
    end
    return DEBUG_MODE_DEFAULT
end

local function get_staging_dir()
    return storage.staging_dir
end

local function get_dir_name(path)
    return tostring(path or ""):match("([^\\/:]+)$") or tostring(path or "")
end

local function delete_dir(path)
    if path and path ~= "" then
        os.execute('rmdir /S /Q "' .. path .. '" 2>nul')
    end
end

local function prune_old_staging_runs(root, keep_count)
    keep_count = keep_count or 20
    local runs = {}
    local i = 0
    while true do
        local name = reaper.EnumerateSubdirectories(root, i)
        if not name then break end
        local ts = tonumber(name:match("^run_(%d+)_%d+$"))
        if ts then
            table.insert(runs, { name = name, ts = ts })
        end
        i = i + 1
    end
    table.sort(runs, function(a, b) return a.ts > b.ts end)
    for idx = keep_count + 1, #runs do
        delete_dir(root .. "\\" .. runs[idx].name)
    end
end

local function create_run_staging_dir()
    local root = get_staging_dir()
    os.execute('mkdir "' .. root .. '" 2>nul')
    prune_old_staging_runs(root, 5)
    local run_dir = string.format("%s\\run_%d_%04d", root, os.time(), math.random(0, 9999))
    os.execute('mkdir "' .. run_dir .. '" 2>nul')
    return run_dir
end

local function list_wav_files(dir)
    local files = {}
    local i = 0
    while true do
        local file = reaper.EnumerateFiles(dir, i)
        if not file then break end
        if file:lower():match("%.wav$") then
            table.insert(files, dir .. "\\" .. file)
        end
        i = i + 1
    end
    return files
end

local function quote(s)
    local text = tostring(s or "")
    -- Escape embedded quotes for Windows command line.
    text = text:gsub('"', '\\"')
    -- Prevent trailing backslashes from escaping the closing quote.
    text = text:gsub("\\+$", function(bs) return bs .. bs end)
    return '"' .. text .. '"'
end

local function json_escape(s)
    local t = tostring(s or "")
    t = t:gsub("\\", "\\\\")
    t = t:gsub('"', '\\"')
    t = t:gsub("\r", "\\r")
    t = t:gsub("\n", "\\n")
    return t
end

local function trim(s)
    local out = (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
    return out
end

local function non_empty_or(value, fallback)
    local v = trim(value or "")
    if v == "" then return fallback end
    return v
end

-- === AUTO NAME ===

local function collect_markers()
    local markers = {}
    local _, num_markers, _ = reaper.CountProjectMarkers(0)
    for i = 0, num_markers - 1 do
        local retval, is_region, pos, _, name = reaper.EnumProjectMarkers(i)
        if retval > 0 and (not is_region) then
            table.insert(markers, { pos = pos, name = name or "" })
        end
    end
    table.sort(markers, function(a, b) return a.pos < b.pos end)
    return markers
end

local function find_left_marker_name(markers, pos)
    local nearest = ""
    for _, m in ipairs(markers or {}) do
        if m.pos <= pos then
            nearest = m.name or ""
        else
            break
        end
    end
    return nearest
end

local function collect_regions()
    local regions = {}
    local _, num_markers, _ = reaper.CountProjectMarkers(0)
    for i = 0, num_markers - 1 do
        local retval, is_region, pos, rgnend, name = reaper.EnumProjectMarkers(i)
        if retval > 0 and is_region then
            regions[#regions + 1] = {
                start_pos = pos or 0,
                end_pos = rgnend or pos or 0,
                name = name or "",
            }
        end
    end
    table.sort(regions, function(a, b) return a.start_pos < b.start_pos end)
    return regions
end

local function find_region_name_at_pos(regions, pos)
    for _, r in ipairs(regions or {}) do
        if pos >= r.start_pos and pos < r.end_pos then
            return r.name or ""
        end
    end
    return ""
end

local function get_item_export_name(item)
    local _, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
    notes = trim(notes)
    if notes ~= "" then return notes end
    local take = reaper.GetActiveTake(item)
    if take then
        local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        take_name = trim(take_name)
        if take_name ~= "" then return take_name end
    end
    return ""
end

local function set_item_export_name(item, name)
    reaper.GetSetMediaItemInfo_String(item, "P_NOTES", name, true)
    local take = reaper.GetActiveTake(item)
    if take then
        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)
    end
end

local function build_named_markers(markers)
    local named = {}
    for _, m in ipairs(markers or {}) do
        local marker_name = trim(m.name or "")
        if marker_name ~= "" then
            named[#named + 1] = { pos = m.pos, name = marker_name }
        end
    end
    return named
end

-- $idx3/$idx2 must substitute before $idx: the pattern "%$idx" also matches inside
-- "$idx2" and "$idx3", so a generic pairs() loop would corrupt those tokens.
-- apply_name_pattern uses pairs() and is only correct for context keys with no prefix overlap
-- (item / track / marker / region / parent).
local function apply_auto_name_pattern(pattern, context)
    local out = tostring(pattern or "")
    out = out:gsub("%$track", tostring((context and context.track) or ""))
    out = out:gsub("%$marker", tostring((context and context.marker) or ""))
    out = out:gsub("%$region", tostring((context and context.region) or ""))
    out = out:gsub("%$idx3", tostring((context and context.idx3) or ""))
    out = out:gsub("%$idx2", tostring((context and context.idx2) or ""))
    out = out:gsub("%$idx", tostring((context and context.idx) or ""))
    return out
end

local function build_auto_name_plan(scope_mode, name_pattern, index_scope, missing_marker_mode, marker_fallback)
    local markers = build_named_markers(collect_markers())
    local regions = collect_regions()
    local mmode = tostring(missing_marker_mode or "skip")
    if #markers == 0 and mmode == "skip" then
        return nil, "No non-empty markers found. Add markers (e.g. Walk/Run) before auto naming."
    end
    local pattern = non_empty_or(name_pattern, "$track_$marker_$idx2")
    local scope = tostring(index_scope or "track_marker")
    local fallback_marker = non_empty_or(marker_fallback, "NoMarker")
    local skipped = 0
    local buckets = {}

    local function push_item(item)
        if not item then return end
        local track = reaper.GetMediaItemTrack(item)
        if not track then return end
        local track_idx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0
        track_idx = math.max(0, math.floor(track_idx - 1))
        local _, track_name = reaper.GetTrackName(track)
        track_name = trim(track_name or "")
        if track_name == "" then
            track_name = string.format("Track%d", track_idx + 1)
        end

        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local marker_name = find_left_marker_name(markers, pos)
        if marker_name == "" and mmode ~= "fallback" then
            skipped = skipped + 1
            return
        end
        if marker_name == "" then
            marker_name = fallback_marker
        end

        local bucket_key = marker_name
        if scope == "track_marker" then
            bucket_key = track_name .. "\1" .. marker_name
        elseif scope == "global" then
            bucket_key = "__global__"
        end
        local list = buckets[bucket_key]
        if not list then
            list = {}
            buckets[bucket_key] = list
        end
        local region_name = find_region_name_at_pos(regions, pos)
        list[#list + 1] = {
            item = item,
            pos = pos,
            track_idx = track_idx,
            marker = marker_name,
            track = track_name,
            region = region_name,
        }
    end

    local mode = tostring(scope_mode or "selected_items")
    if mode == "selected_tracks" then
        local track_count = reaper.CountSelectedTracks(0)
        for t = 0, track_count - 1 do
            local track = reaper.GetSelectedTrack(0, t)
            local item_count = reaper.CountTrackMediaItems(track)
            for i = 0, item_count - 1 do
                push_item(reaper.GetTrackMediaItem(track, i))
            end
        end
    else
        local count = reaper.CountSelectedMediaItems(0)
        for i = 0, count - 1 do
            push_item(reaper.GetSelectedMediaItem(0, i))
        end
    end

    local bucket_keys = {}
    for k, _ in pairs(buckets) do
        bucket_keys[#bucket_keys + 1] = k
    end
    table.sort(bucket_keys)

    local plan = {}
    for _, bucket_key in ipairs(bucket_keys) do
        local items = buckets[bucket_key] or {}
        table.sort(items, function(a, b)
            if a.pos == b.pos then
                return (a.track_idx or 0) < (b.track_idx or 0)
            end
            return a.pos < b.pos
        end)
        for idx, entry in ipairs(items) do
            local context = {
                track = entry.track or "",
                marker = entry.marker or "",
                region = entry.region or "",
                idx = tostring(idx),
                idx2 = string.format("%02d", idx),
                idx3 = string.format("%03d", idx),
            }
            local item_name = trim(apply_auto_name_pattern(pattern, context))
            if item_name == "" then
                item_name = string.format("%s_%s_%02d", context.track, context.marker, idx)
            end
            plan[#plan + 1] = { item = entry.item, name = item_name, bucket = bucket_key }
        end
    end

    return { rows = plan, skipped = skipped }, nil
end

local function auto_name_items_by_track_and_marker(scope_mode, name_pattern, index_scope, missing_marker_mode, marker_fallback)
    local plan_data, err = build_auto_name_plan(
        scope_mode,
        name_pattern,
        index_scope,
        missing_marker_mode,
        marker_fallback
    )
    if err then
        return nil, err
    end

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    local renamed = 0
    for _, row in ipairs(plan_data.rows or {}) do
        set_item_export_name(row.item, row.name)
        renamed = renamed + 1
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Auto-name items from track + markers (UI)", -1)
    return { renamed = renamed, skipped = plan_data.skipped or 0 }, nil
end

local function build_item_context_map()
    local markers = collect_markers()
    local regions = collect_regions()
    local map = {}
    local count = reaper.CountSelectedMediaItems(0)
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item then
            local item_name = get_item_export_name(item)
            if item_name ~= "" then
                local track = reaper.GetMediaItemTrack(item)
                local _, track_name = reaper.GetTrackName(track, "")
                local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local marker_name = find_left_marker_name(markers, pos)
                local region_name = find_region_name_at_pos(regions, pos)
                map[item_name] = {
                    marker = marker_name,
                    region = region_name,
                    track = track_name or "",
                    item = item_name,
                }
            end
        end
    end
    return map
end

-- === STATE / IPC ===

local function get_state_dir()
    return storage.state_dir
end

local function ensure_state_dir()
    local dir = get_state_dir()
    if dir == "" then return end
    -- Avoid shell spawn on startup; it can be noticeably slow on some setups.
    if reaper.RecursiveCreateDirectory then
        reaper.RecursiveCreateDirectory(dir, 0)
        return
    end
    os.execute('mkdir "' .. dir .. '" 2>nul')
end

local function build_request_file_path()
    return get_state_dir() .. "\\rtw_request.json"
end

local function build_status_file_path()
    return get_state_dir() .. "\\rtw_status.json"
end

local function build_query_status_file_path()
    return get_state_dir() .. "\\rtw_query_status.json"
end

local function build_query_result_file_path()
    return get_state_dir() .. "\\rtw_query_result.json"
end

local function build_import_process_log_path()
    return get_state_dir() .. "\\rtw_import_process.log"
end

local function build_ui_state_file_path()
    return get_state_dir() .. "\\rtw_ui_state.json"
end

local DEFAULT_STRUCTURES = {
    { object_type = "Actor Mixer", object_name = "$track" },
    { object_type = "Random Container", object_name = "$track_$marker" },
    { object_type = "Sound SFX", object_name = "$item" },
}

local function clone_structures(src)
    local out = {}
    for _, row in ipairs(src or {}) do
        out[#out + 1] = {
            object_type = row.object_type or "Sound SFX",
            object_name = row.object_name or "$item",
        }
    end
    return out
end

-- Forward declaration: assigned after cache path helpers (Lua would otherwise treat
-- calls inside write_request_file as globals and hit nil at runtime).
local build_object_map_file_path
-- Forward declaration: referenced by process-watch helpers before definition.
local run_process

local function write_request_file(path, status_path, project_path, subfolder, target, operation, template_path, wavs, structures, item_context_map, selected_wwu)
    local struct_rows = structures or {}
    local wav_rows = wavs or {}
    local lines = {
        "{",
        '  "status_file": "' .. json_escape(status_path or "") .. '",',
        '  "object_map_file": "' .. json_escape(build_object_map_file_path()) .. '",',
        '  "expected_project_path": "' .. json_escape(project_path) .. '",',
        '  "originals_subfolder": "' .. json_escape(subfolder) .. '",',
        '  "import_target": "' .. json_escape(target) .. '",',
        '  "selected_wwu": "' .. json_escape(selected_wwu or "") .. '",',
        '  "import_operation": "' .. json_escape(operation) .. '",',
        '  "debug_mode": ' .. (is_debug_mode_enabled() and "true" or "false") .. ',',
        '  "property_template_path": "' .. json_escape(template_path or "") .. '",',
        '  "structures": ['
    }
    for i, row in ipairs(struct_rows) do
        local suffix = (i < #struct_rows) and "," or ""
        lines[#lines + 1] =
            '    {"object_type":"' .. json_escape(row.object_type or "") ..
            '","object_name":"' .. json_escape(row.object_name or "") .. '"}' .. suffix
    end
    lines[#lines + 1] = "  ],"
    lines[#lines + 1] = '  "item_context_map": {'
    local ctx_entries = {}
    for item_name, ctx in pairs(item_context_map or {}) do
        ctx_entries[#ctx_entries + 1] = { item_name = item_name, ctx = ctx }
    end
    table.sort(ctx_entries, function(a, b) return a.item_name < b.item_name end)
    for i, entry in ipairs(ctx_entries) do
        local suffix = (i < #ctx_entries) and "," or ""
        local marker = json_escape(entry.ctx.marker or "")
        local region = json_escape(entry.ctx.region or "")
        local track = json_escape(entry.ctx.track or "")
        local item = json_escape(entry.ctx.item or entry.item_name)
        lines[#lines + 1] =
            '    "' .. json_escape(entry.item_name) .. '": {"marker":"' .. marker ..
            '","region":"' .. region .. '","track":"' .. track .. '","item":"' .. item .. '"}' .. suffix
    end
    lines[#lines + 1] = "  },"
    lines[#lines + 1] = '  "wav_files": ['
    for i, wav in ipairs(wav_rows) do
        local suffix = (i < #wav_rows) and "," or ""
        lines[#lines + 1] = '    "' .. json_escape(wav) .. '"' .. suffix
    end
    lines[#lines + 1] = "  ]"
    lines[#lines + 1] = "}"

    local f = io.open(path, "w")
    if not f then return false end
    f:write(table.concat(lines, "\n"))
    f:close()
    return true
end

local function load_ui_state()
    local path = build_ui_state_file_path()
    local f = io.open(path, "r")
    if not f then return {} end
    local text = f:read("*all")
    f:close()

    local function pick(key)
        return text:match('"' .. key .. '"%s*:%s*"([^"]*)"') or ""
    end

    return {
        project_path = pick("project_path"):gsub("\\\\", "\\"),
        subfolder = pick("subfolder"):gsub("\\\\", "\\"),
        target = pick("target"):gsub("\\\\", "\\"),
        operation = pick("operation"),
        template_path = pick("template_path"):gsub("\\\\", "\\"),
        auto_name_pattern = pick("auto_name_pattern"),
        auto_name_index_scope = pick("auto_name_index_scope"),
        auto_name_missing_marker_mode = pick("auto_name_missing_marker_mode"),
        auto_name_fallback_marker = pick("auto_name_fallback_marker"),
    }
end

local function save_ui_state(project_path, subfolder, target, operation, template_path, auto_name_pattern, auto_name_index_scope, auto_name_missing_marker_mode, auto_name_fallback_marker)
    ensure_state_dir()
    local path = build_ui_state_file_path()
    local lines = {
        "{",
        '  "project_path": "' .. json_escape(project_path or "") .. '",',
        '  "subfolder": "' .. json_escape(subfolder or "") .. '",',
        '  "target": "' .. json_escape(target or "") .. '",',
        '  "operation": "' .. json_escape(operation or "") .. '",',
        '  "template_path": "' .. json_escape(template_path or "") .. '",',
        '  "auto_name_pattern": "' .. json_escape(auto_name_pattern or "$track_$marker_$idx2") .. '",',
        '  "auto_name_index_scope": "' .. json_escape(auto_name_index_scope or "track_marker") .. '",',
        '  "auto_name_missing_marker_mode": "' .. json_escape(auto_name_missing_marker_mode or "skip") .. '",',
        '  "auto_name_fallback_marker": "' .. json_escape(auto_name_fallback_marker or "NoMarker") .. '"',
        "}"
    }
    local f = io.open(path, "w")
    if not f then return false end
    f:write(table.concat(lines, "\n"))
    f:close()
    return true
end

local function parse_status_file(path)
    local f = io.open(path, "r")
    if not f then return nil, nil, nil, nil end
    local text = f:read("*all")
    f:close()
    local state = text:match('"state"%s*:%s*"([^"]+)"')
    local requested = tonumber(text:match('"requested_wavs"%s*:%s*(%d+)')) or tonumber(text:match('"requested"%s*:%s*(%d+)'))
    local processed = tonumber(text:match('"processed_objects"%s*:%s*(%d+)')) or tonumber(text:match('"processed"%s*:%s*(%d+)'))
    local processed_sfx = tonumber(text:match('"processed_sound_sfx"%s*:%s*(%d+)'))
    local skipped = tonumber(text:match('"skipped"%s*:%s*(%d+)'))
    local stage = text:match('"stage"%s*:%s*"([^"]+)"')
    local pid = tonumber(text:match('"pid"%s*:%s*(%d+)'))
    local updated_at = tonumber(text:match('"updated_at"%s*:%s*([%d%.]+)'))
    return state, requested, processed, processed_sfx, skipped, stage, pid, updated_at
end

local function is_pid_alive(pid)
    if not pid or pid <= 0 then return nil end
    local osstr = (reaper.GetOS and reaper.GetOS()) or ""
    if not osstr:match("Win") then
        return nil
    end
    local cmd = string.format('cmd /c tasklist /FI "PID eq %d" /FO CSV /NH', pid)
    local code, text = run_process(cmd, 5000)
    if code == 259 then
        return nil
    end
    local out = tostring(text or "")
    if out == "" then
        return nil
    end
    if out:find("No tasks are running", 1, true) then
        return false
    end
    if out:find('"' .. tostring(pid) .. '"', 1, true) then
        return true
    end
    return nil
end

local function terminate_pid(pid)
    if not pid or pid <= 0 then return false end
    local osstr = (reaper.GetOS and reaper.GetOS()) or ""
    if not osstr:match("Win") then
        return false
    end
    local cmd = string.format('cmd /c taskkill /PID %d /T /F', pid)
    local code, _ = run_process(cmd, 8000)
    return code == 0
end

local function monitor_import_status(status_path, fallback_requested, subfolder, target, started_at, staging_dir)
    local state, requested, processed, processed_sfx, skipped, stage, pid, updated_at = parse_status_file(status_path)
    local now_epoch = os.time()
    if state == "running" and pid then
        local alive_now = is_pid_alive(pid)
        if alive_now == false then
            delete_dir(staging_dir)
            local age_now = nil
            if updated_at then
                age_now = math.max(0, now_epoch - math.floor(updated_at))
            end
            reaper.ShowMessageBox(
                "Import process exited, but status stayed in running.\n\n" ..
                "Wwise import likely finished (please verify in Wwise).\n" ..
                string.format("Last stage: %s\nPID: %s\nStatus age: %s sec",
                    tostring(stage or "unknown"),
                    tostring(pid or "unknown"),
                    tostring(age_now or "unknown")),
                "ReaAssetFlow - Import Possibly Completed", 0)
            return
        end
        -- Root-cause mitigation: waapi-client call can hang indefinitely without timeout.
        -- If import stage heartbeat is stale for too long, force-kill stuck worker process.
        if alive_now == true and stage == "waapi_import" and updated_at then
            local stale_sec = math.max(0, now_epoch - math.floor(updated_at))
            if stale_sec >= 180 then
                local killed = terminate_pid(pid)
                delete_dir(staging_dir)
                reaper.ShowMessageBox(
                    "Import process appears stuck in WAAPI import stage and has been terminated.\n\n" ..
                    string.format("PID: %s\nStage stale: %d sec\nKilled: %s\n\n",
                        tostring(pid), stale_sec, killed and "yes" or "no") ..
                    "Please retry import. If this repeats, reduce batch size or split the selection.",
                    "ReaAssetFlow - Import Stalled", 0)
                return
            end
        end
    end
    if state == "done" then
        requested = requested or fallback_requested or 0
        processed = processed or requested
        processed_sfx = processed_sfx or requested
        skipped = skipped or 0
        delete_dir(staging_dir)
        reaper.ShowMessageBox(
            string.format(
                "Import finished (background).\n\nRequested WAVs: %d\nProcessed Objects: %d\nProcessed Sound SFX: %d\nSkipped: %d\n\n" ..
                "Originals subfolder: %s\nWwise target: %s",
                requested, processed, processed_sfx, skipped, subfolder, target
            ),
            "ReaAssetFlow - Import Complete", 0)
        return
    end
    if state == "error" then
        delete_dir(staging_dir)
        reaper.ShowMessageBox(
            "Background import reported an error.\n\nPlease check Reaper console output.",
            "ReaAssetFlow - Import Failed", 0)
        return
    end
    if reaper.time_precise() - started_at > 300 then
        local alive = is_pid_alive(pid)
        local age = nil
        if updated_at then
            age = math.max(0, now_epoch - math.floor(updated_at))
        end
        if alive == false then
            delete_dir(staging_dir)
            reaper.ShowMessageBox(
                "Import process exited but status file stayed in running.\n\n" ..
                "Wwise objects may already be imported.\n" ..
                string.format("Last stage: %s\nPID: %s\nStatus age: %s sec",
                    tostring(stage or "unknown"),
                    tostring(pid or "unknown"),
                    tostring(age or "unknown")),
                "ReaAssetFlow - Import Possibly Completed", 0)
            return
        end
        reaper.ShowMessageBox(
            "Background import is still running after 5 minutes.\n\n" ..
            string.format("Stage: %s\nPID: %s\nStatus age: %s sec\n\n",
                tostring(stage or "unknown"),
                tostring(pid or "unknown"),
                tostring(age or "unknown")) ..
            "Please verify results in Wwise or check Reaper console output.",
            "ReaAssetFlow - Import Still Running", 0)
        return
    end
    reaper.defer(function()
        monitor_import_status(status_path, fallback_requested, subfolder, target, started_at, staging_dir)
    end)
end

run_process = function(cmd, timeout_ms)
    local timeout = timeout_ms or 60000
    local t0 = (reaper.time_precise and reaper.time_precise()) or 0
    local code, output = reaper.ExecProcess(cmd, timeout)
    local t1 = (reaper.time_precise and reaper.time_precise()) or t0
    local elapsed_ms = math.floor((t1 - t0) * 1000 + 0.5)
    local code_num = tonumber(code)
    local text = tostring(output or "")

    -- Some Reaper builds only expose one return value.
    -- If the first return value is numeric text (e.g. "259"), treat it as exit code.
    if (output == nil or text == "") and type(code) == "string" then
        if code:match("^%-?%d+$") then
            code_num = tonumber(code)
            text = ""
        else
            text = code
            code_num = nil
        end
    end
    -- Some builds may duplicate exit code in stdout field (e.g. "259").
    -- Treat pure numeric stdout that equals exit code as empty output.
    local numeric_text = tonumber(trim(text))
    if code_num ~= nil and numeric_text ~= nil and numeric_text == code_num then
        text = ""
    end
    -- Strip numeric-only noise lines (e.g. a standalone "0"/"259").
    if text ~= "" then
        local kept = {}
        for line in text:gmatch("[^\r\n]+") do
            local t = trim(line)
            local n = tonumber(t)
            local is_noise = false
            if t ~= "" and n ~= nil and t:match("^%-?%d+$") then
                if code_num ~= nil and n == code_num then
                    is_noise = true
                elseif n == 0 then
                    is_noise = true
                end
            end
            if not is_noise then
                kept[#kept + 1] = line
            end
        end
        text = table.concat(kept, "\n")
        if tonumber(trim(text)) ~= nil and trim(text):match("^%-?%d+$") then
            text = ""
        end
    end
    -- Some Reaper builds return nil/""
    -- on timeout; infer timeout by elapsed wall time.
    if code_num == nil and trim(text) == "" and elapsed_ms >= (timeout - 50) then
        code_num = 259
    end
    return code_num, text
end

local function check_base_prerequisites()
    local probe = "import sys; assert sys.version_info >= (3, 8); " ..
        "import waapi; print('REAASSETFLOW_READY ' + sys.version.split()[0])"
    local code, output = run_process("python -c " .. quote(probe), 10000)
    local text = trim(output or "")
    if code ~= 259 and text:find("REAASSETFLOW_READY", 1, true) then
        return {
            ok = true,
            summary = "Setup ready · Python " .. (text:match("REAASSETFLOW_READY%s+([^%s]+)") or "3.8+"),
        }
    end
    local lower = text:lower()
    local reason
    if lower:find("no module named", 1, true) and lower:find("waapi", 1, true) then
        reason = "Python is available, but waapi-client is missing."
    elseif lower:find("assertionerror", 1, true) then
        reason = "Python 3.8 or newer is required."
    else
        reason = "Python 3.8+ could not be started."
    end
    return {
        ok = false,
        summary = "Setup required",
        detail = reason .. " Open the installation folder, run setup.bat, then choose Check Again.",
    }
end

local function normalize_subfolder(s)
    local out = trim(s):gsub("\\", "/")
    out = out:gsub("^/+", ""):gsub("/+$", "")
    return out
end

local function normalize_folder_path(s)
    local out = trim(s):gsub("/", "\\")
    out = out:gsub("\\+$", "")
    return out
end

local function normalize_project_path(s)
    return normalize_folder_path(s)
end

local function normalize_target_path(s)
    local out = trim(s):gsub("/", "\\")
    out = out:gsub("\\+$", "")
    if out ~= "" and out:sub(1, 1) ~= "\\" then
        out = "\\" .. out
    end
    return out
end

-- Per-Reaper-project cache under REAPER resource path (must appear after normalize_folder_path).
--   ...\REAPER\ReaAssetFlow\cache\<slug>\target_cache.txt
--   ...\REAPER\ReaAssetFlow\cache\<slug>\object_map.json
local function current_reaper_project_path_key()
    if not reaper.GetProjectPath then return "" end
    return normalize_folder_path(trim(reaper.GetProjectPath(""))):lower()
end

local function reaper_project_cache_slug()
    local proj = ""
    if reaper.GetProjectPath then
        proj = trim(reaper.GetProjectPath(""))
    end
    if proj == "" then
        return "_no_reaper_project"
    end
    local norm = normalize_folder_path(proj):lower()
    local h1, h2 = 5381, 52711
    for i = 1, #norm do
        local c = norm:byte(i)
        h1 = (h1 * 33 + c) % 4294967296
        h2 = (h2 * 37 + c * i) % 4294967296
    end
    local leaf = norm:match("([^\\/]+)$") or "project"
    leaf = leaf:gsub("%.rpp$", ""):gsub("[^%w%-_]", "_")
    if #leaf > 48 then
        leaf = leaf:sub(1, 48)
    end
    return string.format("%s__%08x_%08x", leaf, h1, h2)
end

local function build_reaper_to_wwise_cache_dir()
    return storage.cache_dir .. "\\" .. reaper_project_cache_slug()
end

-- Parent of per-project slug folders: ...\REAPER\ReaAssetFlow\cache
local function build_reaper_to_wwise_cache_root_dir()
    return normalize_folder_path(storage.cache_dir)
end

local function ensure_folder_exists_for_dev(path)
    path = normalize_folder_path(path)
    if path == "" then return end
    if reaper.file_exists and reaper.file_exists(path) then
        return
    end
    if reaper.RecursiveCreateDirectory then
        reaper.RecursiveCreateDirectory(path, 0)
        return
    end
    if reaper.GetOS and reaper.GetOS():match("Win") then
        os.execute('mkdir "' .. path .. '" 2>nul')
    end
end

local function open_folder_in_system_file_manager(path)
    path = normalize_folder_path(path)
    if path == "" then return end
    local osstr = (reaper.GetOS and reaper.GetOS()) or ""
    if osstr:match("Win") then
        -- start "" explorer … returns once Explorer is spawned; avoids blocking Reaper longer than needed.
        os.execute("cmd /c start \"\" explorer " .. quote(path))
    elseif osstr:match("OSX") then
        os.execute("open " .. quote(path))
    else
        os.execute("xdg-open " .. quote(path) .. " 2>/dev/null &")
    end
end

-- Defer folder open off the ImGui click handler: os.execute still blocks one frame, but the panel stays responsive.
local function dev_open_folder_next_tick(path)
    path = normalize_folder_path(path)
    if path == "" then return end
    reaper.defer(function()
        ensure_folder_exists_for_dev(path)
        open_folder_in_system_file_manager(path)
    end)
end

local function dev_open_state_dir_next_tick()
    reaper.defer(function()
        local p = normalize_folder_path(get_state_dir())
        if not (reaper.file_exists and reaper.file_exists(p)) then
            ensure_state_dir()
        end
        open_folder_in_system_file_manager(p)
    end)
end

build_object_map_file_path = function()
    return build_reaper_to_wwise_cache_dir() .. "\\object_map.json"
end

local function looks_like_error(output)
    local text = tostring(output or ""):lower()
    return text:find("[error]", 1, true) ~= nil
        or text:find("cannot connect to wwise", 1, true) ~= nil
        or text:find("is not installed", 1, true) ~= nil
        or text:find("not recognized", 1, true) ~= nil
        or text:find("timed out", 1, true) ~= nil
        or text:find("traceback", 1, true) ~= nil
end

local function parse_import_summary(output)
    local text = tostring(output or "")
    local requested = tonumber(text:match("requested_wavs=(%d+)")) or tonumber(text:match("requested=(%d+)"))
    local processed = tonumber(text:match("processed_objects=(%d+)")) or tonumber(text:match("processed=(%d+)"))
    local processed_sfx = tonumber(text:match("processed_sound_sfx=(%d+)"))
    local skipped = tonumber(text:match("skipped=(%d+)"))
    return requested, processed, processed_sfx, skipped
end

local function normalize_import_operation(s)
    local lowered = trim(s):lower()
    if lowered == "1" or lowered == "useexisting" or lowered == "use existing" then
        return "useExisting"
    end
    if lowered == "2" or lowered == "createnew" or lowered == "create new" then
        return "createNew"
    end
    if lowered == "3" or lowered == "replaceexisting" or lowered == "replace existing" then
        return "replaceExisting"
    end
    return nil
end

local function parse_target_candidates(output)
    local targets = {}
    for line in tostring(output or ""):gmatch("[^\r\n]+") do
        local path = line:match("^%[TARGET%]%s+(.+)$")
        if path and path ~= "" then
            table.insert(targets, path)
        end
    end
    return targets
end

local function parse_result_items_file(path)
    local f = io.open(path, "r")
    if not f then return {} end
    local text = f:read("*all")
    f:close()
    local items_block = text:match('"items"%s*:%s*%[(.-)%]')
    if not items_block then return {} end
    local out = {}
    for raw in items_block:gmatch('"(.-)"') do
        local item = raw:gsub("\\\\", "\\")
        if item ~= "" then
            out[#out + 1] = item
        end
    end
    return out
end

local function parse_status_message(path)
    local f = io.open(path, "r")
    if not f then return nil, nil end
    local text = f:read("*all")
    f:close()
    local state = text:match('"state"%s*:%s*"([^"]+)"')
    local message = text:match('"message"%s*:%s*"([^"]*)"')
    return state, message
end

local function parse_wwu_candidates(output)
    local wwus = {}
    for line in tostring(output or ""):gmatch("[^\r\n]+") do
        local path = line:match("^%[WWU%]%s+(.+)$")
        if path and path ~= "" then
            table.insert(wwus, path)
        end
    end
    return wwus
end

-- === TARGET CACHE ===

local function build_target_cache_file_path()
    return build_reaper_to_wwise_cache_dir() .. "\\target_cache.txt"
end

local function cache_encode_field(s)
    local out = tostring(s or "")
    out = out:gsub("%%", "%%25")
    out = out:gsub("|", "%%7C")
    out = out:gsub("\n", "%%0A")
    out = out:gsub("\r", "")
    return out
end

local function cache_decode_field(s)
    local out = tostring(s or "")
    out = out:gsub("%%0A", "\n")
    out = out:gsub("%%7C", "|")
    out = out:gsub("%%25", "%%")
    return out
end

local function cache_project_key(project_path)
    return normalize_project_path(project_path or ""):lower()
end

local function cache_base_key(base_path)
    return normalize_target_path(base_path or ""):lower()
end

local function load_target_cache()
    local path = build_target_cache_file_path()
    local f = io.open(path, "r")
    if not f then return { wwus = {}, targets = {} } end
    local text = f:read("*all")
    f:close()
    local cache = { wwus = {}, targets = {} }
    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        local kind, a, b, c = line:match("^([A-Z]+)|([^|]*)|([^|]*)|?(.*)$")
        if kind == "WWU" then
            local pkey = cache_decode_field(a)
            local wwu = cache_decode_field(b)
            cache.wwus[pkey] = cache.wwus[pkey] or {}
            cache.wwus[pkey][#cache.wwus[pkey] + 1] = wwu
        elseif kind == "TARGET" then
            local pkey = cache_decode_field(a)
            local bkey = cache_decode_field(b)
            local target = cache_decode_field(c)
            cache.targets[pkey] = cache.targets[pkey] or {}
            cache.targets[pkey][bkey] = cache.targets[pkey][bkey] or {}
            cache.targets[pkey][bkey][#cache.targets[pkey][bkey] + 1] = target
        end
    end
    return cache
end

local function unique_sorted_copy(src)
    local seen, out = {}, {}
    for _, v in ipairs(src or {}) do
        if v and v ~= "" and not seen[v] then
            seen[v] = true
            out[#out + 1] = v
        end
    end
    table.sort(out)
    return out
end

local function ensure_directory_recursive(dir)
    if dir == "" or not dir then return end
    if reaper.RecursiveCreateDirectory then
        reaper.RecursiveCreateDirectory(dir, 0)
        return
    end
    os.execute('mkdir "' .. dir .. '" 2>nul')
end

local function json_unescape_simple(s)
    local t = tostring(s or "")
    t = t:gsub("\\\\", "\\")
    t = t:gsub('\\"', '"')
    t = t:gsub("\\n", "\n")
    t = t:gsub("\\r", "\r")
    return t
end

local function sanitize_preset_file_stem(s)
    local stem = trim(s):gsub('[<>:"/\\|?%*]', "_")
    stem = stem:gsub("%s+", "_")
    if stem == "" then stem = "transfer_preset" end
    if #stem > 80 then stem = stem:sub(1, 80) end
    return stem
end

local function enumerate_structure_preset_files(dir)
    local out = {}
    if dir == "" then return out end
    local i = 0
    while true do
        local name = reaper.EnumerateFiles(dir, i)
        if not name then break end
        if name:lower():match("%.json$") then
            out[#out + 1] = normalize_folder_path(dir) .. "\\" .. name
        end
        i = i + 1
    end
    table.sort(out)
    return out
end

local function preset_basename(path)
    local name = tostring(path or ""):match("([^\\/]+)$") or ""
    return (name:gsub("%.json$", "")) or ""
end

local function wwu_path_in_list(list, path)
    local np = normalize_target_path(path)
    if np == "" then return false end
    for _, w in ipairs(list or {}) do
        if normalize_target_path(w) == np then
            return true
        end
    end
    return false
end

local function write_panel_preset_file(dir, display_name, state)
    ensure_directory_recursive(dir)
    local stem = sanitize_preset_file_stem(display_name)
    local path = dir .. "\\" .. stem .. ".json"
    local probe = io.open(path, "r")
    if probe then
        probe:close()
        path = dir .. "\\" .. stem .. "_" .. tostring(os.time()) .. ".json"
    end
    local rows = state.structures or {}
    local lines = {
        "{",
        '  "name": "' .. json_escape(display_name) .. '",',
        '  "project_path": "' .. json_escape(state.project_path or "") .. '",',
        '  "originals_path": "' .. json_escape(state.originals_path or "") .. '",',
        '  "target": "' .. json_escape(state.target or "") .. '",',
        '  "operation": "' .. json_escape(state.operation or "useExisting") .. '",',
        '  "selected_wwu": "' .. json_escape(state.selected_wwu or "") .. '",',
        '  "template_path": "' .. json_escape(state.template_path or "") .. '",',
        '  "auto_name_pattern": "' .. json_escape(state.auto_name_pattern or "$track_$marker_$idx2") .. '",',
        '  "auto_name_index_scope": "' .. json_escape(state.auto_name_index_scope or "track_marker") .. '",',
        '  "auto_name_missing_marker_mode": "' .. json_escape(state.auto_name_missing_marker_mode or "skip") .. '",',
        '  "auto_name_fallback_marker": "' .. json_escape(state.auto_name_fallback_marker or "NoMarker") .. '",',
        '  "selected_structure_idx": ' .. tostring(math.max(1, math.floor(tonumber(state.selected_structure_idx) or 1))) .. ",",
        '  "structures": [',
    }
    for i, row in ipairs(rows) do
        local comma = (i < #rows) and "," or ""
        lines[#lines + 1] = string.format(
            '    {"object_type":"%s","object_name":"%s"}%s',
            json_escape(row.object_type or ""),
            json_escape(row.object_name or ""),
            comma
        )
    end
    lines[#lines + 1] = "  ]"
    lines[#lines + 1] = "}"
    local f = io.open(path, "w")
    if not f then return nil, "Could not write preset file." end
    f:write(table.concat(lines, "\n"))
    f:close()
    return path, nil
end

local function read_panel_preset_file(path, default_subfolder, def_project_path, def_target, def_operation)
    local f = io.open(path, "r")
    if not f then return nil, "Could not read preset file." end
    local text = f:read("*all")
    f:close()

    local function jstr(key)
        local raw = text:match('"' .. key .. '"%s*:%s*"([^"]*)"')
        if raw == nil then return nil end
        return json_unescape_simple(raw)
    end

    local block = text:match('"structures"%s*:%s*%[(.-)%]%s*}')
    if not block then return nil, "Invalid preset (missing structures)." end
    local structures = {}
    for ot, on in block:gmatch(
        '{%s*"object_type"%s*:%s*"([^"]-)"%s*,%s*"object_name"%s*:%s*"([^"]-)"%s*}'
    ) do
        structures[#structures + 1] = {
            object_type = json_unescape_simple(ot),
            object_name = json_unescape_simple(on),
        }
    end
    if #structures == 0 then
        return nil, "Invalid preset (no structure rows)."
    end

    local name = jstr("name") or preset_basename(path)
    local project_path = normalize_project_path(jstr("project_path") or def_project_path or "")
    local originals_path = normalize_folder_path(jstr("originals_path") or "")
    if trim(originals_path) == "" then
        originals_path = build_originals_folder_path(project_path, default_subfolder)
    end
    local target_raw = jstr("target")
    local target
    if target_raw == nil then
        target = normalize_target_path(def_target or "")
    else
        target = normalize_target_path(target_raw)
    end
    local op_raw = jstr("operation")
    local operation = normalize_import_operation(op_raw or "") or def_operation or "useExisting"
    local selected_wwu = normalize_target_path(jstr("selected_wwu") or "")
    local template_path = jstr("template_path") or ""
    local auto_name_pattern = jstr("auto_name_pattern") or "$track_$marker_$idx2"
    local auto_name_index_scope = jstr("auto_name_index_scope") or "track_marker"
    local auto_name_missing_marker_mode = jstr("auto_name_missing_marker_mode") or "skip"
    local auto_name_fallback_marker = jstr("auto_name_fallback_marker") or "NoMarker"
    local idx = tonumber(text:match('"selected_structure_idx"%s*:%s*(%d+)')) or 1
    idx = math.max(1, math.min(idx, #structures))

    return {
        name = name,
        project_path = project_path,
        originals_path = originals_path,
        target = target,
        operation = operation,
        selected_wwu = selected_wwu,
        template_path = template_path,
        auto_name_pattern = auto_name_pattern,
        auto_name_index_scope = auto_name_index_scope,
        auto_name_missing_marker_mode = auto_name_missing_marker_mode,
        auto_name_fallback_marker = auto_name_fallback_marker,
        structures = structures,
        selected_structure_idx = idx,
    }, nil
end

local function save_target_cache(cache)
    local path = build_target_cache_file_path()
    local dir = path:match("^(.*)\\[^\\]+$") or ""
    if dir ~= "" then
        ensure_directory_recursive(dir)
    end
    local lines = {}
    for pkey, list in pairs((cache and cache.wwus) or {}) do
        for _, wwu in ipairs(unique_sorted_copy(list)) do
            lines[#lines + 1] = table.concat({
                "WWU",
                cache_encode_field(pkey),
                cache_encode_field(wwu),
                ""
            }, "|")
        end
    end
    for pkey, by_base in pairs((cache and cache.targets) or {}) do
        for bkey, list in pairs(by_base or {}) do
            for _, target in ipairs(unique_sorted_copy(list)) do
                lines[#lines + 1] = table.concat({
                    "TARGET",
                    cache_encode_field(pkey),
                    cache_encode_field(bkey),
                    cache_encode_field(target)
                }, "|")
            end
        end
    end
    local f = io.open(path, "w")
    if not f then return false end
    f:write(table.concat(lines, "\n"))
    f:close()
    return true
end

local function get_cached_wwus(cache, project_path)
    local pkey = cache_project_key(project_path)
    return unique_sorted_copy(((cache or {}).wwus or {})[pkey] or {})
end

local function set_cached_wwus(cache, project_path, wwus)
    local pkey = cache_project_key(project_path)
    cache.wwus[pkey] = unique_sorted_copy(wwus)
end

local function get_cached_targets(cache, project_path, base_path)
    local pkey = cache_project_key(project_path)
    local bkey = cache_base_key(base_path)
    local by_base = (((cache or {}).targets or {})[pkey] or {})
    return unique_sorted_copy(by_base[bkey] or {})
end

local function set_cached_targets(cache, project_path, base_path, targets)
    local pkey = cache_project_key(project_path)
    local bkey = cache_base_key(base_path)
    cache.targets[pkey] = cache.targets[pkey] or {}
    cache.targets[pkey][bkey] = unique_sorted_copy(targets)
end

local function pick_best_wwu_for_target(wwus, target_path)
    local normalized_target = normalize_target_path(target_path):lower()
    if normalized_target == "" then return nil end
    local best = nil
    local best_len = -1
    for _, wwu in ipairs(wwus or {}) do
        local n = normalize_target_path(wwu):lower()
        if n ~= "" and normalized_target:sub(1, #n) == n and #n > best_len then
            best = wwu
            best_len = #n
        end
    end
    return best
end

-- === WWISE QUERY ===

local function pick_target_from_list(python_script, default_target, project_path)
    local list_cmd = table.concat({
        "python",
        quote(python_script),
        "--list-import-targets",
        "--list-base-path", quote("\\Actor-Mixer Hierarchy"),
        "--expected-project-path", quote(project_path),
    }, " ")
    local code, text = run_process(list_cmd, 90000)
    reaper.ShowConsoleMsg(text .. "\n")
    if code == 259 then
        return nil, "Query Wwise target list timed out (90s)."
    end
    if looks_like_error(text) then
        return nil, "Could not query Wwise target list."
    end

    local targets = parse_target_candidates(text)
    if #targets == 0 then
        return nil, "No target candidates returned from Wwise."
    end

    local max_show = math.min(20, #targets)
    local lines = {}
    for i = 1, max_show do
        lines[#lines + 1] = string.format("%02d) %s", i, targets[i])
    end

    reaper.ShowConsoleMsg(
        "[ReaAssetFlow] Target candidates:\n" ..
        table.concat(lines, "\n") .. "\n\n" ..
        "[ReaAssetFlow] Enter an index in the next dialog.\n"
    )

    local choice_ok, choice_csv = reaper.GetUserInputs(
        string.format("Select Wwise Target (1-%d)", max_show),
        1,
        "Index from console list:,extrawidth=280",
        "1"
    )
    if not choice_ok then
        return default_target, nil
    end

    local idx = tonumber((trim(choice_csv)), 10)
    if not idx or idx < 1 or idx > max_show then
        return nil, "Invalid index selection."
    end

    reaper.ShowConsoleMsg("[ReaAssetFlow] Selected: " .. targets[idx] .. "\n")
    return targets[idx], nil
end

local function build_llm_context_args(tracks, markers, items)
    local parts = {}
    if tracks and #tracks > 0 then
        parts[#parts + 1] = "--tracks"
        for _, t in ipairs(tracks) do parts[#parts + 1] = quote(t) end
    end
    if markers and #markers > 0 then
        parts[#parts + 1] = "--markers"
        for _, m in ipairs(markers) do parts[#parts + 1] = quote(m) end
    end
    if items and #items > 0 then
        parts[#parts + 1] = "--items"
        for _, it in ipairs(items) do parts[#parts + 1] = quote(it) end
    end
    return parts
end

local function collect_llm_context()
    local markers_list = build_named_markers(collect_markers())
    local regions_list = collect_regions()
    local tracks_seen, markers_seen, item_names = {}, {}, {}
    local tracks_ordered, markers_ordered = {}, {}

    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local track = reaper.GetMediaItemTrack(item)
        local _, tname = reaper.GetTrackName(track)
        tname = trim(tname or "")
        if tname ~= "" and not tracks_seen[tname] then
            tracks_seen[tname] = true
            tracks_ordered[#tracks_ordered + 1] = tname
        end
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local mname = find_left_marker_name(markers_list, pos)
        if mname ~= "" and not markers_seen[mname] then
            markers_seen[mname] = true
            markers_ordered[#markers_ordered + 1] = mname
        end
        local ename = trim(get_item_export_name(item))
        if ename ~= "" then item_names[#item_names + 1] = ename end
    end
    return tracks_ordered, markers_ordered, item_names
end

local function detect_llm_runtime_error(text)
    local raw = tostring(text or "")
    local lower = raw:lower()
    if lower:find("ollama package not installed", 1, true) then
        return "ollama package not installed. Run: pip install ollama"
    end
    if lower:find("ollama service unavailable", 1, true) then
        return "ollama service unavailable. Install/start Ollama and run: ollama serve"
    end
    if lower:find("ollama model not found", 1, true) then
        local line = raw:match("[Oo]llama model not found:[^\r\n]*")
        return trim(line or "ollama model not found. Run: ollama pull <model>")
    end
    if lower:find("ollama request timed out", 1, true) then
        return "ollama request timed out. Make sure Ollama is running: ollama serve"
    end
    return nil
end

local function run_llm_suggest_pattern(llm_script, model, tracks, markers, items)
    local started_at = reaper.time_precise()
    reaper.ShowConsoleMsg(string.format(
        "[ReaAssetFlow LLM] Pattern analysis started (model=%s, tracks=%d, markers=%d, items=%d)\n",
        tostring(model), #tracks, #markers, #items
    ))
    local parts = { "python", quote(llm_script), "--model", quote(model), "suggest-pattern" }
    for _, a in ipairs(build_llm_context_args(tracks, markers, items)) do
        parts[#parts + 1] = a
    end
    local _, text = run_process(table.concat(parts, " "), 120000)
    local user_err = detect_llm_runtime_error(text)
    if user_err then
        local elapsed_ms = math.floor((reaper.time_precise() - started_at) * 1000)
        reaper.ShowConsoleMsg(string.format(
            "[ReaAssetFlow LLM] Pattern analysis failed: %s (%d ms).\n",
            user_err, elapsed_ms
        ))
        return nil, user_err
    end
    local pattern = text:match('"pattern"%s*:%s*"([^"]+)"')
    if not pattern or trim(pattern) == "" then
        local elapsed_ms = math.floor((reaper.time_precise() - started_at) * 1000)
        reaper.ShowConsoleMsg(string.format(
            "[ReaAssetFlow LLM] Pattern analysis finished with invalid output (%d ms).\n",
            elapsed_ms
        ))
        return nil, "LLM returned unexpected output:\n" .. text
    end
    local elapsed_ms = math.floor((reaper.time_precise() - started_at) * 1000)
    reaper.ShowConsoleMsg(string.format(
        "[ReaAssetFlow LLM] Pattern analysis finished successfully (%d ms).\n",
        elapsed_ms
    ))
    return trim(pattern), nil
end

local function run_llm_suggest_structure(llm_script, model, tracks, markers, items)
    local started_at = reaper.time_precise()
    reaper.ShowConsoleMsg(string.format(
        "[ReaAssetFlow LLM] Structure analysis started (model=%s, tracks=%d, markers=%d, items=%d)\n",
        tostring(model), #tracks, #markers, #items
    ))
    local parts = { "python", quote(llm_script), "--model", quote(model), "suggest-structure" }
    for _, a in ipairs(build_llm_context_args(tracks, markers, items)) do
        parts[#parts + 1] = a
    end
    local _, text = run_process(table.concat(parts, " "), 120000)
    local user_err = detect_llm_runtime_error(text)
    if user_err then
        local elapsed_ms = math.floor((reaper.time_precise() - started_at) * 1000)
        reaper.ShowConsoleMsg(string.format(
            "[ReaAssetFlow LLM] Structure analysis failed: %s (%d ms).\n",
            user_err, elapsed_ms
        ))
        return nil, user_err
    end
    local block = text:match('"structures"%s*:%s*%[(.-)%]')
    if not block then
        local elapsed_ms = math.floor((reaper.time_precise() - started_at) * 1000)
        reaper.ShowConsoleMsg(string.format(
            "[ReaAssetFlow LLM] Structure analysis finished with invalid output (%d ms).\n",
            elapsed_ms
        ))
        return nil, "LLM returned unexpected output:\n" .. text
    end
    local structures = {}
    for obj_text in block:gmatch("{(.-)}") do
        local ot = obj_text:match('"object_type"%s*:%s*"([^"]-)"')
        local on = obj_text:match('"object_name"%s*:%s*"([^"]-)"')
        if ot and on and trim(ot) ~= "" and trim(on) ~= "" then
            structures[#structures + 1] = { object_type = ot, object_name = on }
        end
    end
    if #structures == 0 then
        local elapsed_ms = math.floor((reaper.time_precise() - started_at) * 1000)
        reaper.ShowConsoleMsg(string.format(
            "[ReaAssetFlow LLM] Structure analysis finished with empty result (%d ms).\n",
            elapsed_ms
        ))
        return nil, "LLM returned an empty structures array."
    end
    local elapsed_ms = math.floor((reaper.time_precise() - started_at) * 1000)
    reaper.ShowConsoleMsg(string.format(
        "[ReaAssetFlow LLM] Structure analysis finished successfully (%d row(s), %d ms).\n",
        #structures, elapsed_ms
    ))
    return structures, nil
end

local function run_import(project_path, subfolder, target, operation, template_path, structures, auto_name_pattern, auto_name_index_scope, auto_name_missing_marker_mode, auto_name_fallback_marker, selected_wwu)
    math.randomseed(math.floor(reaper.time_precise() * 1000000))
    save_ui_state(
        project_path,
        subfolder,
        target,
        operation,
        template_path,
        auto_name_pattern,
        auto_name_index_scope,
        auto_name_missing_marker_mode,
        auto_name_fallback_marker
    )
    local python_script = repo_root() .. "scripts\\wwise_import.py"
    local request_file = build_request_file_path()
    local status_file = build_status_file_path()
    local item_context_map = build_item_context_map()
    os.remove(status_file)
    if not write_request_file(request_file, status_file, project_path, subfolder, target, operation, template_path, {}, structures, item_context_map, selected_wwu) then
        reaper.ShowMessageBox(
            "Could not create request file for Python call.",
            "ReaAssetFlow - Error", 0)
        return
    end

    -- Validate WAAPI connectivity and target path before render
    local validate_cmd = table.concat({
        "python",
        quote(python_script),
        "--request-file",        quote(request_file),
        "--validate-target-only",
    }, " ")
    local validate_code, validate_text = run_process(validate_cmd, 60000)
    reaper.ShowConsoleMsg(validate_text .. "\n")
    if validate_code == 259 or looks_like_error(validate_text) then
        reaper.ShowMessageBox(
            "Target validation failed before render.\n\n" ..
            "Please check:\n" ..
            "  • Wwise is running\n" ..
            "  • WAAPI is enabled\n" ..
            "  • Wwise target path exists\n\n" ..
            "Details are in Reaper console output.",
            "ReaAssetFlow - Validation Failed", 0)
        return
    end

    -- Use a per-run staging directory to avoid mixing files from previous runs.
    local staging_dir = create_run_staging_dir()

    -- Save + override render directory AND filename pattern
    local _, prev_render_file    = reaper.GetSetProjectInfo_String(0, "RENDER_FILE",    "", false)
    local _, prev_render_pattern = reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "", false)
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE",    staging_dir, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$item",     true)

    -- Open render dialog — BLOCKS until user closes it
    reaper.ShowConsoleMsg(
        "[ReaAssetFlow] Render dialog opening...\n" ..
        "  Directory : " .. staging_dir .. "\n" ..
        "  Pattern   : $item\n" ..
        "  Please set: Source = 'Selected items (stems)'\n\n")
    reaper.Main_OnCommand(42230, 0)

    -- Restore original render settings
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE",    prev_render_file,    true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", prev_render_pattern, true)

    -- Collect rendered WAVs
    local wavs = list_wav_files(staging_dir)
    reaper.ShowConsoleMsg("[ReaAssetFlow] Scanning: " .. staging_dir .. "\n")
    reaper.ShowConsoleMsg("  Found " .. #wavs .. " WAV file(s)\n\n")

    if #wavs == 0 then
        reaper.ShowMessageBox(
            "No WAV files found in:\n" .. staging_dir ..
            "\n\nPossible causes:\n" ..
            "  • Render was cancelled\n" ..
            "  • Source was not set to 'Selected items (stems)'\n" ..
            "  • Filename pattern was not $item",
            "ReaAssetFlow", 0)
        return
    end

    reaper.ShowConsoleMsg("[ReaAssetFlow] Rendered " .. #wavs .. " file(s).\n")
    if not write_request_file(request_file, status_file, project_path, subfolder, target, operation, template_path, wavs, structures, item_context_map, selected_wwu) then
        reaper.ShowMessageBox(
            "Could not update request file for preview.",
            "ReaAssetFlow - Error", 0)
        return
    end

    reaper.ShowConsoleMsg("[ReaAssetFlow] Starting import...\n")

    -- Launch Python import script as a truly detached background process on Windows.
    -- This avoids relying on ExecProcess timeout behavior, which may terminate child processes.
    local cmd_parts = {
        "python",
        quote(python_script),
        "--request-file",        quote(request_file),
        "--delete-after",
    }
    local redirect_target = ">NUL 2>&1"
    if is_debug_mode_enabled() then
        redirect_target = "> " .. quote(build_import_process_log_path()) .. " 2>&1"
    end
    local detached_cmd = "cmd /c start \"\" /B " .. table.concat(cmd_parts, " ")
        .. " " .. redirect_target
    local ok = os.execute(detached_cmd)
    if not ok then
        delete_dir(staging_dir)
        reaper.ShowMessageBox(
            "Failed to launch background import process.",
            "ReaAssetFlow - Import Failed", 0)
        return
    end
    reaper.ShowConsoleMsg(
        "[ReaAssetFlow] Import process started in detached background mode.\n" ..
        "  Reaper remains usable. Monitoring status file...\n")
    reaper.ShowMessageBox(
        "Import is running in background.\n\n" ..
        "Reaper will stay responsive now.\n" ..
        "Please wait a bit and verify results in Wwise.",
        "ReaAssetFlow - Import In Progress", 0)
    monitor_import_status(status_file, #wavs, subfolder, target, reaper.time_precise(), staging_dir)
    return
end

local function query_work_unit_candidates(project_path)
    local python_script = repo_root() .. "scripts\\wwise_import.py"
    local request_file = build_request_file_path()
    local status_file = build_query_status_file_path()
    local result_file = build_query_result_file_path()
    os.remove(status_file)
    os.remove(result_file)
    if not write_request_file(request_file, status_file, project_path, "Imported", "\\Actor-Mixer Hierarchy", "useExisting", "", {}, {}, {}) then
        return nil, "Cannot create request file."
    end
    local list_cmd = table.concat({
        "python",
        quote(python_script),
        "--request-file", quote(request_file),
        "--list-work-units",
        "--list-base-path", quote("\\Actor-Mixer Hierarchy"),
        "--expected-project-path", quote(project_path),
        "--result-file", quote(result_file),
    }, " ")
    local code, text = run_process(list_cmd, 90000)
    reaper.ShowConsoleMsg(text .. "\n")
    if code == 259 then
        return nil, "WorkUnit query timed out."
    end
    if code and code ~= 0 then
        local q_state, q_msg = parse_status_message(status_file)
        if q_state == "error" and trim(q_msg or "") ~= "" then
            return nil, "WorkUnit query failed: " .. q_msg
        end
        return nil, string.format("WorkUnit query failed (exit code: %d).", code)
    end
    local wwus = parse_result_items_file(result_file)
    if #wwus == 0 then
        wwus = parse_wwu_candidates(text)
    end
    if #wwus == 0 then
        local q_state, q_msg = parse_status_message(status_file)
        if q_state == "error" then
            return nil, "WorkUnit query failed: " .. (q_msg or "unknown error")
        end
        if looks_like_error(text) then
            return nil, "WorkUnit query failed."
        end
        return nil, "No WorkUnits found."
    end
    return wwus, nil
end

local function query_target_candidates_once(project_path, base_path, depth, timeout_ms)
    local python_script = repo_root() .. "scripts\\wwise_import.py"
    local request_file = build_request_file_path()
    local status_file = build_query_status_file_path()
    local result_file = build_query_result_file_path()
    os.remove(status_file)
    os.remove(result_file)
    local normalized_base = normalize_target_path(base_path)
    if not write_request_file(request_file, status_file, project_path, "Imported", normalized_base, "useExisting", "", {}, {}, {}) then
        return nil, "Cannot create request file."
    end
    local list_cmd = table.concat({
        "python",
        quote(python_script),
        "--request-file", quote(request_file),
        "--list-import-targets",
        "--list-base-path", quote(normalized_base),
        "--expected-project-path", quote(project_path),
        "--list-depth", tostring(depth or 0),
        "--result-file", quote(result_file),
    }, " ")
    local code, text = run_process(list_cmd, timeout_ms or 90000)
    reaper.ShowConsoleMsg(text .. "\n")
    if code == 259 then
        return nil, "Target query timed out.", true
    end
    if code and code ~= 0 then
        local q_state, q_msg = parse_status_message(status_file)
        if q_state == "error" and trim(q_msg or "") ~= "" then
            return nil, "Target query failed: " .. q_msg, false
        end
        return nil, string.format("Target query failed (exit code: %d).", code), false
    end
    local targets = parse_result_items_file(result_file)
    if #targets == 0 then
        targets = parse_target_candidates(text)
    end
    if #targets == 0 then
        local q_state, q_msg = parse_status_message(status_file)
        if q_state == "error" then
            return nil, "Target query failed: " .. (q_msg or "unknown error"), false
        end
        if looks_like_error(text) then
            return nil, "Target query failed.", false
        end
        return nil, "No candidates.", false
    end
    return targets, nil, false
end

local function query_target_candidates(project_path, base_path)
    -- Large Wwise trees can timeout at full-depth traversal from Reaper.
    -- Try bounded-depth queries progressively and keep the deepest/biggest result.
    local attempts = {
        { depth = 2, timeout_ms = 15000 },
        { depth = 4, timeout_ms = 25000 },
        -- Deep probe only: try to get more levels, but never stall the UI for long.
        { depth = 6, timeout_ms = 8000 },
    }
    local last_err = "Target query failed."
    local saw_timeout = false
    local best_targets = nil
    local best_depth = -1
    local best_count = 0
    for _, a in ipairs(attempts) do
        local targets, err, timed_out = query_target_candidates_once(project_path, base_path, a.depth, a.timeout_ms)
        if targets and #targets > 0 then
            local count = #targets
            -- Prefer deeper successful scan; if same depth, prefer more items.
            if (a.depth > best_depth) or (a.depth == best_depth and count > best_count) then
                best_targets = targets
                best_depth = a.depth
                best_count = count
            end
            -- Keep probing deeper to get as complete as possible.
        end
        if err and err ~= "" then
            last_err = err
        end
        if timed_out then
            saw_timeout = true
            -- Once deeper levels timeout, stop escalating to avoid long UI stalls.
            if best_targets and #best_targets > 0 then
                break
            end
        elseif err and err ~= "No candidates." then
            -- Non-timeout failures are usually deterministic; no need to keep retrying.
            if best_targets and #best_targets > 0 then
                break
            end
            break
        end
    end
    if best_targets and #best_targets > 0 then
        return best_targets, nil
    end
    if saw_timeout and (not last_err or last_err == "" or last_err == "Target query timed out.") then
        return nil, "Target query timed out (tree is too large). Try selecting a deeper WorkUnit node."
    end
    return nil, last_err
end

local function pick_project_file(default_path)
    local ok, path = reaper.GetUserFileNameForRead(default_path or "", "Select Wwise Project", ".wproj")
    if ok then return path end
    return nil
end

local function get_originals_sfx_root(project_path)
    local p = tostring(project_path or "")
    if p == "" then return "" end
    local dir = p:match("^(.*)[/\\][^/\\]+$") or p
    local root = (dir:gsub("[/\\]+$", "")) .. "\\Originals\\SFX"
    return root
end

local function build_originals_folder_path(project_path, subfolder)
    local root = normalize_folder_path(get_originals_sfx_root(project_path))
    if root == "" then
        return ""
    end
    local rel = normalize_subfolder(subfolder)
    if rel == "" then
        return root
    end
    return root .. "\\" .. rel:gsub("/", "\\")
end

local function pick_folder(initial_dir)
    local function extract_abs_path(text)
        for line in tostring(text or ""):gmatch("[^\r\n]+") do
            local v = trim(line)
            if v:match("^[A-Za-z]:[\\/].+") or v:match("^\\\\[^\\]+\\[^\\]+") then
                return v
            end
        end
        return nil
    end

    -- Prefer an Explorer-style folder picker on Windows.
    if reaper.GetOS():match("Win") then
        local init = tostring(initial_dir or ""):gsub("'", "''")
        local ps = table.concat({
            "Add-Type -AssemblyName System.Windows.Forms;",
            "$d=New-Object System.Windows.Forms.OpenFileDialog;",
            "$d.InitialDirectory='" .. init .. "';",
            "$d.Filter='Folders|*.*';",
            "$d.CheckFileExists=$false;",
            "$d.ValidateNames=$false;",
            "$d.FileName='Select Folder';",
            "if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){",
            "  [Console]::OutputEncoding=[System.Text.Encoding]::UTF8;",
            "  Write-Output (Split-Path $d.FileName -Parent)",
            "}"
        }, "")
        local cmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command " .. quote(ps)
        local _, out = run_process(cmd, 120000)
        local folder = extract_abs_path(out)
        if folder then
            return normalize_folder_path(folder)
        end
    end

    -- Fallbacks for non-Windows or unavailable PowerShell UI.
    if reaper.JS_Dialog_BrowseForFolder then
        return reaper.JS_Dialog_BrowseForFolder("Select Originals Subfolder", initial_dir or "")
    end
    if reaper.CF_Dialog_BrowseForFolder then
        local folder = reaper.CF_Dialog_BrowseForFolder("Select Originals Folder", initial_dir or "")
        if folder and folder ~= "" then
            return folder
        end
    end
    local ok, csv = reaper.GetUserInputs(
        "Originals Folder Path",
        1,
        "Absolute folder path:,extrawidth=520",
        initial_dir or ""
    )
    if not ok then return nil end
    local folder = trim(csv)
    if folder == "" then return nil end
    return folder
end

local function to_subfolder_from_folder(folder_path)
    local normalized = tostring(folder_path or ""):gsub("\\", "/")
    local lower = normalized:lower()
    local marker = "/originals/sfx/"
    local idx = lower:find(marker, 1, true)
    if idx then
        local sub = normalized:sub(idx + #marker)
        sub = sub:gsub("^/+", ""):gsub("/+$", "")
        return sub
    end
    -- Fallback: use leaf folder name when path is outside Originals/SFX.
    local leaf = normalized:match("([^/]+)$") or normalized
    return leaf
end

local function subfolder_from_originals_path(project_path, originals_path)
    local root = normalize_folder_path(get_originals_sfx_root(project_path))
    local full = normalize_folder_path(originals_path)
    if root == "" or full == "" then
        return nil
    end
    local root_l = root:lower()
    local full_l = full:lower()
    if full_l == root_l then
        return ""
    end
    local prefix = root_l .. "\\"
    if full_l:sub(1, #prefix) ~= prefix then
        return nil
    end
    local rel = full:sub(#root + 2):gsub("\\", "/")
    return normalize_subfolder(rel)
end

-- === STRUCTURE PREVIEW ===

local OBJECT_TYPE_TAGS = {
    ["Random Container"] = "<Random Container>",
    ["Blend Container"] = "<Blend Container>",
    ["Actor Mixer"] = "<Actor-Mixer>",
    ["Folder"] = "<Folder>",
    ["Sound SFX"] = "<Sound SFX>",
}

local OBJECT_TYPE_COMBO_ITEMS = "Random Container\0Blend Container\0Actor Mixer\0Folder\0Sound SFX\0"
local OBJECT_TYPE_TO_IDX = {
    ["Random Container"] = 0,
    ["Blend Container"]  = 1,
    ["Actor Mixer"]      = 2,
    ["Folder"]           = 3,
    ["Sound SFX"]        = 4,
}
local OBJECT_IDX_TO_TYPE = {
    [0] = "Random Container",
    [1] = "Blend Container",
    [2] = "Actor Mixer",
    [3] = "Folder",
    [4] = "Sound SFX",
}

local function apply_name_pattern(pattern, context)
    local out = tostring(pattern or "")
    for key, value in pairs(context or {}) do
        out = out:gsub("%$" .. key, tostring(value or ""))
    end
    return out
end

local function build_structured_object_path_preview(import_target, item_name, item_ctx, structures)
    local target = normalize_target_path(import_target):gsub("\\+$", "")
    local marker_value = tostring((item_ctx and item_ctx.marker) or item_name)
    local track_value = tostring((item_ctx and item_ctx.track) or item_name)
    local raw_item = tostring((item_ctx and item_ctx.item) or item_name)
    local item_value = raw_item:match("^(.+)%.wav$") or raw_item
    local context = {
        item = item_value,
        track = track_value,
        marker = marker_value,
        region = tostring((item_ctx and item_ctx.region) or item_name),
        parent = item_name,
    }
    local parts = {}
    for _, row in ipairs(structures or {}) do
        local obj_type = trim(row.object_type or "")
        local name_pattern = trim(row.object_name or "")
        if obj_type ~= "" then
            local tag = OBJECT_TYPE_TAGS[obj_type]
            if tag then
                local obj_name = trim(apply_name_pattern(name_pattern, context))
                if obj_name == "" then obj_name = item_name end
                parts[#parts + 1] = tag .. obj_name
            end
        end
    end
    if #parts == 0 then
        parts[#parts + 1] = OBJECT_TYPE_TAGS["Sound SFX"] .. item_name
    end
    local has_sfx = false
    for _, p in ipairs(parts) do
        if p:sub(1, #OBJECT_TYPE_TAGS["Sound SFX"]) == OBJECT_TYPE_TAGS["Sound SFX"] then
            has_sfx = true
            break
        end
    end
    if not has_sfx then
        parts[#parts + 1] = OBJECT_TYPE_TAGS["Sound SFX"] .. item_name
    end
    return target .. "\\" .. table.concat(parts, "\\")
end

-- Path below Import Destination (no redundant \\Actor-Mixer Hierarchy\\... prefix in preview).
local function path_under_import_target(import_target, full_path)
    local base = normalize_target_path(import_target):gsub("\\+$", "")
    local path = normalize_target_path(full_path)
    if base == "" or path == "" then
        return path
    end
    local bl, pl = base:lower(), path:lower()
    if #pl < #bl or pl:sub(1, #bl) ~= bl then
        return path
    end
    if #pl == #bl then
        return "."
    end
    if pl:sub(#bl + 1, #bl + 1) ~= "\\" then
        return path
    end
    local rest = path:sub(#base + 2)
    if rest == "" then return "." end
    return rest
end

local function structure_uses_track_dimension(structures)
    for _, row in ipairs(structures or {}) do
        local name_pattern = tostring(row.object_name or "")
        if name_pattern:find("$track", 1, true) or name_pattern:find("$track_id", 1, true) then
            return true
        end
    end
    return false
end

local function collect_item_context_stats(item_context_map)
    local entries = {}
    local track_set = {}
    for item_name, ctx in pairs(item_context_map or {}) do
        entries[#entries + 1] = { item = item_name, ctx = ctx or {} }
        local track_name = trim((ctx and ctx.track) or "")
        if track_name ~= "" then
            track_set[track_name] = true
        end
    end
    table.sort(entries, function(a, b) return a.item < b.item end)
    local track_count = 0
    for _ in pairs(track_set) do track_count = track_count + 1 end
    return entries, track_count
end

-- max_lines: 0 = no rows (still counts duplicates over all items);
--            <0 = no cap (show all);
--            >0 = cap rows for UI.
local function build_structure_preview_rows(import_target, structures, item_context_map, max_lines)
    local entries = collect_item_context_stats(item_context_map)
    local rows = {}
    local path_counts = {}
    local shown = 0
    max_lines = max_lines or 8
    for _, entry in ipairs(entries) do
        local path = build_structured_object_path_preview(import_target, entry.item, entry.ctx, structures)
        path_counts[path] = (path_counts[path] or 0) + 1
        local should_collect_row = false
        if max_lines < 0 then
            should_collect_row = true
        elseif max_lines > 0 and shown < max_lines then
            should_collect_row = true
        end
        if should_collect_row then
            shown = shown + 1
            local rel = path_under_import_target(import_target, path)
            local target_norm = normalize_target_path(import_target)
            local outside = false
            if target_norm ~= "" then
                outside = normalize_target_path(rel):lower() == normalize_target_path(path):lower()
            end
            rows[#rows + 1] = {
                item = entry.item,
                relative = rel,
                full = path,
                outside = outside,
            }
        end
    end
    local duplicate_paths = 0
    for _, count in pairs(path_counts) do
        if count > 1 then duplicate_paths = duplicate_paths + 1 end
    end
    return rows, duplicate_paths, #entries
end

local SFX_TYPE_TAG = OBJECT_TYPE_TAGS["Sound SFX"]

-- Merge preview rows into a Wwise-like hierarchy (shared path prefixes folded).
local function build_preview_hierarchy(rows)
    local root = { children = {}, leaf_items = {}, outside = {} }
    local function insert_segments(node, segs, idx, item_name)
        local seg = segs[idx]
        node._child_map = node._child_map or {}
        node.children = node.children or {}
        if not node._child_map[seg] then
            local child = { segment = seg, children = {} }
            node._child_map[seg] = child
            node.children[#node.children + 1] = child
        end
        local child = node._child_map[seg]
        if idx == #segs then
            child.leaf_items = child.leaf_items or {}
            child.leaf_items[#child.leaf_items + 1] = item_name
        else
            insert_segments(child, segs, idx + 1, item_name)
        end
    end
    for _, prow in ipairs(rows or {}) do
        if prow.outside then
            root.outside[#root.outside + 1] = prow
        else
            local rel = trim(tostring(prow.relative or ""))
            if rel == "" or rel == "." then
                root.leaf_items[#root.leaf_items + 1] = prow.item
            else
                local segs = {}
                -- Support both Windows and POSIX separators in preview paths.
                for part in rel:gmatch("[^\\/]+") do
                    part = trim(part)
                    if part ~= "" then segs[#segs + 1] = part end
                end
                if #segs == 0 then
                    root.leaf_items[#root.leaf_items + 1] = prow.item
                else
                    insert_segments(root, segs, 1, prow.item)
                end
            end
        end
    end
    return root
end

local function sort_preview_node_children(node)
    local ch = node.children or {}
    table.sort(ch, function(a, b)
        return tostring(a.segment or "") < tostring(b.segment or "")
    end)
end

local function sfx_leaf_redundant_segment(segment, item_name)
    if not segment or not item_name then return false end
    if segment:sub(1, #SFX_TYPE_TAG) ~= SFX_TYPE_TAG then return false end
    return segment:sub(#SFX_TYPE_TAG + 1) == item_name
end

-- Renders merged hierarchy; use_tree false = indented text fallback.
local function render_preview_hierarchy(ctx, node, depth, use_tree, indent)
    sort_preview_node_children(node)
    for i, ch in ipairs(node.children or {}) do
        if reaper.ImGui_PushID then
            reaper.ImGui_PushID(ctx, i + depth * 4096)
        end
        local seg = tostring(ch.segment or "")
        local kids = ch.children or {}
        local li = ch.leaf_items
        local n_kids = #kids
        local n_li = li and #li or 0
        local redundant_single = n_kids == 0 and n_li == 1 and sfx_leaf_redundant_segment(seg, li[1])

        if use_tree and (reaper.ImGui_TreeNodeEx or reaper.ImGui_TreeNode) then
            if redundant_single then
                if reaper.ImGui_BulletText then
                    reaper.ImGui_BulletText(ctx, seg)
                else
                    reaper.ImGui_Text(ctx, "· " .. seg)
                end
            else
                local flags = 0
                if depth <= 1 and reaper.ImGui_TreeNodeFlags_DefaultOpen then
                    local df = reaper.ImGui_TreeNodeFlags_DefaultOpen()
                    if df then flags = flags + df end
                end
                -- Keep visible label clean; unique ID is handled by PushID above.
                local label = seg
                local opened
                if reaper.ImGui_TreeNodeEx then
                    opened = reaper.ImGui_TreeNodeEx(ctx, flags, label)
                else
                    opened = reaper.ImGui_TreeNode(ctx, label)
                end
                if opened then
                    render_preview_hierarchy(ctx, ch, depth + 1, use_tree, indent + 1)
                    for _, it in ipairs(li or {}) do
                        if not sfx_leaf_redundant_segment(seg, it) then
                            if reaper.ImGui_BulletText then
                                reaper.ImGui_BulletText(ctx, tostring(it))
                            else
                                reaper.ImGui_Text(ctx, "  · " .. tostring(it))
                            end
                        end
                    end
                    if reaper.ImGui_TreePop then
                        reaper.ImGui_TreePop(ctx)
                    end
                end
            end
        else
            if redundant_single then
                reaper.ImGui_Text(ctx, string.rep("  ", indent) .. "· " .. seg)
            else
                reaper.ImGui_Text(ctx, string.rep("  ", indent) .. seg)
                render_preview_hierarchy(ctx, ch, depth + 1, false, indent + 1)
                for _, it in ipairs(li or {}) do
                    if not sfx_leaf_redundant_segment(seg, it) then
                        reaper.ImGui_Text(ctx, string.rep("  ", indent + 1) .. "· " .. tostring(it))
                    end
                end
            end
        end
        if reaper.ImGui_PopID then
            reaper.ImGui_PopID(ctx)
        end
    end
end

-- === PANEL STATE & UI ===

local function append_token_to_selected_row(state, token)
    local row = state.structures[state.selected_structure_idx]
    if not row then return end
    local current = tostring(row.object_name or "")
    if current == "" then
        row.object_name = token
    else
        row.object_name = current .. token
    end
end

local function run_imgui_ui()
    ensure_state_dir()
    local smoke_path = os.getenv("REAASSETFLOW_UI_SMOKE_RESULT")
    local smoke_written = false
    if not reaper.ImGui_CreateContext then
        reaper.ShowMessageBox("ReaImGui is required. Please install ReaImGui via ReaPack.", "ReaAssetFlow", 0)
        return
    end
    local ui_state = load_ui_state()
    local default_subfolder = ""
    local default_target = ""
    local state = {
        project_path = normalize_project_path(ui_state.project_path ~= "" and ui_state.project_path or ""),
        subfolder = ui_state.subfolder ~= "" and ui_state.subfolder or default_subfolder,
        target = ui_state.target ~= "" and ui_state.target or default_target,
        operation = ui_state.operation ~= "" and ui_state.operation or "useExisting",
        structures = clone_structures(DEFAULT_STRUCTURES),
        selected_structure_idx = 1,
        wwu_candidates = {},
        selected_wwu = "",
        candidates = {},
        target_choice_idx = 0,
        cache = load_target_cache(),
        reaper_project_path_key = current_reaper_project_path_key(),
        auto_initialized = false,
        last_project_path = "",
        status = "",
        preview_rows = {},
        auto_name_preview_rows = {},
        structure_preset_choice_idx = 0,
        template_path = trim(ui_state.template_path or ""),
        auto_name_pattern = non_empty_or(ui_state.auto_name_pattern, "$track_$marker_$idx2"),
        auto_name_index_scope = non_empty_or(ui_state.auto_name_index_scope, "track_marker"),
        auto_name_missing_marker_mode = non_empty_or(ui_state.auto_name_missing_marker_mode, "skip"),
        auto_name_fallback_marker = non_empty_or(ui_state.auto_name_fallback_marker, "NoMarker"),
        llm_model = "qwen2.5vl:7b",
        prerequisites = check_base_prerequisites(),
    }
    state.originals_path = build_originals_folder_path(state.project_path, state.subfolder)
    local last_saved_ui_key = nil

    -- Persist panel fields once a Wwise project is chosen (Import Destination may still be empty).
    local function save_ui_state_if_project_and_target()
        local project_ok = trim(state.project_path) ~= ""
        if not project_ok then
            return false
        end
        local sf = subfolder_from_originals_path(state.project_path, state.originals_path)
        local save_key = table.concat({
            trim(state.project_path),
            normalize_target_path(state.target),
            normalize_folder_path(state.originals_path),
            state.operation or "",
            sf or state.subfolder or "",
        }, "\x1f")
        if save_key == last_saved_ui_key then
            return false
        end
        save_ui_state(
            trim(state.project_path),
            sf or state.subfolder or default_subfolder or "",
            state.target,
            state.operation,
            state.template_path or "",
            state.auto_name_pattern or "",
            state.auto_name_index_scope or "",
            state.auto_name_missing_marker_mode or "",
            state.auto_name_fallback_marker or ""
        )
        last_saved_ui_key = save_key
        state.status = "Panel state saved."
        return true
    end

    local function reset_project_dependent_state()
        state.wwu_candidates = {}
        state.selected_wwu = ""
        state.candidates = {}
        state.target_choice_idx = 0
        state.target = ""
    end

    local function refresh_wwu_list(force_refresh, cache_only)
        -- No WorkUnit context: keep Import Destination empty so stale paths are not shown.
        local function clear_import_when_no_wwus()
            if #state.wwu_candidates == 0 then
                state.target = ""
                state.candidates = {}
                state.target_choice_idx = 0
                state.selected_wwu = ""
            end
        end

        if trim(state.project_path) == "" then
            state.status = "Project path is required to load WorkUnits."
            clear_import_when_no_wwus()
            return false
        end
        if not force_refresh then
            local cached = get_cached_wwus(state.cache, state.project_path)
            if #cached > 0 then
                state.wwu_candidates = cached
                local want = trim(state.selected_wwu or "")
                local want_missing = (want ~= "" and not wwu_path_in_list(cached, want))
                if want ~= "" and wwu_path_in_list(cached, want) then
                    state.selected_wwu = want
                else
                    local matched = pick_best_wwu_for_target(cached, state.target)
                    if matched then
                        state.selected_wwu = matched
                    elseif want == "" then
                        state.selected_wwu = cached[1]
                    else
                        state.selected_wwu = cached[1]
                    end
                end
                state.status = string.format("Loaded %d WorkUnits from cache.", #cached)
                if want_missing then
                    state.status = state.status .. " Stored Work Unit path is not in this project."
                end
                clear_import_when_no_wwus()
                return true
            end
            if cache_only then
                state.status = "No cached WorkUnits. Click Load WorkUnits."
                clear_import_when_no_wwus()
                return false
            end
        end
        state.status = "Loading WorkUnits from Wwise..."
        local wwus, err = query_work_unit_candidates(state.project_path)
        if err then
            state.wwu_candidates = {}
            state.selected_wwu = ""
            state.status = "WorkUnit query failed: " .. err
            clear_import_when_no_wwus()
            return false
        end
        state.wwu_candidates = wwus
        if #wwus > 0 then
            local want = trim(state.selected_wwu or "")
            local want_missing = (want ~= "" and not wwu_path_in_list(wwus, want))
            if want ~= "" and wwu_path_in_list(wwus, want) then
                state.selected_wwu = want
            else
                local matched = pick_best_wwu_for_target(wwus, state.target)
                if matched then
                    state.selected_wwu = matched
                elseif want == "" then
                    state.selected_wwu = wwus[1]
                else
                    state.selected_wwu = wwus[1]
                end
            end
            state.status = string.format("Loaded %d WorkUnits.", #wwus)
            if want_missing then
                state.status = state.status .. " Stored Work Unit path is not in this project."
            end
        else
            state.selected_wwu = ""
        end
        set_cached_wwus(state.cache, state.project_path, wwus)
        save_target_cache(state.cache)
        if #wwus == 0 then
            state.status = string.format("Loaded %d WorkUnits.", #wwus)
        end
        clear_import_when_no_wwus()
        return true
    end

    local function refresh_target_list(force_refresh)
        if trim(state.project_path) == "" then
            state.status = "Project path is required."
            return false
        end
        local base_path = normalize_target_path(state.selected_wwu)
        if base_path == "" then
            state.status = "Select a WorkUnit first."
            return false
        end
        if not force_refresh then
            local cached = get_cached_targets(state.cache, state.project_path, base_path)
            if #cached > 0 then
                state.candidates = cached
                state.target_choice_idx = 0
                state.status = string.format("Loaded %d targets from cache.", #cached)
                return true
            end
        end
        state.status = "Loading targets from selected WorkUnit..."
        local targets, err = query_target_candidates(state.project_path, base_path)
        if err then
            state.status = "Target query failed: " .. err
            return false
        end
        state.candidates = targets
        state.target_choice_idx = 0
        if #targets > 0 and trim(state.target) == "" then
            state.target = targets[1]
        end
        set_cached_targets(state.cache, state.project_path, base_path, targets)
        save_target_cache(state.cache)
        state.status = string.format("Loaded %d targets under WorkUnit.", #targets)
        return true
    end

    -- ReaImGui may draw built-in widget labels to the right of the control; use explicit
    -- titles above fields and ## ids so labels read naturally (title -> control).
    local function ui_section_title(ctx, title)
        if reaper.ImGui_Spacing then reaper.ImGui_Spacing(ctx) end
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, title)
    end

    local function ui_major_section_title(ctx, title)
        if reaper.ImGui_Spacing then reaper.ImGui_Spacing(ctx) end
        if reaper.ImGui_SeparatorText then
            reaper.ImGui_SeparatorText(ctx, title)
        else
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "== " .. title .. " ==")
            reaper.ImGui_Separator(ctx)
        end
        if reaper.ImGui_Spacing then reaper.ImGui_Spacing(ctx) end
    end

    local function ui_subsection_title(ctx, title)
        if reaper.ImGui_Spacing then reaper.ImGui_Spacing(ctx) end
        reaper.ImGui_Text(ctx, title)
    end

    local function ui_labeled_input(ctx, label, input_id, value)
        reaper.ImGui_Text(ctx, label)
        if reaper.ImGui_PushItemWidth then reaper.ImGui_PushItemWidth(ctx, -1) end
        local ch, v = reaper.ImGui_InputText(ctx, input_id, value)
        if reaper.ImGui_PushItemWidth then reaper.ImGui_PopItemWidth(ctx) end
        return ch, v
    end

    -- on_click may return a string to override the InputText buffer (Browse runs after InputText;
    -- without this, the stale `v` from InputText would overwrite the path picked in on_click).
    local function ui_labeled_input_with_button(ctx, label, input_id, value, right_reserve_px, button_label, on_click)
        reaper.ImGui_Text(ctx, label)
        if reaper.ImGui_PushItemWidth and right_reserve_px and right_reserve_px > 0 then
            reaper.ImGui_PushItemWidth(ctx, -right_reserve_px)
        end
        local ch, v = reaper.ImGui_InputText(ctx, input_id, value)
        if reaper.ImGui_PushItemWidth and right_reserve_px and right_reserve_px > 0 then
            reaper.ImGui_PopItemWidth(ctx)
        end
        reaper.ImGui_SameLine(ctx)
        local browse_override = nil
        local browse_changed = false
        if reaper.ImGui_Button(ctx, button_label) and on_click then
            browse_override = on_click()
            if browse_override ~= nil then
                browse_changed = true
            end
        end
        if browse_override ~= nil then
            v = browse_override
        end
        -- InputText alone stays false when only Browse updates the buffer.
        return (ch or browse_changed), v
    end

    local function ui_labeled_combo(ctx, label, combo_id, cur_idx, items_nullsep)
        reaper.ImGui_Text(ctx, label)
        if reaper.ImGui_PushItemWidth then reaper.ImGui_PushItemWidth(ctx, -1) end
        local ch, idx = reaper.ImGui_Combo(ctx, combo_id, cur_idx, items_nullsep)
        if reaper.ImGui_PushItemWidth then reaper.ImGui_PopItemWidth(ctx) end
        return ch, idx
    end

    local function render_auto_name_preview(scope_mode, scope_label)
        local plan_data, err = build_auto_name_plan(
            scope_mode,
            state.auto_name_pattern,
            state.auto_name_index_scope,
            state.auto_name_missing_marker_mode,
            state.auto_name_fallback_marker
        )
        if err then
            state.status = "Auto naming preview failed: " .. err
            state.auto_name_preview_rows = {}
            return
        end
        state.auto_name_preview_rows = {}

        if state.auto_name_index_scope == "track_marker" then
            local grouped = {}
            local group_order = {}
            for _, row in ipairs(plan_data.rows or {}) do
                local key = tostring(row.bucket or "")
                if not grouped[key] then
                    grouped[key] = {}
                    group_order[#group_order + 1] = key
                end
                local list = grouped[key]
                if #list < 3 then
                    list[#list + 1] = row.name
                end
            end
            table.sort(group_order)
            local max_groups = 12
            for i = 1, math.min(#group_order, max_groups) do
                local g = group_order[i]
                local track, marker = g:match("^(.-)\1(.-)$")
                if not track then
                    track = g
                    marker = ""
                end
                state.auto_name_preview_rows[#state.auto_name_preview_rows + 1] =
                    string.format("[Track: %s | Marker: %s]", tostring(track or ""), tostring(marker or ""))
                for _, nm in ipairs(grouped[g] or {}) do
                    state.auto_name_preview_rows[#state.auto_name_preview_rows + 1] = "  - " .. tostring(nm)
                end
            end
            state.status = string.format(
                "Auto naming preview (%s): showing first 3 names for %d/%d track+marker group(s), skipped %d item(s).",
                scope_label,
                math.min(#group_order, max_groups),
                #group_order,
                plan_data.skipped or 0
            )
        else
            local max_preview = 20
            for i = 1, math.min(#(plan_data.rows or {}), max_preview) do
                state.auto_name_preview_rows[#state.auto_name_preview_rows + 1] = plan_data.rows[i].name
            end
            state.status = string.format(
                "Auto naming preview (%s): showing %d/%d name(s), skipped %d item(s).",
                scope_label,
                #state.auto_name_preview_rows,
                #(plan_data.rows or {}),
                plan_data.skipped or 0
            )
        end
    end

    local ctx = reaper.ImGui_CreateContext("ReaAssetFlow")
    local function loop()
        local sel_count = reaper.CountSelectedMediaItems(0)
        if reaper.ImGui_SetNextWindowSize then
            local cond = (reaper.ImGui_Cond_FirstUseEver and reaper.ImGui_Cond_FirstUseEver()) or 24
            reaper.ImGui_SetNextWindowSize(ctx, 560, 720, cond)
        end
        local visible, open = reaper.ImGui_Begin(ctx, "ReaAssetFlow", true)
        if visible then
            local rp_key = current_reaper_project_path_key()
            if rp_key ~= state.reaper_project_path_key then
                state.reaper_project_path_key = rp_key
                state.cache = load_target_cache()
                reset_project_dependent_state()
                if trim(state.project_path) ~= "" then
                    refresh_wwu_list(false, true)
                end
                state.status = "Reaper project changed; cache folder switched."
            end
            if (not state.auto_initialized) and trim(state.project_path) ~= "" then
                refresh_wwu_list(false, true)
                state.last_project_path = state.project_path
                state.auto_initialized = true
            end

            if state.prerequisites.ok then
                reaper.ImGui_Text(ctx, state.prerequisites.summary)
            else
                reaper.ImGui_Text(ctx, state.prerequisites.summary)
                if reaper.ImGui_TextWrapped then
                    reaper.ImGui_TextWrapped(ctx, state.prerequisites.detail)
                else
                    reaper.ImGui_Text(ctx, state.prerequisites.detail)
                end
                if reaper.ImGui_Button(ctx, "Open installation folder##setup") then
                    dev_open_folder_next_tick(repo_root())
                end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "Check Again##setup") then
                    state.prerequisites = check_base_prerequisites()
                    state.status = state.prerequisites.ok and
                        "Setup check passed." or state.prerequisites.detail
                end
                reaper.ImGui_Separator(ctx)
            end

            ui_major_section_title(ctx, "Auto Renamer")
            changed, state.auto_name_pattern = ui_labeled_input(ctx, "Name pattern", "##rtw_autoname_pattern", state.auto_name_pattern)
            state.auto_name_pattern = non_empty_or(state.auto_name_pattern, "$track_$marker_$idx2")
            reaper.ImGui_Text(ctx, "Tokens:")
            if reaper.ImGui_Button(ctx, "$track##autoname") then state.auto_name_pattern = (state.auto_name_pattern or "") .. "$track" end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "$marker##autoname") then state.auto_name_pattern = (state.auto_name_pattern or "") .. "$marker" end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "$region##autoname") then state.auto_name_pattern = (state.auto_name_pattern or "") .. "$region" end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "$idx##autoname") then state.auto_name_pattern = (state.auto_name_pattern or "") .. "$idx" end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "$idx2##autoname") then state.auto_name_pattern = (state.auto_name_pattern or "") .. "$idx2" end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "$idx3##autoname") then state.auto_name_pattern = (state.auto_name_pattern or "") .. "$idx3" end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Suggest Pattern via LLM##autoname") then
                if not state.prerequisites.ok then
                    state.status = state.prerequisites.detail
                elseif sel_count == 0 then
                    state.status = "Select items first so LLM has context to analyse."
                else
                    local llm_script = repo_root() .. "scripts\\llm_assist.py"
                    local tracks, markers, items = collect_llm_context()
                    state.status = string.format(
                        "Asking LLM (tracks: %d, markers: %d, items: %d)...",
                        #tracks, #markers, #items)
                    local pattern, err = run_llm_suggest_pattern(
                        llm_script, state.llm_model, tracks, markers, items)
                    if err then
                        state.status = "LLM error: " .. err
                        reaper.ShowConsoleMsg("[ReaAssetFlow LLM] " .. err .. "\n")
                    else
                        state.auto_name_pattern = pattern
                        state.status = "LLM suggested pattern: " .. pattern
                    end
                end
            end

            local idx_scope_items = "Per track + marker\0Per marker\0Global\0"
            local idx_scope_idx = (state.auto_name_index_scope == "marker" and 1) or (state.auto_name_index_scope == "global" and 2) or 0
            changed, idx_scope_idx = ui_labeled_combo(ctx, "Index scope", "##rtw_autoname_scope", idx_scope_idx, idx_scope_items)
            state.auto_name_index_scope = (idx_scope_idx == 1 and "marker") or (idx_scope_idx == 2 and "global") or "track_marker"

            local missing_items = "Skip items without marker\0Use fallback marker name\0"
            local missing_idx = (state.auto_name_missing_marker_mode == "fallback" and 1) or 0
            changed, missing_idx = ui_labeled_combo(ctx, "Missing marker", "##rtw_autoname_missing", missing_idx, missing_items)
            state.auto_name_missing_marker_mode = (missing_idx == 1) and "fallback" or "skip"
            if state.auto_name_missing_marker_mode == "fallback" then
                changed, state.auto_name_fallback_marker = ui_labeled_input(ctx, "Fallback marker name", "##rtw_autoname_fallback", state.auto_name_fallback_marker)
                state.auto_name_fallback_marker = non_empty_or(state.auto_name_fallback_marker, "NoMarker")
            end

            if reaper.ImGui_Button(ctx, "Preview Names (Selected Items)") then
                render_auto_name_preview("selected_items", "selected items")
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Preview Names (Selected Tracks)") then
                render_auto_name_preview("selected_tracks", "selected tracks")
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Clear Preview") then
                state.auto_name_preview_rows = {}
                state.status = "Auto naming preview cleared."
            end

            if reaper.ImGui_Button(ctx, "Auto Name (Selected Items)") then
                local confirm_msg =
                    "Apply auto naming to selected items?\n\n" ..
                    "This will overwrite item notes and active take names."
                if reaper.ShowMessageBox(confirm_msg, "ReaAssetFlow - Confirm Auto Naming", 4) == 6 then
                    local result, err = auto_name_items_by_track_and_marker(
                        "selected_items",
                        state.auto_name_pattern,
                        state.auto_name_index_scope,
                        state.auto_name_missing_marker_mode,
                        state.auto_name_fallback_marker
                    )
                    if err then
                        state.status = "Auto naming failed: " .. err
                    else
                        state.status = string.format(
                            "Auto naming done (selected items): named %d item(s), skipped %d item(s) before first marker.",
                            result.renamed or 0,
                            result.skipped or 0
                        )
                    end
                else
                    state.status = "Auto naming cancelled."
                end
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Auto Name (Selected Tracks)") then
                local confirm_msg =
                    "Apply auto naming to ALL items on selected tracks?\n\n" ..
                    "This will overwrite item notes and active take names."
                if reaper.ShowMessageBox(confirm_msg, "ReaAssetFlow - Confirm Auto Naming", 4) == 6 then
                    local result, err = auto_name_items_by_track_and_marker(
                        "selected_tracks",
                        state.auto_name_pattern,
                        state.auto_name_index_scope,
                        state.auto_name_missing_marker_mode,
                        state.auto_name_fallback_marker
                    )
                    if err then
                        state.status = "Auto naming failed: " .. err
                    else
                        state.status = string.format(
                            "Auto naming done (selected tracks): named %d item(s), skipped %d item(s) before first marker.",
                            result.renamed or 0,
                            result.skipped or 0
                        )
                    end
                else
                    state.status = "Auto naming cancelled."
                end
            end
            if #state.auto_name_preview_rows > 0 then
                if state.auto_name_index_scope == "track_marker" then
                    reaper.ImGui_Text(ctx, "Preview (per track+marker: first 3 each):")
                else
                    reaper.ImGui_Text(ctx, "Preview (first 20 names):")
                end
                for _, n in ipairs(state.auto_name_preview_rows) do
                    if tostring(n):sub(1, 1) == "[" then
                        reaper.ImGui_Text(ctx, tostring(n))
                    elseif reaper.ImGui_BulletText then
                        reaper.ImGui_BulletText(ctx, tostring(n))
                    else
                        reaper.ImGui_Text(ctx, "  · " .. tostring(n))
                    end
                end
            end

            if reaper.ImGui_Spacing then reaper.ImGui_Spacing(ctx) end
            ui_major_section_title(ctx, "Wwise Importer")
            ui_subsection_title(ctx, "Presets")
            do
                local presets_dir = normalize_folder_path(storage.presets_dir)
                local preset_paths = enumerate_structure_preset_files(presets_dir)
                if state.structure_preset_choice_idx >= #preset_paths then
                    state.structure_preset_choice_idx = math.max(0, #preset_paths - 1)
                end
                if reaper.ImGui_Button(ctx, "Save panel preset…") then
                    local ok, csv = reaper.GetUserInputs(
                        "Save panel preset",
                        1,
                        "Preset name:,extrawidth=360",
                        ""
                    )
                    if ok then
                        local display_name = trim(csv or "")
                        if display_name == "" then
                            state.status = "Preset name is empty; not saved."
                        else
                            local written, err = write_panel_preset_file(presets_dir, display_name, state)
                            if not written then
                                state.status = err or "Failed to save preset."
                            else
                                state.status = "Saved preset: " .. preset_basename(written)
                            end
                        end
                    end
                end
                if #preset_paths > 0 then
                    local names = {}
                    for _, p in ipairs(preset_paths) do
                        names[#names + 1] = preset_basename(p)
                    end
                    local combo = table.concat(names, "\0") .. "\0"
                    local ch, idx = ui_labeled_combo(ctx, "Load preset", "##rtw_struct_preset", state.structure_preset_choice_idx, combo)
                    state.structure_preset_choice_idx = idx
                    if reaper.ImGui_Button(ctx, "Load selected preset") then
                        local p = preset_paths[state.structure_preset_choice_idx + 1]
                        if p then
                            local def_proj = ""
                            local def_target = default_target
                            local def_op = "useExisting"
                            local data, err = read_panel_preset_file(p, default_subfolder, def_proj, def_target, def_op)
                            if not data then
                                state.status = err or "Failed to load preset."
                            else
                                state.project_path = normalize_project_path(data.project_path or "")
                                state.originals_path = normalize_folder_path(data.originals_path or "")
                                state.target = data.target or ""
                                state.operation = data.operation or "useExisting"
                                state.selected_wwu = data.selected_wwu or ""
                                state.template_path = data.template_path or ""
                                state.auto_name_pattern = non_empty_or(data.auto_name_pattern, "$track_$marker_$idx2")
                                state.auto_name_index_scope = non_empty_or(data.auto_name_index_scope, "track_marker")
                                state.auto_name_missing_marker_mode = non_empty_or(data.auto_name_missing_marker_mode, "skip")
                                state.auto_name_fallback_marker = non_empty_or(data.auto_name_fallback_marker, "NoMarker")
                                state.structures = clone_structures(data.structures)
                                state.selected_structure_idx = math.max(1, math.min(data.selected_structure_idx or 1, #state.structures))
                                state.subfolder = subfolder_from_originals_path(state.project_path, state.originals_path)
                                    or default_subfolder
                                state.preview_rows = {}
                                state.candidates = {}
                                state.target_choice_idx = 0
                                state.last_project_path = state.project_path
                                state.cache = load_target_cache()
                                refresh_wwu_list(false, false)
                                refresh_target_list(false)
                                local sf = subfolder_from_originals_path(state.project_path, state.originals_path)
                                save_ui_state(
                                    trim(state.project_path),
                                    sf or default_subfolder or "",
                                    state.target,
                                    state.operation,
                                    state.template_path or "",
                                    state.auto_name_pattern or "",
                                    state.auto_name_index_scope or "",
                                    state.auto_name_missing_marker_mode or "",
                                    state.auto_name_fallback_marker or ""
                                )
                                state.status = "Loaded preset: " .. (data.name or preset_basename(p))
                            end
                        end
                    end
                    reaper.ImGui_SameLine(ctx)
                    if reaper.ImGui_Button(ctx, "Delete selected preset") then
                        local p = preset_paths[state.structure_preset_choice_idx + 1]
                        if p and reaper.ShowMessageBox(
                            "Delete this preset file?\n\n" .. p,
                            "ReaAssetFlow",
                            4
                        ) == 6 then
                            os.remove(p)
                            state.structure_preset_choice_idx = 0
                            state.status = "Deleted preset."
                        end
                    end
                end
            end

            ui_section_title(ctx, "Wwise project & media")

            if trim(state.project_path) == "" then
                if reaper.ImGui_TextWrapped then
                    reaper.ImGui_TextWrapped(ctx, "Select a .wproj (Browse Project).")
                else
                    reaper.ImGui_Text(ctx, "Select a .wproj (Browse Project).")
                end
            end

            local changed
            changed, state.project_path = ui_labeled_input_with_button(ctx, "Project Path", "##rtw_pp", state.project_path, 150, "Browse Project", function()
                local picked = pick_project_file(state.project_path)
                if picked then
                    state.project_path = normalize_project_path(picked)
                    if state.subfolder ~= nil then
                        state.originals_path = build_originals_folder_path(state.project_path, state.subfolder)
                    end
                    reset_project_dependent_state()
                    state.status = "Project changed. Refresh WorkUnits."
                    return state.project_path
                end
                return nil
            end)
            state.project_path = normalize_project_path(state.project_path)
            local project_path_changed = changed
            if state.last_project_path ~= state.project_path then
                reset_project_dependent_state()
                state.status = "Project path changed. Refresh WorkUnits."
                state.last_project_path = state.project_path
                project_path_changed = true
            end
            if project_path_changed then
                save_ui_state_if_project_and_target()
            end

            changed, state.originals_path = ui_labeled_input_with_button(ctx, "Originals Folder Path", "##rtw_orig", state.originals_path, 140, "Browse Folder", function()
                local base_dir = get_originals_sfx_root(state.project_path)
                local picked_folder = pick_folder(base_dir)
                if picked_folder and picked_folder ~= "" then
                    local norm = normalize_folder_path(picked_folder)
                    state.originals_path = norm
                    state.status = "Originals folder selected."
                    return norm
                end
                state.status = "Folder picker cancelled or returned invalid path."
                return nil
            end)
            if changed and trim(state.project_path) ~= "" then
                save_ui_state_if_project_and_target()
            end

            local ops = "useExisting\0createNew\0replaceExisting\0"
            local op_idx = (state.operation == "createNew" and 1) or (state.operation == "replaceExisting" and 2) or 0
            changed, op_idx = ui_labeled_combo(ctx, "If Name Exists", "##rtw_op", op_idx, ops)
            state.operation = (op_idx == 1 and "createNew") or (op_idx == 2 and "replaceExisting") or "useExisting"
            if state.operation == "useExisting" then
                reaper.ImGui_Text(ctx, "Behavior: reuse existing objects and create missing ones.")
            elseif state.operation == "createNew" then
                reaper.ImGui_Text(ctx, "Behavior: always create new objects (duplicates possible).")
            else
                reaper.ImGui_Text(ctx, "Behavior: replace existing objects only.")
            end

            ui_section_title(ctx, "Work units & import target")
            if reaper.ImGui_Button(ctx, "Load WorkUnits") then
                refresh_wwu_list(true)
            end
            if #state.wwu_candidates > 0 then
                local wwu_labels = table.concat(state.wwu_candidates, "\0") .. "\0"
                local wwu_idx = 0
                for i, wwu in ipairs(state.wwu_candidates) do
                    if wwu == state.selected_wwu then
                        wwu_idx = i - 1
                        break
                    end
                end
                changed, wwu_idx = ui_labeled_combo(ctx, "WorkUnit", "##rtw_wwu", wwu_idx, wwu_labels)
                local new_wwu = state.wwu_candidates[wwu_idx + 1] or state.selected_wwu
                if new_wwu ~= state.selected_wwu then
                    state.selected_wwu = new_wwu
                    state.candidates = {}
                    state.target_choice_idx = 0
                    if not refresh_target_list(true) then
                        state.status = "WorkUnit changed. Click Load Targets From WorkUnit if needed."
                    end
                end
            end
            if reaper.ImGui_Button(ctx, "Load Targets From WorkUnit") then
                refresh_target_list(false)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Force Refresh Targets") then
                refresh_target_list(true)
            end
            if #state.candidates > 0 then
                -- Keep combo selection aligned with current target path from preset/manual input.
                local matched_idx = nil
                for i, c in ipairs(state.candidates) do
                    if c == state.target then
                        matched_idx = i - 1
                        break
                    end
                end
                if matched_idx ~= nil then
                    state.target_choice_idx = matched_idx
                elseif state.target_choice_idx < 0 or state.target_choice_idx >= #state.candidates then
                    state.target_choice_idx = 0
                end
                local labels = table.concat(state.candidates, "\0") .. "\0"
                changed, state.target_choice_idx = ui_labeled_combo(ctx, "Target", "##rtw_sugtgt", state.target_choice_idx, labels)
                local chosen = state.candidates[state.target_choice_idx + 1] or ""
                if changed and chosen ~= "" then
                    state.target = chosen
                    save_ui_state_if_project_and_target()
                end
            end
            changed, state.target = ui_labeled_input(ctx, "Import Destination", "##rtw_dest", state.target)
            if changed then
                save_ui_state_if_project_and_target()
            end

            ui_section_title(ctx, "Wwise structures")
            for i, row in ipairs(state.structures) do
                local label = string.format("%d) %s | %s", i, row.object_type or "", row.object_name or "")
                local selected = (state.selected_structure_idx == i)
                if reaper.ImGui_Selectable(ctx, label, selected) then
                    state.selected_structure_idx = i
                end
            end
            if #state.structures == 0 then
                reaper.ImGui_Text(ctx, "(No structure rows)")
            end

            if reaper.ImGui_Button(ctx, "Add Row") then
                state.structures[#state.structures + 1] = { object_type = "Sound SFX", object_name = "$item" }
                state.selected_structure_idx = #state.structures
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Delete Row") then
                if #state.structures > 0 and state.selected_structure_idx >= 1 then
                    table.remove(state.structures, state.selected_structure_idx)
                    if state.selected_structure_idx > #state.structures then
                        state.selected_structure_idx = #state.structures
                    end
                    if state.selected_structure_idx < 1 then
                        state.selected_structure_idx = 1
                    end
                end
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Move Up") then
                local i = state.selected_structure_idx
                if i and i > 1 and i <= #state.structures then
                    state.structures[i], state.structures[i - 1] = state.structures[i - 1], state.structures[i]
                    state.selected_structure_idx = i - 1
                end
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Move Down") then
                local i = state.selected_structure_idx
                if i and i >= 1 and i < #state.structures then
                    state.structures[i], state.structures[i + 1] = state.structures[i + 1], state.structures[i]
                    state.selected_structure_idx = i + 1
                end
            end

            local edit_row = state.structures[state.selected_structure_idx]
            if edit_row then
                local type_idx = OBJECT_TYPE_TO_IDX[edit_row.object_type] or 4
                changed, type_idx = ui_labeled_combo(ctx, "Row object type", "##rtw_rowtype", type_idx, OBJECT_TYPE_COMBO_ITEMS)
                edit_row.object_type = OBJECT_IDX_TO_TYPE[type_idx] or "Sound SFX"
                changed, edit_row.object_name = ui_labeled_input(ctx, "Row object name pattern", "##rtw_rowpat", edit_row.object_name or "$item")
                reaper.ImGui_Text(ctx, "Tokens:")
                if reaper.ImGui_Button(ctx, "$item") then append_token_to_selected_row(state, "$item") end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "$track") then append_token_to_selected_row(state, "$track") end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "$marker") then append_token_to_selected_row(state, "$marker") end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "$region") then append_token_to_selected_row(state, "$region") end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "$parent") then append_token_to_selected_row(state, "$parent") end
                reaper.ImGui_Text(ctx, "Use tokens to compose structure names.")
            end

            if reaper.ImGui_Button(ctx, "Suggest via LLM") then
                if sel_count == 0 then
                    state.status = "Select items first so LLM has context to analyse."
                else
                    local llm_script = repo_root() .. "scripts\\llm_assist.py"
                    local tracks, markers, items = collect_llm_context()
                    state.status = string.format(
                        "Asking LLM (tracks: %d, markers: %d, items: %d)...",
                        #tracks, #markers, #items)
                    local suggested, err = run_llm_suggest_structure(
                        llm_script, state.llm_model, tracks, markers, items)
                    if err then
                        state.status = "LLM error: " .. err
                        reaper.ShowConsoleMsg("[ReaAssetFlow LLM] " .. err .. "\n")
                    else
                        state.structures = suggested
                        state.selected_structure_idx = 1
                        state.status = string.format(
                            "LLM suggested %d structure row(s). Review before transferring.", #suggested)
                    end
                end
            end

            if reaper.ImGui_Button(ctx, "Preview Structure") then
                local item_context_map = build_item_context_map()
                local rows, dup_count, item_count =
                    build_structure_preview_rows(state.target, state.structures, item_context_map, -1)
                state.preview_rows = rows
                state.status = string.format(
                    "Preview refreshed: %d item(s), %d duplicate path group(s).",
                    item_count, dup_count)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Clear Preview##structure") then
                state.preview_rows = {}
                state.status = "Structure preview cleared."
            end
            if #state.preview_rows > 0 then
                reaper.ImGui_Text(ctx, "Preview hierarchy (first items, under Import Destination):")
                reaper.ImGui_Text(ctx, "  Shared folders collapse like Wwise Project Explorer.")
                local root = build_preview_hierarchy(state.preview_rows)
                local use_tree = (reaper.ImGui_TreeNodeEx ~= nil) or (reaper.ImGui_TreeNode ~= nil)
                if #root.leaf_items > 0 then
                    reaper.ImGui_Text(ctx, "At Import Destination:")
                    for _, it in ipairs(root.leaf_items) do
                        if reaper.ImGui_BulletText then
                            reaper.ImGui_BulletText(ctx, tostring(it))
                        else
                            reaper.ImGui_Text(ctx, "  · " .. tostring(it))
                        end
                    end
                    if reaper.ImGui_Spacing then reaper.ImGui_Spacing(ctx) end
                end
                render_preview_hierarchy(ctx, root, 0, use_tree, 0)
                if #root.outside > 0 then
                    reaper.ImGui_Text(ctx, "Not under Import Destination:")
                    for _, ow in ipairs(root.outside) do
                        local disp = tostring(ow.full or ""):gsub("[\\/]", " > ")
                        local line = tostring(ow.item or "") .. "  →  " .. disp
                        if reaper.ImGui_TextWrapped then
                            reaper.ImGui_TextWrapped(ctx, line)
                        else
                            reaper.ImGui_Text(ctx, line)
                        end
                    end
                end
            end

            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, string.format("Selected items: %d", sel_count))

            if reaper.ImGui_Button(ctx, "Render Settings...") then
                reaper.Main_OnCommand(40015, 0)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Transfer to Wwise") then
                local subfolder = subfolder_from_originals_path(state.project_path, state.originals_path)
                local target = normalize_target_path(state.target)
                local item_context_map = build_item_context_map()
                local _, selected_track_count = collect_item_context_stats(item_context_map)
                local _, duplicate_paths = build_structure_preview_rows(target, state.structures, item_context_map, 0)
                if sel_count == 0 then
                    state.status = "Please select at least one item before transfer."
                elseif trim(state.project_path) == "" or not subfolder or target == "" then
                    state.status = "Project/Originals Folder/Target are required, and Originals Folder must be under <Project>/Originals/SFX."
                else
                    local proceed_transfer = true
                    if selected_track_count > 1 and not structure_uses_track_dimension(state.structures) then
                        local msg = "Detected multi-track selection, but structure does not include $track/$track_id.\n\n" ..
                            "Assets from different tracks may be merged into the same Wwise objects.\n\n" ..
                            "Continue anyway?"
                        if reaper.ShowMessageBox(msg, "ReaAssetFlow - Multi-Track Warning", 4) ~= 6 then
                            state.status = "Transfer cancelled. Add track dimension token if needed."
                            proceed_transfer = false
                        end
                    end
                    if proceed_transfer and duplicate_paths > 0 then
                        local msg = string.format(
                            "Preview found %d duplicate object path group(s).\n\n" ..
                            "Different items may import into the same Wwise object path.\n\n" ..
                            "Continue anyway?",
                            duplicate_paths)
                        if reaper.ShowMessageBox(msg, "ReaAssetFlow - Path Collision Warning", 4) ~= 6 then
                            state.status = "Transfer cancelled. Adjust structure naming pattern."
                            proceed_transfer = false
                        end
                    end
                    if proceed_transfer then
                        state.subfolder = subfolder
                        run_import(
                            trim(state.project_path),
                            subfolder,
                            target,
                            state.operation,
                            state.template_path or "",
                            state.structures,
                            state.auto_name_pattern or "",
                            state.auto_name_index_scope or "",
                            state.auto_name_missing_marker_mode or "",
                            state.auto_name_fallback_marker or "",
                            state.selected_wwu or ""
                        )
                        state.status = "Import finished. Ready for next transfer."
                    end
                end
            end

            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "Status")
            do
                local st = trim(state.status or "")
                if st ~= "" then
                    if reaper.ImGui_TextWrapped then
                        reaper.ImGui_TextWrapped(ctx, st)
                    else
                        reaper.ImGui_Text(ctx, st)
                    end
                else
                    reaper.ImGui_Text(ctx, "(no messages)")
                end
            end

            ui_major_section_title(ctx, "Dev")
            if reaper.ImGui_PushItemWidth then reaper.ImGui_PushItemWidth(ctx, -1) end
            if reaper.ImGui_Button(ctx, "Open user cache##dev_cache_root") then
                dev_open_folder_next_tick(build_reaper_to_wwise_cache_root_dir())
            end
            if reaper.ImGui_Button(ctx, "Open current Reaper project cache (slug)##dev_cache_slug") then
                dev_open_folder_next_tick(normalize_folder_path(build_reaper_to_wwise_cache_dir()))
            end
            if reaper.ImGui_Button(ctx, "Open user state##dev_state") then
                dev_open_state_dir_next_tick()
            end
            if reaper.ImGui_Button(ctx, "Open user staging##dev_staging") then
                dev_open_folder_next_tick(normalize_folder_path(get_staging_dir()))
            end
            if reaper.ImGui_Button(ctx, "Open user presets##dev_presets") then
                dev_open_folder_next_tick(normalize_folder_path(storage.presets_dir))
            end
            if reaper.ImGui_PopItemWidth then reaper.ImGui_PopItemWidth(ctx) end

            reaper.ImGui_End(ctx)
        end
        if smoke_path and not smoke_written then
            local file = io.open(smoke_path, "w")
            if file then
                file:write("PASS ReaAssetFlow UI frame\n")
                file:close()
            end
            smoke_written = true
            open = false
        end
        if open then
            reaper.defer(loop)
        else
            if reaper.ImGui_DestroyContext then
                reaper.ImGui_DestroyContext(ctx)
            end
            if smoke_path then
                reaper.Main_OnCommand(40004, 0)
            end
        end
    end
    reaper.defer(loop)
end

run_imgui_ui()
