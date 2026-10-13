"""
ReaAssetFlow - Wwise Import Script

Imports WAV files into Wwise as Sound SFX objects via WAAPI.
Wwise copies each file into its Originals/SFX/<subfolder>/ directory.

Usage:
    python wwise_import.py [--originals-subfolder SUBFOLDER]
                           [--import-target TARGET]
                           [--import-operation OPERATION]
                           [--property-template-path TEMPLATE_PATH]
                           [--preview-only]
                           [--validate-target-only]
                           [--list-import-targets]
                           [--list-base-path BASE_PATH]
                           [--delete-after]
                           [<wav_file> ...]
"""

import sys
import json
import time
import os
import argparse
import shutil
import subprocess
from pathlib import Path

try:
    from waapi import WaapiClient, CannotConnectToWaapiException
except ImportError:
    print("[ERROR] waapi-client is not installed. Run setup.bat first.")
    sys.exit(1)


REPO_ROOT = Path(__file__).resolve().parent.parent

P4_POLICY_VALUES = {"off", "auto", "required"}
DEFAULT_P4_TIMEOUT_SEC = 8
SCRIPT_P4_ENABLED = False

# Defaults when no JSON config is present (Reaper panel + request.json supply real paths).
DEFAULT_CONFIG = {
    "waapi_url": "ws://127.0.0.1:8080/waapi",
    "wwise_project_path": "",
    "originals_subfolder": "Imported",
    "wwise_import_target": r"\Actor-Mixer Hierarchy\Default Work Unit\Imported",
    "import_operation": "useExisting",
    "import_batch_size": 48,
    "p4_policy": "off",
    "p4_timeout_sec": DEFAULT_P4_TIMEOUT_SEC,
}


def _merge_json_file(cfg, path):
    if not path.exists():
        return
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return
    if isinstance(data, dict):
        cfg.update(data)


def load_config():
    cfg = dict(DEFAULT_CONFIG)
    # Optional legacy overrides (not shipped with the repo).
    _merge_json_file(cfg, REPO_ROOT / "config.json")
    _merge_json_file(cfg, REPO_ROOT / "config.local.json")
    return cfg


def parse_args():
    parser = argparse.ArgumentParser(description="Import WAV files into Wwise via WAAPI")
    parser.add_argument("wav_files", nargs="*", metavar="WAV")
    parser.add_argument("--request-file", dest="request_file",
                        help="JSON request file containing import parameters")
    parser.add_argument("--originals-subfolder", dest="originals_subfolder",
                        help="Override originals_subfolder from config")
    parser.add_argument("--import-target", dest="import_target",
                        help="Override wwise_import_target from config")
    parser.add_argument("--import-operation", dest="import_operation",
                        choices=["useExisting", "createNew", "replaceExisting"],
                        help="How to handle existing objects during import")
    parser.add_argument("--property-template-path", dest="property_template_path",
                        help="Wwise property template path (validated only in v0.1)")
    parser.add_argument("--expected-project-path", dest="expected_project_path",
                        help="Expected Wwise project path to validate against opened project")
    parser.add_argument("--preview-only", action="store_true",
                        help="Print import plan and exit")
    parser.add_argument("--validate-target-only", action="store_true",
                        help="Validate Wwise import target and exit")
    parser.add_argument("--list-import-targets", action="store_true",
                        help="List import target candidates and exit")
    parser.add_argument("--list-work-units", action="store_true",
                        help="List Work Units under base path and exit")
    parser.add_argument("--list-base-path", dest="list_base_path",
                        default="\\Actor-Mixer Hierarchy",
                        help="Base Wwise path used for target listing")
    parser.add_argument("--list-depth", dest="list_depth", type=int, default=0,
                        help="Max expand rounds for listing (0 = until frontier empty)")
    parser.add_argument("--delete-after", action="store_true",
                        help="Delete WAV files after successful import")
    parser.add_argument("--result-file", dest="result_file",
                        help="Optional JSON result file for list modes")
    return parser.parse_args()


