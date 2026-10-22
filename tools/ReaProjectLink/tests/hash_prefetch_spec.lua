local hash_prefetch = require("reaprojectlink.hash_prefetch")
local project_guard = require("reaprojectlink.project_guard")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

-- `hash_file` stands for a background hash: it counts calls and fails for
-- paths in `failures`. `building` is set by the builders under test.
local function fake_job_fs(failures)
  local job_fs = { calls = {}, total = 0, building = false }
  function job_fs.hash_file(path)
    assert(not job_fs.building, "a build pass must not wait for a hash")
    job_fs.calls[path] = (job_fs.calls[path] or 0) + 1
    if failures and failures[path] then return nil, "unreadable" end
    return "hash-" .. path
  end
  function job_fs.file_size() return 5 end
  function job_fs.add_total(bytes) job_fs.total = job_fs.total + bytes end
  return job_fs
end

local function builder(job_fs, paths_for)
  local passes = 0
  return function(fs)
    passes = passes + 1
    job_fs.building = true
    local seen = {}
    for _, path in ipairs(paths_for(seen)) do seen[path] = fs.hash_file(path) end
    job_fs.building = false
    return seen
  end, function() return passes end
end

local tests = {}

function tests.final_build_sees_all_hashes()
  local job_fs = fake_job_fs()
  local build, passes = builder(job_fs, function() return { "a", "b" } end)
  local result = hash_prefetch.run(job_fs, build)
  equal(result.a, "hash-a", "a")
  equal(result.b, "hash-b", "b")
  equal(job_fs.calls.a, 1, "a hashed once")
  equal(job_fs.calls.b, 1, "b hashed once")
  equal(passes(), 2, "collect pass and final pass")
  equal(job_fs.total, 10, "total bytes of missing files")
end

function tests.new_paths_trigger_another_round()
  local job_fs = fake_job_fs()
  local passes = 0
  local result = hash_prefetch.run(job_fs, function(fs)
    passes = passes + 1
    local first = fs.hash_file("a")
    local second = first and fs.hash_file("c") or nil
    return { a = first, c = second }
  end)
  equal(result.c, "hash-c", "c")
  equal(job_fs.calls.c, 1, "c hashed once")
  equal(passes, 3, "one pass per discovery round plus the final pass")
end

function tests.failed_hash_is_not_retried()
  local job_fs = fake_job_fs({ b = true })
  local build = builder(job_fs, function() return { "a", "b" } end)
  local result = hash_prefetch.run(job_fs, build)
  equal(result.b, nil, "b reported missing")
  equal(job_fs.calls.b, 1, "b hashed once")
end

function tests.publish_review_goes_stale_on_mid_check_edit()
  local count = 0
  local adapter = { project_change_count = function() return count end }
  local job_fs = fake_job_fs()
  local hash = job_fs.hash_file
  function job_fs.hash_file(path)
    count = count + 1
    return hash(path)
  end
  local review = hash_prefetch.run(job_fs, function(fs)
    fs.hash_file("a")
    return project_guard.bind({}, adapter, true)
  end)
  equal(review.project_change_count, 1, "bound at the final pass")
  assert(project_guard.check(review, adapter), "current right after the check")
  count = count + 1
  assert(not project_guard.check(review, adapter), "a later edit makes it Out of Date")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
