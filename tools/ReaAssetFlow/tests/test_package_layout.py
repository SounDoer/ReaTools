import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_manifest_entry_and_lua_version_match():
    manifest = json.loads((ROOT / "reatools-package.json").read_text(encoding="utf-8"))
    entry = ROOT / manifest["entry"]
    source = entry.read_text(encoding="utf-8")
    assert entry.name == "ReaAssetFlow.lua"
    assert f"@version {manifest['version']}" in source
    assert "[nomain] lib/reaassetflow/*.lua" in source
    assert "[nomain] scripts/wwise_import.py" in source


def test_user_data_is_outside_the_managed_package_tree():
    source = (ROOT / "lib" / "reaassetflow" / "storage.lua").read_text(encoding="utf-8")
    assert '"Data", "ReaTools", "ReaAssetFlow"' in source
    assert 'state_dir = join(data_root, "state")' in source
    assert 'presets_dir = join(data_root, "presets")' in source
    assert 'staging_dir = join(data_root, "staging")' in source
    assert 'cache_dir = join(data_root, "cache")' in source
    assert "Legacy ReaAssetFlow user data copied without deleting its source." in source


def test_startup_prerequisite_check_is_visible_and_non_silent():
    source = (ROOT / "ReaAssetFlow.lua").read_text(encoding="utf-8")
    assert "check_base_prerequisites" in source
    assert "Open installation folder##setup" in source
    assert "Check Again##setup" in source
    assert "run setup.bat" in source
    assert "state.prerequisites = check_base_prerequisites()" in source
