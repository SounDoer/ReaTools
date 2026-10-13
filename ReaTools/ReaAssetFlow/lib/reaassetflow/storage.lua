local M = {}

local function join(...)
  local parts = { ... }
  local out = tostring(parts[1] or ""):gsub("[\\/]+$", "")
  for i = 2, #parts do
    local part = tostring(parts[i] or ""):gsub("^[\\/]+", ""):gsub("[\\/]+$", "")
    if part ~= "" then out = out .. "\\" .. part end
  end
  return out
end

local function file_exists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end

function M.create(reaper_api, install_root, data_root_override)
  local resource_root = reaper_api.GetResourcePath and reaper_api.GetResourcePath() or install_root
  local data_root = data_root_override or join(resource_root, "Data", "ReaTools", "ReaAssetFlow")
  local storage = {
    data_root = data_root,
    state_dir = join(data_root, "state"),
    staging_dir = join(data_root, "staging"),
    presets_dir = join(data_root, "presets"),
    cache_dir = join(data_root, "cache"),
    legacy = {
      state_dir = join(install_root, "_state"),
      presets_dir = join(install_root, "presets"),
      cache_dir = join(resource_root, "ReaAssetFlow", "cache"),
    },
  }

  local function ensure_dir(path)
    if reaper_api.RecursiveCreateDirectory then
      reaper_api.RecursiveCreateDirectory(path, 0)
      return true
    end
    return false, "REAPER cannot create the user-data directory: " .. path
  end

  local function copy_file(source, target)
    if file_exists(target) then return true, false end
    local input = io.open(source, "rb")
    if not input then return false, "Could not read legacy file: " .. source end
    local content = input:read("*a")
    input:close()
    local output = io.open(target, "wb")
    if not output then return false, "Could not create migrated file: " .. target end
    output:write(content)
    output:close()
    return true, true
  end

  local function copy_tree(source, target, report)
    if not reaper_api.EnumerateFiles or not reaper_api.EnumerateSubdirectories then return true end
    local created, create_error = ensure_dir(target)
    if not created then report.errors[#report.errors + 1] = create_error; return false end
    local index = 0
    while true do
      local name = reaper_api.EnumerateFiles(source, index)
      if not name then break end
      local ok, copied_or_error = copy_file(join(source, name), join(target, name))
      if not ok then
        report.errors[#report.errors + 1] = copied_or_error
      elseif copied_or_error then
        report.copied = report.copied + 1
      end
      index = index + 1
    end
    index = 0
    while true do
      local name = reaper_api.EnumerateSubdirectories(source, index)
      if not name then break end
      copy_tree(join(source, name), join(target, name), report)
      index = index + 1
    end
    return #report.errors == 0
  end

  function storage.ensure()
    for _, path in ipairs({ storage.state_dir, storage.staging_dir, storage.presets_dir, storage.cache_dir }) do
      local ok, err = ensure_dir(path)
      if not ok then return false, err end
    end
    return true
  end

  function storage.migrate_legacy()
    local report = { copied = 0, errors = {} }
    local ok, err = storage.ensure()
    if not ok then report.errors[#report.errors + 1] = err; return report end
    local marker = join(data_root, "migration-v1.done")
    if file_exists(marker) then return report end
    copy_tree(storage.legacy.state_dir, storage.state_dir, report)
    copy_tree(storage.legacy.presets_dir, storage.presets_dir, report)
    copy_tree(storage.legacy.cache_dir, storage.cache_dir, report)
    if #report.errors == 0 then
      local file = io.open(marker, "wb")
      if file then
        file:write("Legacy ReaAssetFlow user data copied without deleting its source.\n")
        file:close()
      else
        report.errors[#report.errors + 1] = "Could not write migration marker: " .. marker
      end
    end
    return report
  end

  return storage
end

return M
