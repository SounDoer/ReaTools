local filesystem = require("reaprojectlink.filesystem")
local json = require("reaprojectlink.json")
local delivery_writer = require("reaprojectlink.delivery_writer")
local sha256 = require("reaprojectlink.sha256")

local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = assert(source:match("^(.*)[/\\]"))
local root = tests_dir .. "/.filesystem-fixture"
local fs = filesystem.create(reaper)

fs.remove_tree(root)
assert(fs.make_directory(root))

local first_lock = assert(fs.acquire_lock(root, {
  user = "tester",
  machine = "test-machine",
  started_at = "2026-09-13T12:00:00+08:00",
}))
local second_lock = fs.acquire_lock(root, {})
assert(second_lock == nil, "a second publisher must not acquire the lock")
assert(fs.release_lock(root, first_lock))
local third_lock = assert(fs.acquire_lock(root, {}))
assert(fs.release_lock(root, third_lock))

local stale_token = assert(fs.acquire_lock(root, {
  user = "stale-user",
  machine = "stale-machine",
  started_at = "2026-09-13T12:30:00+08:00",
}))
local lock_info = assert(fs.read_lock(root))
assert(lock_info.token == stale_token and lock_info.user == "stale-user", "lock metadata")
local wrong_removal = fs.remove_lock(root, "wrong-token")
assert(wrong_removal == nil, "lock removal requires the observed token")
assert(fs.remove_lock(root, stale_token), "explicit stale-lock removal")

local source_path = fs.join(root, "source.wav")
local copied_path = fs.join(root, "nested", "copy.wav")
assert(fs.write_file(source_path, "wave bytes"))
assert(fs.make_directory(fs.join(root, "nested")))
assert(fs.copy_file(source_path, copied_path))
assert(fs.read_file(copied_path) == "wave bytes", "copied bytes")
assert(fs.file_size(copied_path) == 10, "copied size")
assert(fs.hash_file(copied_path) == sha256.digest("wave bytes"), "copied hash")

local spaced_path = fs.join(root, "spaced name.wav")
local binary_bytes = "\0\r\n\255wave"
assert(fs.write_file(spaced_path, binary_bytes))
assert(fs.hash_file(spaced_path) == sha256.digest(binary_bytes), "hash of a spaced binary path")

local stable_path = fs.join(root, "delivery.json")
local temporary_path = fs.join(root, "delivery.tmp")
assert(fs.write_file(stable_path, "old"))
assert(fs.write_file(temporary_path, "new"))
assert(fs.atomic_replace(temporary_path, stable_path))
assert(fs.read_file(stable_path) == "new", "atomic replacement")
assert(not fs.exists(temporary_path), "temporary file is consumed")

local package_root = fs.join(root, "package")
local publish_result, publish_error = delivery_writer.publish({
  package_root = package_root,
  expected_revision = 0,
  transaction_id = "integration",
  snapshot = {
    schemaVersion = 1,
    sourceProjectId = "source-1",
    deliveryRevision = 1,
    lanes = json.array(),
  },
  pointer = {
    schemaVersion = 1,
    sourceProjectId = "source-1",
    latestDeliveryRevision = 1,
    manifest = "history/delivery-0001.json",
  },
  media = {
    {
      source_path = source_path,
      destination = "media/clip-1/clip_r0001.wav",
      size = 10,
      hash = sha256.digest("wave bytes"),
    },
  },
}, fs)
assert(publish_result, publish_error)
local published_pointer = assert(fs.read_file(fs.join(package_root, "delivery.json")))
assert(json.decode(published_pointer).latestDeliveryRevision == 1, "real Publish pointer")
assert(
  fs.read_file(fs.join(package_root, "media", "clip-1", "clip_r0001.wav")) == "wave bytes",
  "real Publish media"
)

local native_commands = {}
local command_fs = filesystem.create({
  ExecProcess = function(command)
    table.insert(native_commands, command)
    if command:find("certutil", 1, true) then
      return "0\n" .. string.rep("a", 64) .. "\n"
    end
    return "0\n"
  end,
})
assert(command_fs.copy_file("source path.wav", "destination path.wav"))
assert(#native_commands == 1, "copy uses one native process")
if package.config:sub(1, 1) == "\\" then
  assert(native_commands[1]:find("[IO.File]::Copy", 1, true), "Windows copy uses the native file API")
  local joined = command_fs.join([[\\server\share]], "media/clip/file.wav")
  assert(joined == [[\\server\share\media\clip\file.wav]],
    "Windows joins normalize manifest path separators")
  native_commands = {}
  assert(command_fs.copy_file([[\\server\share\source.wav]],
    [[\\server\share\media\clip\long destination.wav]]))
  assert(native_commands[1]:find([[\\?\UNC\server\share\source.wav]], 1, true),
    "Windows native copy uses an extended UNC source path")
  assert(native_commands[1]:find([[\\?\UNC\server\share\media\clip\long destination.wav]], 1, true),
    "Windows native copy uses an extended UNC destination path")
  native_commands = {}
  assert(command_fs.hash_file([[\\server\share\media\clip\long destination.wav]]) ==
    string.rep("a", 64))
  assert(native_commands[1]:find([[\\?\UNC\server\share\media\clip\long destination.wav]], 1, true),
    "Windows native hash uses an extended UNC path")
else
  assert(native_commands[1]:find("/bin/cp", 1, true), "POSIX copy uses the native copy tool")
  local joined = command_fs.join("/server/share", [[media\clip\file.wav]])
  assert(joined == "/server/share/media/clip/file.wav",
    "POSIX joins normalize manifest path separators")
end

local failed_command_fs = filesystem.create({
  ExecProcess = function() return "1\nnative copy failed" end,
})
local copied, copy_error = failed_command_fs.copy_file("source.wav", "destination.wav")
assert(copied == nil and copy_error:find("native copy failed", 1, true),
  "native copy errors are returned")

local function wait_for(handle)
  local deadline = reaper.time_precise() + 30
  while reaper.time_precise() < deadline do
    local status, value = fs.poll(handle)
    if status ~= "running" then return status, value end
  end
  error("background job did not finish: " .. handle.path)
end

assert(fs.make_directory(fs.join(root, "background")))
for _, name in ipairs({ "plain.wav", "it's here.wav", "中文 音效.wav" }) do
  local path = fs.join(root, name)
  assert(fs.write_file(path, binary_bytes .. name))
  local status, digest = wait_for(fs.start_hash(path))
  assert(status == "done" and digest == fs.hash_file(path), "background hash of " .. name)
  local destination = fs.join(root, "background", name)
  status = wait_for(fs.start_copy(path, destination))
  assert(status == "done", "background copy of " .. name)
  assert(fs.read_file(destination) == fs.read_file(path), "background copy bytes of " .. name)
end

local missing_status, missing_error = wait_for(fs.start_copy(fs.join(root, "missing.wav"),
  fs.join(root, "background", "missing.wav")))
assert(missing_status == "failed" and missing_error ~= "", "background copy of a missing file fails")

local lost = fs.start_hash(fs.join(root, "plain.wav"))
lost.id = "never-written"
lost.started_at = reaper.time_precise() - filesystem.BACKGROUND_TIMEOUT_SECONDS - 1
local lost_status, lost_error = fs.poll(lost)
assert(lost_status == "failed" and lost_error:find("timed out", 1, true) and
  lost_error:find(lost.path, 1, true), "background job without a result times out")
fs.clear_background()

assert(fs.remove_tree(root))
assert(not fs.exists(root), "fixture directory is removed")

return 1