def load_request_file(path):
    if not path:
        return {}
    req_path = Path(path).resolve()
    if not req_path.exists():
        print(f"[ERROR] Request file not found: {req_path}")
        sys.exit(1)
    with open(req_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        print("[ERROR] Request file must contain a JSON object.")
        sys.exit(1)
    return data


def write_status_file(path, payload):
    if not path:
        return
    if isinstance(payload, dict):
        payload = dict(payload)
        payload.setdefault("pid", os.getpid())
        payload["updated_at"] = time.time()
    status_path = Path(path).resolve()
    status_path.parent.mkdir(parents=True, exist_ok=True)
    with open(status_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False)

def write_running_stage(status_file, mode, stage, extra=None):
    payload = {"state": "running", "mode": mode, "stage": stage}
    if isinstance(extra, dict):
        payload.update(extra)
    write_status_file(status_file, payload)

def safe_print(message):
    try:
        print(message)
    except Exception:
        # Background subprocess stdout/stderr can become unavailable; avoid hard crash.
        pass


OBJECT_MAP_VERSION = 1


def load_object_map(path):
    p = Path(str(path or "")).resolve()
    if not p.exists():
        return {"version": OBJECT_MAP_VERSION, "entries": {}}
    try:
        with open(p, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            return {"version": OBJECT_MAP_VERSION, "entries": {}}
        entries = data.get("entries")
        if not isinstance(entries, dict):
            entries = {}
        data["entries"] = entries
        data["version"] = int(data.get("version") or OBJECT_MAP_VERSION)
        return data
    except (OSError, json.JSONDecodeError):
        return {"version": OBJECT_MAP_VERSION, "entries": {}}


def save_object_map(path, data):
    p = Path(str(path or "")).resolve()
    if not str(p):
        return False
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    tmp.replace(p)
    return True


def is_sound_sfx_type(obj_type):
    t = str(obj_type or "").lower().strip()
    return t in ("sound", "sound sfx")


def pick_sound_object_for_stem(created, stem):
    """Pick the best-matching Sound/Sound SFX object for a WAV stem (may duplicate names in Wwise)."""
    if not stem:
        return None
    stem_l = stem.lower()
    matches = []
    for obj in created or []:
        if not is_sound_sfx_type(obj.get("type")):
            continue
        name = str(obj.get("name") or "")
        if name == stem or name.lower() == stem_l:
            matches.append(obj)
    if not matches:
        return None
    if len(matches) == 1:
        return matches[0]
    return max(matches, key=lambda o: len(str(o.get("path") or "")))


def object_map_entry_key(project_norm, import_target_norm, file_stem):
    # \x1f (ASCII Unit Separator) prevents collision with / and \ in Wwise path segments
    return f"{project_norm}\x1f{import_target_norm}\x1f{file_stem}"


def merge_object_map_from_import(
    object_map_file,
    project_path_raw,
    import_target_raw,
    wav_files,
    created,
):
    if not object_map_file:
        return 0
    project_norm = normalize_path_string(project_path_raw)
    target_norm = normalize_path_string(import_target_raw)
    if not project_norm or not target_norm:
        print("[WARN] Object map skipped (missing project or import target path).")
        return 0

    data = load_object_map(object_map_file)
    entries = data.setdefault("entries", {})
    updated = 0
    for wav in wav_files or []:
        stem = wav.stem
        obj = pick_sound_object_for_stem(created, stem)
        if not obj:
            continue
        oid = str(obj.get("id") or "")
        if not oid:
            continue
        key = object_map_entry_key(project_norm, target_norm, stem)
        entries[key] = {
            "project_path": str(project_path_raw or ""),
            "import_target": str(import_target_raw or ""),
            "file_stem": stem,
            "sound_sfx_id": oid,
            "sound_sfx_path": str(obj.get("path") or ""),
            "sound_sfx_name": str(obj.get("name") or stem),
            "updated_at": time.time(),
        }
        updated += 1
    if updated:
        data["version"] = OBJECT_MAP_VERSION
        if save_object_map(object_map_file, data):
            print(f"[INFO] Object map updated: {updated} entr(y/ies) -> {object_map_file}")
        else:
            print(f"[WARN] Could not write object map: {object_map_file}")
    return updated


def write_result_file(path, payload):
    if not path:
        return
    out_path = Path(path).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False)


def normalize_p4_policy(value):
    policy = str(value or "").strip().lower()
    if policy in P4_POLICY_VALUES:
        return policy
    return "auto"


def run_p4(args, timeout_sec=DEFAULT_P4_TIMEOUT_SEC):
    cmd = ["p4"] + list(args or [])
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=max(1, int(timeout_sec or DEFAULT_P4_TIMEOUT_SEC)))
    except subprocess.TimeoutExpired as e:
        detail = f"p4 command timeout after {max(1, int(timeout_sec or DEFAULT_P4_TIMEOUT_SEC))}s: {' '.join(cmd)}"
        return subprocess.CompletedProcess(
            cmd,
            124,
            stdout=(e.stdout or ""),
            stderr=((e.stderr or "") + ("\n" if e.stderr else "") + detail),
        )


def p4_is_available():
    return bool(shutil.which("p4"))


