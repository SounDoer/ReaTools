-- Runs one long operation at a time inside a coroutine. The operation gets a
-- job filesystem whose hash and copy run in background processes, so REAPER
-- keeps drawing while they work; `step` is called once per frame.
local M = {}

M.CANCELLED = "ReaProjectLink operation cancelled"

local PROJECT_CLOSED = "The project was closed."

function M.progress(job)
  if not job.total_bytes or job.total_bytes <= 0 then return nil end
  return math.min(100, job.done_bytes / job.total_bytes * 100)
end

local function is_cancel(err)
  return type(err) == "string" and err:find(M.CANCELLED, 1, true) ~= nil
end

function M.create(deps)
  local fs, adapter = deps.fs, deps.adapter
  local runner = { current = nil }

  local function job_fs_for(job)
    local proxy = setmetatable({}, { __index = fs })
    -- Cancellation takes effect at the next file operation before the commit;
    -- the operation's own error handling then cleans up.
    local function check_cancel()
      if job.cancel_requested and job.phase ~= "finishing" then error(M.CANCELLED, 0) end
    end
    local function wait(handle)
      job.pending = handle
      local status, value = coroutine.yield()
      check_cancel()
      return status, value
    end

    function proxy.hash_file(path)
      check_cancel()
      local status, value = wait(fs.start_hash(path))
      if status ~= "done" then return nil, value end
      job.done_bytes = job.done_bytes + (fs.file_size(path) or 0)
      return value
    end

    function proxy.copy_file(source, destination)
      check_cancel()
      local status, value = wait(fs.start_copy(source, destination))
      if status ~= "done" then return nil, value end
      return true
    end

    function proxy.atomic_replace(source, destination)
      check_cancel()
      job.phase = "finishing"
      return fs.atomic_replace(source, destination)
    end

    function proxy.add_total(bytes)
      job.total_bytes = (job.total_bytes or 0) + bytes
    end

    return proxy
  end

  local function finish(job, state, result, err)
    job.state, job.result, job.pending = state, result, nil
    if state == "cancelled" then
      job.error = job.cancel_reason or "Cancelled."
    else
      job.error = err
    end
    if job.on_done then job.on_done(job) end
  end

  function runner:busy()
    return self.current ~= nil and self.current.state == "running"
  end

  function runner:start(spec)
    if self:busy() then error("another operation is still running") end
    local job = {
      kind = spec.kind, label = spec.label, project = spec.project, project_name = spec.project_name,
      state = "running", phase = "working", done_bytes = 0, total_bytes = spec.total_bytes,
      on_done = spec.on_done,
    }
    job.co = coroutine.create(function() return spec.run(job_fs_for(job)) end)
    self.current = job
    return job
  end

  function runner:step()
    local job = self.current
    if not job or job.state ~= "running" then return end
    if job.project and not job.cancel_requested and not adapter.project_is_open(job.project) then
      job.cancel_requested, job.cancel_reason = true, PROJECT_CLOSED
      if job.phase ~= "finishing" then job.phase = "cancelling" end
    end
    local status, value
    if job.pending then
      status, value = fs.poll(job.pending)
      if status == "running" then return end
      job.pending = nil
    end
    job.started = true
    local ok, result, err = adapter.with_project(job.project, coroutine.resume, job.co, status, value)
    if coroutine.status(job.co) ~= "dead" then return end
    if not ok then
      finish(job, is_cancel(result) and "cancelled" or "failed", nil, tostring(result))
    elseif result ~= nil then
      finish(job, "succeeded", result)
    else
      finish(job, is_cancel(err) and "cancelled" or "failed", nil, err)
    end
  end

  function runner:cancel()
    local job = self.current
    if not job or job.state ~= "running" or job.phase == "finishing" then return end
    if not job.started then
      finish(job, "cancelled")
      return
    end
    job.cancel_requested = true
    job.phase = "cancelling"
  end

  -- Drops a job without reporting it; its background process finishes on its
  -- own and leaves one small, unread result file.
  function runner:discard()
    self.current = nil
  end

  function runner:dismiss()
    if self.current and self.current.state ~= "running" then self.current = nil end
  end

  return runner
end

return M
