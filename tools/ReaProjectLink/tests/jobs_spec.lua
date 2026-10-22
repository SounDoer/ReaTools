local jobs = require("reaprojectlink.jobs")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

-- Background handles finish on their second poll unless `failures` names the
-- path; `log` records every start and commit.
local function fake_fs(sizes, failures)
  local fs = { log = {} }
  local function start(kind, path)
    table.insert(fs.log, kind .. ":" .. path)
    return { kind = kind, path = path, polls = 0 }
  end
  function fs.start_hash(path) return start("hash", path) end
  function fs.start_copy(source) return start("copy", source) end
  function fs.poll(handle)
    handle.polls = handle.polls + 1
    if handle.polls < 2 then return "running" end
    if failures and failures[handle.path] then return "failed", failures[handle.path] end
    return "done", handle.kind == "hash" and ("hash-" .. handle.path) or true
  end
  function fs.file_size(path) return sizes[path] end
  function fs.atomic_replace(source) table.insert(fs.log, "commit:" .. source) return true end
  function fs.write_file() return true end
  return fs
end

local function fake_adapter()
  local adapter = { open = true, bindings = {} }
  function adapter.project_is_open() return adapter.open end
  function adapter.with_project(project, fn, ...)
    table.insert(adapter.bindings, project)
    return fn(...)
  end
  return adapter
end

local function run_until_done(runner, limit)
  for _ = 1, limit or 50 do
    runner:step()
    if not runner:busy() then return end
  end
  error("job did not finish")
end

local tests = {}

function tests.runs_service_across_frames()
  local fs = fake_fs({ a = 10, b = 30 })
  local runner = jobs.create({ fs = fs, adapter = fake_adapter() })
  local done_calls, progress = 0, {}
  local job = runner:start({
    kind = "publish", label = "Publishing", total_bytes = 40,
    run = function(job_fs)
      local first = job_fs.hash_file("a")
      local second = job_fs.hash_file("b")
      return first .. "," .. second
    end,
    on_done = function() done_calls = done_calls + 1 end,
  })
  for _ = 1, 50 do
    runner:step()
    local value = jobs.progress(job)
    if value ~= progress[#progress] then table.insert(progress, value) end
    if not runner:busy() then break end
  end
  equal(job.state, "succeeded", "state")
  equal(job.result, "hash-a,hash-b", "result")
  equal(job.done_bytes, 40, "done bytes")
  equal(progress[1], 0, "starts at zero")
  equal(progress[2], 25, "first file")
  equal(progress[3], 100, "second file")
  equal(done_calls, 1, "on_done once")
  equal(runner.current, job, "finished job stays current")
end

function tests.cancel_raises_at_next_file_operation()
  local fs = fake_fs({ a = 1, b = 1 })
  local runner = jobs.create({ fs = fs, adapter = fake_adapter() })
  local cleaned = false
  local job = runner:start({
    kind = "publish", label = "Publishing",
    run = function(job_fs)
      local ok, err = xpcall(function()
        job_fs.hash_file("a")
        job_fs.hash_file("b")
      end, debug.traceback)
      cleaned = true
      if not ok then return nil, err end
      return true
    end,
    on_done = function() end,
  })
  runner:step()
  runner:cancel()
  equal(job.phase, "cancelling", "cancelling while the file finishes")
  run_until_done(runner)
  equal(job.state, "cancelled", "state")
  equal(cleaned, true, "service cleanup ran")
  equal(#fs.log, 1, "second hash never started")
end

function tests.cancel_ignored_after_commit()
  local fs = fake_fs({ a = 1 })
  local runner = jobs.create({ fs = fs, adapter = fake_adapter() })
  local job = runner:start({
    kind = "publish", label = "Publishing",
    run = function(job_fs)
      job_fs.atomic_replace("pointer")
      job_fs.hash_file("a")
      return "published"
    end,
    on_done = function() end,
  })
  runner:step()
  equal(job.phase, "finishing", "commit entered finishing")
  runner:cancel()
  run_until_done(runner)
  equal(job.state, "succeeded", "state")
end

function tests.failed_background_process_fails_job()
  local fs = fake_fs({ a = 1 }, { a = "disk full" })
  local runner = jobs.create({ fs = fs, adapter = fake_adapter() })
  local job = runner:start({
    kind = "check", label = "Checking media",
    run = function(job_fs)
      local digest, err = job_fs.hash_file("a")
      if not digest then return nil, "could not hash: " .. err end
      return digest
    end,
    on_done = function() end,
  })
  run_until_done(runner)
  equal(job.state, "failed", "state")
  equal(job.error, "could not hash: disk full", "service error surfaces")
end

function tests.closed_project_cancels()
  local adapter = fake_adapter()
  local runner = jobs.create({ fs = fake_fs({ a = 1, b = 1 }), adapter = adapter })
  local job = runner:start({
    kind = "publish", label = "Publishing", project = "project-a",
    run = function(job_fs)
      job_fs.hash_file("a")
      job_fs.hash_file("b")
      return true
    end,
    on_done = function() end,
  })
  runner:step()
  adapter.open = false
  run_until_done(runner)
  equal(job.state, "cancelled", "state")
  assert(job.error:find("closed", 1, true), "reason names the closed project")
end

function tests.resumes_inside_bound_project()
  local adapter = fake_adapter()
  local runner = jobs.create({ fs = fake_fs({ a = 1 }), adapter = adapter })
  runner:start({
    kind = "publish", label = "Publishing", project = "project-a",
    run = function(job_fs) return job_fs.hash_file("a") end,
    on_done = function() end,
  })
  run_until_done(runner)
  assert(#adapter.bindings >= 2, "resumed more than once")
  for index, project in ipairs(adapter.bindings) do equal(project, "project-a", "binding " .. index) end
end

function tests.cancel_before_first_frame_never_runs()
  local ran = false
  local runner = jobs.create({ fs = fake_fs({}), adapter = fake_adapter() })
  local job = runner:start({
    kind = "check", label = "Checking media",
    run = function() ran = true return true end,
    on_done = function() end,
  })
  runner:cancel()
  equal(job.state, "cancelled", "state")
  equal(ran, false, "service never ran")
  equal(runner:busy(), false, "not busy")
end

function tests.one_job_at_a_time_and_dismiss()
  local runner = jobs.create({ fs = fake_fs({ a = 1 }), adapter = fake_adapter() })
  runner:start({ kind = "check", label = "Checking media", run = function(job_fs) return job_fs.hash_file("a") end,
    on_done = function() end })
  assert(not pcall(runner.start, runner, { kind = "check", label = "x", run = function() end }), "second start fails")
  run_until_done(runner)
  runner:dismiss()
  equal(runner.current, nil, "dismissed")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