def p4_open_for_edit_or_add(path, timeout_sec=DEFAULT_P4_TIMEOUT_SEC):
    file_path = str(path)
    fstat = run_p4(["fstat", file_path], timeout_sec)
    fstat_out = (fstat.stdout or "") + (fstat.stderr or "")
    no_depot_record = ("no such file(s)." in fstat_out.lower())
    not_in_client = ("not in client view" in fstat_out.lower())
    if not_in_client:
        return False, "skip", f"outside client view: {file_path}"
    if no_depot_record:
        add = run_p4(["add", file_path], timeout_sec)
        ok = add.returncode == 0
        out = ((add.stdout or "") + (add.stderr or "")).strip()
        return ok, "add", out
    if fstat.returncode != 0:
        return False, "error", fstat_out.strip()
    if "... action " in (fstat.stdout or ""):
        return True, "already_open", "already open for changelist action"
    edit = run_p4(["edit", file_path], timeout_sec)
    ok = edit.returncode == 0
    out = ((edit.stdout or "") + (edit.stderr or "")).strip()
    return ok, "edit", out


def resolve_work_unit_file_path(client, work_unit_path):
    if not work_unit_path:
        return ""
    result = client.call("ak.wwise.core.object.get", {
        "from": {"path": [work_unit_path]},
        "options": {"return": ["path", "type", "name", "filePath"]},
    })
    if not result:
        return ""
    returned = result.get("return", [])
    if not returned:
        return ""
    obj = returned[0]
    if str(obj.get("type", "")) != "WorkUnit":
        return ""
    return str(obj.get("filePath", "") or "")


def expected_originals_files(project_path, originals_subfolder, wav_files):
    if not project_path:
        return []
    project_root = Path(project_path).resolve().parent
    dst_root = project_root / "Originals" / "SFX" / str(originals_subfolder or "").strip("/\\")
    out = []
    for wav in wav_files or []:
        out.append((dst_root / wav.name).resolve())
    return out


def ensure_p4_opened_for_paths(paths, label, policy, timeout_sec=DEFAULT_P4_TIMEOUT_SEC, progress_cb=None):
    stats = {"edit": 0, "add": 0, "already_open": 0, "skip": 0, "error": 0}
    if policy == "off":
        return stats
    if not p4_is_available():
        msg = "[WARN] p4 not found in PATH; skipping source-control operations."
        if policy == "required":
            raise RuntimeError("p4 policy is required but p4 executable is not available")
        print(msg)
        return stats
    total = len(paths or [])
    for idx, path in enumerate(paths or [], start=1):
        ok, action, detail = False, "error", ""
        try:
            ok, action, detail = p4_open_for_edit_or_add(path, timeout_sec)
            if action in stats:
                stats[action] += 1
            else:
                stats["error"] += 1
        except BaseException as e:
            stats["error"] += 1
            action = "error"
            detail = f"unexpected p4 failure: {e}"
        if ok:
            safe_print(f"[INFO] p4 {action:<12} {path}")
        else:
            safe_print(f"[WARN] p4 {action:<12} {path} :: {detail}")
            if policy == "required" and action != "skip":
                raise RuntimeError(f"p4 {action} failed for {label}: {path}")
        if progress_cb:
            try:
                progress_cb(idx, total, path, action, ok)
            except Exception:
                pass
    return stats


def build_imports(wav_files, originals_subfolder, import_target):
    target = import_target.rstrip("\\")
    return [
        {
            "audioFile": str(wav),
            "objectPath": f"{target}\\<Sound SFX>{wav.stem}",
            "originalsSubFolder": originals_subfolder,
        }
        for wav in wav_files
    ]


OBJECT_TYPE_TAGS = {
    "Random Container": "<Random Container>",
    "Blend Container": "<Blend Container>",
    # WAAPI object path tag uses hyphenated Actor-Mixer spelling.
    "Actor Mixer": "<Actor-Mixer>",
    "Folder": "<Folder>",
    "Sound SFX": "<Sound SFX>",
}


def apply_name_pattern(pattern, context):
    out = str(pattern or "")
    for key, value in context.items():
        out = out.replace(f"${key}", str(value))
    return out


def _strip_wav_ext(name):
    return name[:-4] if name.lower().endswith(".wav") else name


