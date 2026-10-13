"""Unit tests for wwise_import helpers (no live Wwise / WAAPI)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import wwise_import as wi


def test_load_config_has_defaults() -> None:
    cfg = wi.load_config()
    assert cfg["waapi_url"] == "ws://127.0.0.1:8080/waapi"
    assert "import_operation" in cfg
    assert wi.normalize_p4_policy(cfg.get("p4_policy")) in ("off", "auto", "required")


def test_normalize_path_string() -> None:
    assert wi.normalize_path_string(r"D:\A\B") == "d:/a/b"
    assert wi.normalize_path_string("") == ""


def test_normalize_p4_policy() -> None:
    assert wi.normalize_p4_policy("REQUIRED") == "required"
    assert wi.normalize_p4_policy("off") == "off"
    assert wi.normalize_p4_policy("bogus") == "auto"
    assert wi.normalize_p4_policy(None) == "auto"


def test_apply_name_pattern() -> None:
    ctx = {"item": "X", "track": "T", "marker": "M", "region": "R", "parent": "P"}
    assert wi.apply_name_pattern("$track_$marker", ctx) == "T_M"
    assert wi.apply_name_pattern("", ctx) == ""


def test_build_structured_object_path(tmp_path: Path) -> None:
    wav = tmp_path / "foot.wav"
    wav.write_bytes(b"fake")
    structures = [
        {"object_type": "Actor Mixer", "object_name": "$track"},
        {"object_type": "Sound SFX", "object_name": "$item"},
    ]
    ctx = {"foot": {"track": "TR", "marker": "", "region": "", "item": "foot"}}
    p = wi.build_structured_object_path(
        "\\Actor-Mixer Hierarchy\\WU",
        wav,
        structures,
        ctx,
    )
    assert p.startswith("\\Actor-Mixer Hierarchy\\WU\\")
    assert "<Actor-Mixer>TR" in p
    assert "<Sound SFX>foot" in p


def test_build_structured_object_path_appends_sound_sfx(tmp_path: Path) -> None:
    wav = tmp_path / "only.wav"
    wav.write_bytes(b"fake")
    structures = [{"object_type": "Actor Mixer", "object_name": "$track"}]
    ctx = {"only": {"track": "Z", "marker": "", "region": "", "item": "only"}}
    p = wi.build_structured_object_path("\\Root", wav, structures, ctx)
    assert p.endswith("\\<Actor-Mixer>Z\\<Sound SFX>only")


def test_collect_valid_wavs(tmp_path: Path) -> None:
    good = tmp_path / "a.wav"
    good.write_bytes(b"x")
    bad = tmp_path / "b.txt"
    bad.write_text("n")
    missing = tmp_path / "missing.wav"
    wavs, skipped = wi.collect_valid_wavs([str(good), str(bad), str(missing)])
    assert len(wavs) == 1
    assert wavs[0].resolve() == good.resolve()
    assert skipped == 2


def test_expected_originals_files(tmp_path: Path) -> None:
    wproj = tmp_path / "Game.wproj"
    wproj.write_text("{}", encoding="utf-8")
    wav = tmp_path / "hit.wav"
    wav.write_bytes(b"x")
    out = wi.expected_originals_files(str(wproj), "Foley/Step", [wav])
    assert len(out) == 1
    assert out[0].name == "hit.wav"
    p = str(out[0]).replace("\\", "/")
    assert "Originals/SFX/Foley/Step" in p or "Originals\\SFX\\Foley\\Step" in str(out[0])


def test_ensure_p4_opened_paths_policy_off() -> None:
    stats = wi.ensure_p4_opened_for_paths([Path("nope.wav")], "label", "off")
    assert stats == {"edit": 0, "add": 0, "already_open": 0, "skip": 0, "error": 0}


def test_is_sound_sfx_type() -> None:
    assert wi.is_sound_sfx_type("Sound SFX") is True
    assert wi.is_sound_sfx_type("sound") is True
    assert wi.is_sound_sfx_type("RandomSequenceContainer") is False
