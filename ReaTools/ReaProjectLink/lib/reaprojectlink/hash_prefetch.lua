-- Runs a review builder against prefetched hashes. Each pass records the
-- files it could not get a hash for; those are hashed through the job
-- filesystem (in the background) and the builder runs again. The returned
-- result comes from a pass that needed nothing new, so it was built in one
-- frame from one project state.
local M = {}

function M.run(job_fs, build)
  local hashes = {}
  while true do
    local missing, recorded = {}, {}
    local view = setmetatable({}, { __index = job_fs })
    function view.hash_file(path)
      local known = hashes[path]
      if known ~= nil then return known or nil end
      if not recorded[path] then
        recorded[path] = true
        table.insert(missing, path)
      end
      return nil
    end
    local result, err = build(view)
    if #missing == 0 then return result, err end
    for _, path in ipairs(missing) do job_fs.add_total(job_fs.file_size(path) or 0) end
    for _, path in ipairs(missing) do hashes[path] = job_fs.hash_file(path) or false end
  end
end

return M