def build_structured_object_path(import_target, wav_file, structures, item_context_map):
    target = import_target.rstrip("\\")
    # Item names from Reaper may include the .wav extension; try both forms.
    if isinstance(item_context_map, dict):
        item_ctx = (item_context_map.get(wav_file.stem)
                    or item_context_map.get(wav_file.name)
                    or {})
    else:
        item_ctx = {}
    marker_value = str(item_ctx.get("marker", "") or wav_file.stem)
    region_value = str(item_ctx.get("region", "") or wav_file.stem)
    track_value = str(item_ctx.get("track", "") or wav_file.stem)
    item_value = _strip_wav_ext(str(item_ctx.get("item", "") or wav_file.stem))
    context = {
        "item": item_value,
        "track": track_value,
        "marker": marker_value,
        "region": region_value,
        "parent": wav_file.stem,
    }
    parts = []
    for row in structures or []:
        obj_type = str(row.get("object_type", "") or "").strip()
        name_pattern = str(row.get("object_name", "") or "").strip()
        if not obj_type:
            continue
        tag = OBJECT_TYPE_TAGS.get(obj_type)
        if not tag:
            continue
        obj_name = apply_name_pattern(name_pattern, context).strip() or wav_file.stem
        parts.append(f"{tag}{obj_name}")
    if not parts:
        parts.append(f"{OBJECT_TYPE_TAGS['Sound SFX']}{wav_file.stem}")
    if not any(p.startswith(OBJECT_TYPE_TAGS["Sound SFX"]) for p in parts):
        parts.append(f"{OBJECT_TYPE_TAGS['Sound SFX']}{wav_file.stem}")
    joined = "\\".join(parts)
    return f"{target}\\{joined}"


def build_imports_with_structures(wav_files, originals_subfolder, import_target, structures, item_context_map):
    return [
        {
            "audioFile": str(wav),
            "objectPath": build_structured_object_path(import_target, wav, structures, item_context_map),
            "originalsSubFolder": originals_subfolder,
        }
        for wav in wav_files
    ]


def collect_valid_wavs(raw_args):
    wav_files = []
    skipped = 0
    for arg in raw_args:
        path = Path(arg).resolve()
        if not path.exists():
            print(f"[WARN] File not found, skipping: {path}")
            skipped += 1
            continue
        if path.suffix.lower() != ".wav":
            print(f"[WARN] Not a WAV file, skipping: {path}")
            skipped += 1
            continue
        wav_files.append(path)
    return wav_files, skipped


def print_import_plan(wav_files, originals_subfolder, import_target, structures, item_context_map):
    print("[PLAN] Preview of import actions:")
    for wav in wav_files:
        object_path = build_structured_object_path(import_target, wav, structures, item_context_map)
        print(f"[PLAN] object={object_path}  originals={originals_subfolder}  wav={wav}")


def target_exists(client, import_target):
    result = client.call("ak.wwise.core.object.get", {
        "from": {"path": [import_target]},
        "options": {"return": ["id", "name", "type", "path"]},
    })
    if not result:
        return None
    returned = result.get("return", [])
    return returned[0] if returned else None


def get_open_project_path(client):
    info = client.call("ak.wwise.core.getInfo", {})
    if not info:
        return ""
    return str(info.get("projectPath", "") or "")


def normalize_path_string(path):
    return str(path or "").replace("\\", "/").lower().strip()


def _traverse_wwise_tree(client, base_path, max_depth=0, expandable_types=None):
    """Walk children under base_path.

    Only WorkUnit, Folder, and ActorMixer nodes are expanded further (frontier).
    max_depth: 0 or negative = expand until frontier is empty; positive = at most
    that many expand rounds (legacy escape hatch).
    """
    base_info = target_exists(client, base_path)
    if not base_info:
        return []

    def get_children(paths):
        if not paths:
            return []
        # WAAPI calls with very large "from.path" arrays can become very slow
        # (or appear hung from Reaper ExecProcess). Query in chunks.
        chunk_size = 200
        merged = []
        for i in range(0, len(paths), chunk_size):
            chunk = paths[i:i + chunk_size]
            result = client.call("ak.wwise.core.object.get", {
                "from": {"path": chunk},
                "transform": [{"select": ["children"]}],
                "options": {"return": ["path", "type"]},
            })
            if result:
                merged.extend(result.get("return", []) or [])
        return merged

    objects = [{"path": base_info.get("path", base_path), "type": base_info.get("type", "")}]
    # Only expand nodes that can meaningfully contain import destinations.
    # This avoids fanning out through large amounts of Sound SFX leaves.
    if expandable_types is None:
        expandable_types = {"WorkUnit", "Folder", "ActorMixer"}
    else:
        expandable_types = set(expandable_types)
    base_type = str(base_info.get("type", "") or "")
    frontier = [base_info.get("path", base_path)] if base_type in expandable_types else []

    def advance_frontier(level):
        objects.extend(level)
        return [
            obj.get("path", "")
            for obj in level
            if obj.get("path") and str(obj.get("type", "") or "") in expandable_types
        ]

    cap = int(max_depth) if max_depth is not None else 0
    if cap <= 0:
        while frontier:
            level = get_children(frontier)
            if not level:
                break
            frontier = advance_frontier(level)
    else:
        for _ in range(cap):
            level = get_children(frontier)
            if not level:
                break
            frontier = advance_frontier(level)
    return objects


def list_target_candidates(client, base_path, max_depth=0):
    objects = _traverse_wwise_tree(client, base_path, max_depth)
    if not objects:
        return []
    allowed = {
        "WorkUnit", "Folder", "ActorMixer", "RandomSequenceContainer",
        "SwitchContainer", "BlendContainer"
    }
    paths = [
        obj.get("path", "") for obj in objects
        if obj.get("type", "") in allowed and obj.get("path", "")
    ]
    return sorted(set(paths))


def _is_strict_descendant_of_base(base_path: str, object_path: str) -> bool:
    """True if object_path is under base_path but not the base itself (e.g. exclude \\Actor-Mixer Hierarchy)."""
    b = normalize_path_string(base_path).rstrip("/")
    w = normalize_path_string(object_path).rstrip("/")
    if not b or not w or w == b:
        return False
    return w.startswith(b + "/")


def list_work_units(client, base_path):
    # WorkUnit discovery does not need to fan out across ActorMixer trees.
    # Restrict expansion set to keep "Load WorkUnits" responsive in big projects.
    objects = _traverse_wwise_tree(client, base_path, 0, {"WorkUnit", "Folder"})
    if not objects:
        return []
    paths = []
    for obj in objects:
        if str(obj.get("type", "") or "") != "WorkUnit":
            continue
        p = obj.get("path", "") or ""
        if not p or not _is_strict_descendant_of_base(base_path, p):
            continue
        paths.append(p)
    return sorted(set(paths))


def count_sound_sfx(objects):
    count = 0
    for obj in objects or []:
        obj_type = str(obj.get("type", "") or "").lower()
        if obj_type in ("sound", "sound sfx", "soundsfx", "audiofilesource", "soundvoice"):
            count += 1
    return count


def _to_bool(value, default=False):
    if isinstance(value, bool):
        return value
    if value is None:
        return default
    if isinstance(value, (int, float)):
        return value != 0
    text = str(value).strip().lower()
    if text in ("1", "true", "yes", "on"):
        return True
    if text in ("0", "false", "no", "off", ""):
        return False
    return default


# ---------------------------------------------------------------------------
# Main entry point — parameter resolution and mode dispatch
# ---------------------------------------------------------------------------

def _resolve_params(args, config, request):
    return {
        "originals_subfolder": (
            args.originals_subfolder
            or request.get("originals_subfolder")
            or config["originals_subfolder"]
        ),
        "import_target": (
            args.import_target
            or request.get("import_target")
            or config["wwise_import_target"]
        ),
        "import_operation": (
            args.import_operation
            or request.get("import_operation")
            or config.get("import_operation", "useExisting")
        ),
        "import_batch_size": int(request.get("import_batch_size") or config.get("import_batch_size") or 48),
        "property_template_path": (
            args.property_template_path
            or request.get("property_template_path")
            or ""
        ),
        "expected_project_path": (
            args.expected_project_path
            or request.get("expected_project_path")
            or ""
        ),
        "wav_arg_list": args.wav_files or request.get("wav_files", []),
        "structures": request.get("structures", []),
        "item_context_map": request.get("item_context_map", {}),
        "status_file": request.get("status_file", ""),
        "selected_wwu": str(request.get("selected_wwu") or ""),
        "debug_mode": _to_bool(request.get("debug_mode"), False),
        "p4_policy": normalize_p4_policy(
            request.get("p4_policy") or config.get("p4_policy") or "auto"
        ),
        "p4_timeout_sec": int(request.get("p4_timeout_sec") or config.get("p4_timeout_sec") or DEFAULT_P4_TIMEOUT_SEC),
        "object_map_file": str(request.get("object_map_file") or ""),
    }


def _detect_mode(args):
    if args.list_import_targets:
        return "list"
    if args.list_work_units:
        return "list_wwu"
    if args.validate_target_only:
        return "validate"
    if args.preview_only:
        return "preview"
    return "import"


def _print_startup_info(params):
    print(f"[INFO] Originals subfolder : {params['originals_subfolder']}")
    print(f"[INFO] Import target       : {params['import_target']}")
    print(f"[INFO] Import operation    : {params['import_operation']}")
    print(f"[INFO] Import batch size   : {params['import_batch_size']}")
    print(f"[INFO] Debug mode         : {'on' if params['debug_mode'] else 'off'}")
    if SCRIPT_P4_ENABLED:
        print(f"[INFO] p4 policy           : {params['p4_policy']}")
        print(f"[INFO] p4 timeout (sec)    : {params['p4_timeout_sec']}")
    else:
        print("[INFO] p4 integration      : disabled (using Wwise/other integration only)")
    if params["property_template_path"]:
        print(f"[INFO] Property template  : {params['property_template_path']}")


def _validate_project_path(client, expected_project_path):
    open_project_path = get_open_project_path(client)
    if open_project_path:
        print(f"[INFO] Open project path   : {open_project_path}")
    else:
        print("[WARN] Could not read opened Wwise project path from WAAPI.")
    if expected_project_path:
        print(f"[INFO] Expected project    : {expected_project_path}")
        if open_project_path and (
            normalize_path_string(open_project_path) != normalize_path_string(expected_project_path)
        ):
            print("[ERROR] Opened Wwise project does not match expected project path.")
            sys.exit(1)
    return open_project_path


def _resolve_target(client, params, mode):
    import_target = params["import_target"]
    property_template_path = params["property_template_path"]
    status_file = params["status_file"]
    selected_wwu = params["selected_wwu"]

    target_info = target_exists(client, import_target)
    if not target_info:
        write_status_file(status_file, {"state": "error", "mode": mode, "message": "target not found"})
        print(f"[ERROR] Wwise target path not found: {import_target}")
        sys.exit(1)
    print(f"[INFO] Target resolved    : {target_info.get('path', import_target)}")
    if selected_wwu:
        print(f"[INFO] Selected WorkUnit  : {selected_wwu}")

    if property_template_path:
        template_info = target_exists(client, property_template_path)
        if not template_info:
            write_status_file(status_file, {"state": "error", "mode": mode, "message": "template not found"})
            print(f"[ERROR] Property template path not found: {property_template_path}")
            sys.exit(1)
        print(f"[INFO] Template resolved : {template_info.get('path', property_template_path)}")

    return target_info


def _run_list(client, args, status_file):
    candidates = list_target_candidates(client, args.list_base_path, args.list_depth)
    if not candidates:
        write_status_file(status_file, {"state": "error", "mode": "list", "message": "no candidates"})
        print(f"[ERROR] No target candidates found under: {args.list_base_path}")
        sys.exit(1)
    print(f"[INFO] Target list base   : {args.list_base_path}")
    print(f"[INFO] Candidates found   : {len(candidates)}")
    for path in candidates:
        print(f"[TARGET] {path}")
    write_result_file(args.result_file, {
        "mode": "list",
        "base_path": args.list_base_path,
        "items": candidates,
    })
    print(f"[SUMMARY] mode=list status=ok base={args.list_base_path} count={len(candidates)}")
    write_status_file(status_file, {
        "state": "done", "mode": "list", "status": "ok", "count": len(candidates),
    })


def _run_list_wwu(client, args, status_file):
    wwus = list_work_units(client, args.list_base_path)
    if not wwus:
        write_status_file(status_file, {"state": "error", "mode": "list_wwu", "message": "no work units"})
        print(f"[ERROR] No Work Units found under: {args.list_base_path}")
        sys.exit(1)
    print(f"[INFO] WorkUnit list base : {args.list_base_path}")
    print(f"[INFO] WorkUnits found    : {len(wwus)}")
    for path in wwus:
        print(f"[WWU] {path}")
    write_result_file(args.result_file, {
        "mode": "list_wwu",
        "base_path": args.list_base_path,
        "items": wwus,
    })
    print(f"[SUMMARY] mode=list_wwu status=ok base={args.list_base_path} count={len(wwus)}")
    write_status_file(status_file, {
        "state": "done", "mode": "list_wwu", "status": "ok", "count": len(wwus),
    })


def _run_validate(status_file):
    print("[OK] Target validation succeeded.")
    print("[SUMMARY] mode=validate status=ok")
    write_status_file(status_file, {"state": "done", "mode": "validate", "status": "ok"})


def _run_preview(wav_files, skipped, params):
    status_file = params["status_file"]
    print_import_plan(
        wav_files,
        params["originals_subfolder"],
        params["import_target"],
        params["structures"],
        params["item_context_map"],
    )
    print(f"[SUMMARY] mode=preview status=ok requested={len(wav_files)} skipped={skipped}")
    write_status_file(status_file, {
        "state": "done", "mode": "preview", "status": "ok",
        "requested": len(wav_files), "skipped": skipped,
    })


def _run_import(client, params, wav_files, skipped, target_info, open_project_path):
    status_file = params["status_file"]
    selected_wwu = params["selected_wwu"]
    p4_policy = params["p4_policy"]
    p4_timeout_sec = params["p4_timeout_sec"]
    originals_subfolder = params["originals_subfolder"]
    import_target = params["import_target"]
    import_operation = params["import_operation"]
    import_batch_size = max(1, int(params.get("import_batch_size") or 48))
    structures = params["structures"]
    item_context_map = params["item_context_map"]
    expected_project_path = params["expected_project_path"]
    write_running_stage(status_file, "import", "start", {
        "requested_wavs": len(wav_files),
        "import_target": import_target,
    })

    p4_wwu_stats = {"edit": 0, "add": 0, "already_open": 0, "skip": 0, "error": 0}
    if SCRIPT_P4_ENABLED and selected_wwu:
        wwu_file = resolve_work_unit_file_path(client, selected_wwu)
        print("[STAGE] p4_wwu_open:start")
        write_running_stage(status_file, "import", "p4_wwu_open")
        if wwu_file:
            p4_wwu_stats = ensure_p4_opened_for_paths([wwu_file], "WorkUnit", p4_policy, p4_timeout_sec)
        else:
            msg = f"[WARN] Could not resolve WorkUnit file path for: {selected_wwu}"
            if p4_policy == "required":
                raise RuntimeError(msg)
            print(msg)
        print("[STAGE] p4_wwu_open:done")

    total_wavs = len(wav_files)
    total_batches = (total_wavs + import_batch_size - 1) // import_batch_size
    created = []
    print("[STAGE] waapi_import:start")
    for i in range(total_batches):
        batch = wav_files[i * import_batch_size:(i + 1) * import_batch_size]
        batch_no = i + 1
        print(f"[STAGE] waapi_import:batch {batch_no}/{total_batches} (files={len(batch)})")
        write_running_stage(status_file, "import", "waapi_import", {
            "batch_index": batch_no,
            "batch_count": total_batches,
            "batch_wavs": len(batch),
            "requested_wavs": total_wavs,
        })
        imports_payload = build_imports_with_structures(
            batch, originals_subfolder, import_target, structures, item_context_map
        )
        if params["debug_mode"]:
            print(f"[DEBUG] Batch {batch_no} objectPaths sent to WAAPI:")
            for entry in imports_payload:
                print(f"[DEBUG]   {entry['objectPath']}")
        result = client.call("ak.wwise.core.audio.import", {
            "importOperation": import_operation,
            "default": {"importLanguage": "SFX"},
            "imports": imports_payload,
        })
        if result:
            batch_objects = result.get("objects", []) or []
            created.extend(batch_objects)
            if params["debug_mode"]:
                print(f"[DEBUG] Batch {batch_no} objects created by WAAPI:")
                for obj in batch_objects:
                    if isinstance(obj, dict):
                        print(f"[DEBUG]   type={obj.get('type','?')} name={obj.get('name','?')} path={obj.get('path','?')} id={obj.get('id','?')}")
    print("[STAGE] waapi_import:done")
    raw_sound_sfx_count = count_sound_sfx(created)
    # WAAPI may return non-uniform type labels across versions/projects.
    # Keep "Processed Sound SFX" aligned with user-visible import result.
    sound_sfx_count = raw_sound_sfx_count if raw_sound_sfx_count > 0 else len(wav_files)
    write_running_stage(status_file, "import", "post_waapi", {
        "requested_wavs": len(wav_files),
        "processed_objects": len(created),
        "processed_sound_sfx": sound_sfx_count,
        "core_import_done": True,
    })
    print(f"[OK] Wwise import succeeded. {len(created)} object(s) processed.")
    # Avoid flooding stdout in background mode.
    preview_max = 20
    if len(created) <= preview_max:
        for obj in created:
            if isinstance(obj, dict):
                print(f"    - {obj.get('name', '?')}  ({obj.get('id', '?')})")
            else:
                print(f"    - {str(obj)}")
    else:
        print(f"[INFO] Imported objects preview (first {preview_max}/{len(created)}):")
        for obj in created[:preview_max]:
            if isinstance(obj, dict):
                print(f"    - {obj.get('name', '?')}  ({obj.get('id', '?')})")
            else:
                print(f"    - {str(obj)}")
        print(f"[INFO] ... {len(created) - preview_max} more object(s) omitted")
    if params["property_template_path"]:
        print("[WARN] Property template apply is not implemented yet in v0.1.")

    project_for_map = (expected_project_path or open_project_path or "").strip()
    target_path_resolved = str(target_info.get("path", import_target) or import_target)
    print("[STAGE] object_map:start")
    write_running_stage(status_file, "import", "object_map", {
        "processed_objects": len(created),
        "processed_sound_sfx": sound_sfx_count,
    })
    merge_object_map_from_import(
        params["object_map_file"],
        project_for_map,
        target_path_resolved,
        wav_files,
        created,
    )
    print("[STAGE] object_map:done")

    p4_wav_stats = {"edit": 0, "add": 0, "already_open": 0, "skip": 0, "error": 0}
    if SCRIPT_P4_ENABLED:
        originals_files = expected_originals_files(project_for_map, originals_subfolder, wav_files)
        print("[STAGE] p4_wav_open:start")
        write_running_stage(status_file, "import", "p4_wav_open", {
            "originals_wavs": len(originals_files),
            "core_import_done": True,
        })
        def _p4_wav_progress(idx, total, _path, _action, _ok):
            if idx == 1 or idx == total or idx % 10 == 0:
                write_running_stage(status_file, "import", "p4_wav_open", {
                    "originals_wavs": total,
                    "p4_processed": idx,
                    "core_import_done": True,
                })

        p4_wav_stats = ensure_p4_opened_for_paths(
            originals_files,
            "Originals WAV",
            p4_policy,
            p4_timeout_sec,
            _p4_wav_progress,
        )
        print("[STAGE] p4_wav_open:done")
    write_status_file(status_file, {
        "state": "done", "mode": "import", "status": "ok",
        "requested_wavs": len(wav_files),
        "processed_objects": len(created),
        "processed_sound_sfx": sound_sfx_count,
        "skipped": skipped,
        "p4_wwu_stats": p4_wwu_stats,
        "p4_wav_stats": p4_wav_stats,
    })
    safe_print(
        f"[INFO] p4 summary         : "
        f"wwu(edit={p4_wwu_stats['edit']}, add={p4_wwu_stats['add']}, open={p4_wwu_stats['already_open']}, "
        f"skip={p4_wwu_stats['skip']}, err={p4_wwu_stats['error']}) "
        f"wav(edit={p4_wav_stats['edit']}, add={p4_wav_stats['add']}, open={p4_wav_stats['already_open']}, "
        f"skip={p4_wav_stats['skip']}, err={p4_wav_stats['error']})"
    )
    safe_print(
        f"[SUMMARY] mode=import status=ok requested_wavs={len(wav_files)} "
        f"processed_objects={len(created)} processed_sound_sfx={sound_sfx_count} "
        f"skipped={skipped}"
    )


def main():
    args = parse_args()
    config = load_config()
    request = load_request_file(args.request_file)
    params = _resolve_params(args, config, request)
    mode = _detect_mode(args)
    write_status_file(params["status_file"], {"state": "running", "mode": mode})
    _print_startup_info(params)

    wav_files = []
    try:
        with WaapiClient(url=config["waapi_url"]) as client:
            open_project_path = _validate_project_path(client, params["expected_project_path"])

            if args.list_import_targets:
                _run_list(client, args, params["status_file"])
                return
            if args.list_work_units:
                _run_list_wwu(client, args, params["status_file"])
                return

            target_info = _resolve_target(client, params, mode)

            if args.validate_target_only:
                _run_validate(params["status_file"])
                return

            wav_files, skipped = collect_valid_wavs(params["wav_arg_list"])
            if not wav_files:
                write_status_file(params["status_file"], {"state": "error", "mode": mode, "message": "no valid wav"})
                print("[ERROR] No valid WAV files to import.")
                sys.exit(1)
            print(f"[INFO] Files to import     : {len(wav_files)}")

            if args.preview_only:
                _run_preview(wav_files, skipped, params)
                return

            _run_import(client, params, wav_files, skipped, target_info, open_project_path)
    except CannotConnectToWaapiException:
        write_status_file(params["status_file"], {"state": "error", "mode": mode, "message": "cannot connect waapi"})
        print(f"[ERROR] Cannot connect to Wwise at {config['waapi_url']}")
        print("        Make sure Wwise is running and WAAPI is enabled.")
        sys.exit(1)
    except Exception as e:
        write_status_file(params["status_file"], {"state": "error", "mode": mode, "message": str(e)})
        print(f"[ERROR] WAAPI call failed: {e}")
        sys.exit(1)
    except BaseException as e:
        # Catch non-Exception failures (e.g. KeyboardInterrupt/SystemExit) so status
        # never gets stuck at running without an explicit terminal state.
        write_status_file(params["status_file"], {"state": "error", "mode": mode, "message": f"fatal: {e}"})
        raise

    if args.delete_after and not args.validate_target_only:
        for wav in wav_files:
            try:
                wav.unlink()
            except Exception as e:
                print(f"[WARN] Could not delete {wav}: {e}")
        print(f"[INFO] Cleaned up {len(wav_files)} temp file(s).")


if __name__ == "__main__":
    main()
