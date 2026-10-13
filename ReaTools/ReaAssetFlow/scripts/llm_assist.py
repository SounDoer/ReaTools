# @noindex
"""
LLM-assisted utilities for ReaAssetFlow — requires Ollama running locally.

Commands:
  suggest-pattern     Suggest a Reaper auto-name pattern based on project context.
  suggest-structure   Suggest a Wwise hierarchy structures array based on project context.
  validate-names      Check WAV file stems against a naming convention.

Usage:
  python llm_assist.py suggest-pattern --tracks "Footstep" "Weapon" --markers "Walk" "Run"
  python llm_assist.py suggest-structure --tracks "Footstep" --markers "Walk" "Run" [--items "name1"]
  python llm_assist.py validate-names --convention "..." --files f1.wav f2.wav ...
"""

import sys
import json
import argparse
from pathlib import Path

DEFAULT_MODEL = "qwen2.5vl:7b"

_PATTERN_SYSTEM = """\
You are a Reaper audio naming expert. Given the track names, marker names, and sample item names
from a Reaper project, suggest the best name pattern for auto-naming audio items.

Available tokens (use exactly as written):
  $track   — the track name
  $marker  — the nearest marker label to the left of the item
  $region  — the region name containing the item
  $idx     — sequential index (1, 2, 3...)
  $idx2    — zero-padded 2-digit index (01, 02, 03...)
  $idx3    — zero-padded 3-digit index (001, 002, 003...)

Rules:
  - Include $track if multiple distinct tracks exist.
  - Include $marker if markers exist and carry meaningful labels (not just numbers).
  - Always end with an index token; prefer $idx2.
  - Respond with ONLY: {"pattern": "<pattern string>"}

Examples:
  Tracks: [Footstep], Markers: [Walk, Run]          → {"pattern": "$track_$marker_$idx2"}
  Tracks: [Footstep, Weapon], Markers: [Walk]        → {"pattern": "$track_$marker_$idx2"}
  Tracks: [Ambience], Markers: []                    → {"pattern": "$track_$idx2"}
  Tracks: [Footstep, Weapon], Markers: []            → {"pattern": "$track_$idx2"}
"""

_STRUCTURE_SYSTEM = """\
You are a Wwise audio middleware expert. Given the track names, marker names, and sample item names
from a Reaper project, suggest the best Wwise hierarchy structures template array.

Available token placeholders (use exactly as written):
  $item    — the WAV file stem
  $track   — the Reaper track name
  $marker  — the Reaper region marker label
  $region  — the Reaper region name
  $parent  — the parent object name

Available object types (use exactly as written):
  "Actor Mixer"
  "Random Container"
  "Blend Container"
  "Folder"
  "Sound SFX"

Rules:
  - Output a TEMPLATE using token placeholders — never hardcode specific names.
  - The LAST entry must always be "Sound SFX".
  - Each entry has exactly two keys: "object_type" and "object_name".
  - Use Actor Mixer for track-level grouping, Random Container for variation grouping.
  - ALWAYS use token placeholders ($track, $marker, $item…) in object_name — NEVER hardcode actual track or marker names.
  - Respond with ONLY: {"structures": [...]}

Examples:
  Tracks: [Footstep], Markers: [Walk, Run] →
    {"structures": [
      {"object_type": "Actor Mixer",      "object_name": "$track"},
      {"object_type": "Random Container", "object_name": "$track_$marker"},
      {"object_type": "Sound SFX",        "object_name": "$item"}
    ]}
  Tracks: [Footstep], Markers: [] →
    {"structures": [
      {"object_type": "Actor Mixer", "object_name": "$track"},
      {"object_type": "Sound SFX",   "object_name": "$item"}
    ]}
"""

_VALIDATE_SYSTEM = """\
You are a game audio asset naming convention validator.
Given a naming convention description and a list of WAV file stems, evaluate each name strictly.
Respond with ONLY a JSON object in this exact format — no text outside the JSON:
{
  "results": [
    {
      "file": "<stem>",
      "valid": true,
      "issues": [],
      "suggestion": ""
    }
  ],
  "summary": "<one-line summary>"
}
"""

_VALID_OBJECT_TYPES = {
    "Actor Mixer", "Random Container", "Blend Container", "Folder", "Sound SFX",
}


def _ollama_chat(model, system, user_prompt):
    try:
        import ollama
    except ImportError:
        print("[ERROR] ollama package not installed. Run: pip install ollama")
        sys.exit(1)
    try:
        response = ollama.chat(
            model=model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_prompt},
            ],
            format="json",
        )
        return response["message"]["content"]
    except Exception as e:
        error_text = str(e)
        lower = error_text.lower()
        if any(k in lower for k in ("connection refused", "failed to connect", "cannot connect", "connection error")):
            print("[ERROR] ollama service unavailable. Install/start Ollama and run: ollama serve")
            sys.exit(1)
        if "timed out" in lower or "timeout" in lower:
            print("[ERROR] ollama request timed out. Make sure Ollama is running: ollama serve")
            sys.exit(1)
        if "model" in lower and ("not found" in lower or "pull" in lower):
            print(f"[ERROR] ollama model not found: {model}. Run: ollama pull {model}")
            sys.exit(1)
        print(f"[ERROR] Ollama request failed: {e}")
        sys.exit(1)


def _parse_json_response(raw):
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        print(f"[ERROR] Model returned invalid JSON:\n{raw}")
        sys.exit(1)


def _build_context_prompt(tracks, markers, items):
    parts = []
    if tracks:
        parts.append(f"Tracks: {', '.join(tracks)}")
    if markers:
        parts.append(f"Markers: {', '.join(markers)}")
    if items:
        parts.append(f"Sample item names: {', '.join(items[:5])}")
    return "\n".join(parts) if parts else "(no context provided)"


def _validate_name_results_integrity(stems, results):
    if not isinstance(results, list):
        print("[ERROR] Model returned invalid 'results' format (expected an array).")
        sys.exit(1)

    expected = set(stems)
    returned = set()

    for idx, entry in enumerate(results):
        if not isinstance(entry, dict):
            print(f"[ERROR] Model returned invalid result entry at index {idx} (expected an object).")
            sys.exit(1)
        file_name = entry.get("file")
        if not isinstance(file_name, str) or not file_name.strip():
            print(f"[ERROR] Model returned a result entry without a valid 'file' at index {idx}.")
            sys.exit(1)
        returned.add(file_name)

    missing = sorted(expected - returned)
    unexpected = sorted(returned - expected)
    if len(results) != len(stems) or missing or unexpected:
        print("[ERROR] Model returned incomplete validation results.")
        print(f"        expected count: {len(stems)}, returned count: {len(results)}")
        if missing:
            print(f"        missing stems : {', '.join(missing)}")
        if unexpected:
            print(f"        extra stems   : {', '.join(unexpected)}")
        sys.exit(1)


def cmd_suggest_pattern(args):
    user_prompt = _build_context_prompt(args.tracks or [], args.markers or [], args.items or [])
    print(f"[INFO] Asking {args.model} for name pattern suggestion...")
    raw = _ollama_chat(args.model, _PATTERN_SYSTEM, user_prompt)
    data = _parse_json_response(raw)

    pattern = data.get("pattern", "")
    if not pattern:
        print("[ERROR] Model returned an empty pattern.")
        sys.exit(1)

    result = json.dumps({"pattern": pattern}, ensure_ascii=False)
    print(result)
    if args.output:
        Path(args.output).write_text(result, encoding="utf-8")


def cmd_suggest_structure(args):
    user_prompt = _build_context_prompt(args.tracks or [], args.markers or [], args.items or [])
    print(f"[INFO] Asking {args.model} for structure suggestion...")
    raw = _ollama_chat(args.model, _STRUCTURE_SYSTEM, user_prompt)
    data = _parse_json_response(raw)

    structures = data.get("structures", [])
    if not structures:
        print("[ERROR] Model returned an empty structures array.")
        sys.exit(1)

    for entry in structures:
        obj_type = entry.get("object_type", "")
        if obj_type not in _VALID_OBJECT_TYPES:
            print(f"[ERROR] Unknown object_type returned by model: '{obj_type}'")
            print(f"        Allowed values: {', '.join(sorted(_VALID_OBJECT_TYPES))}")
            sys.exit(1)

    result = {"structures": structures}
    output_text = json.dumps(result, ensure_ascii=False, indent=2)

    if args.output:
        Path(args.output).write_text(output_text, encoding="utf-8")
        print(f"[OK] Structures written to: {args.output}")
    else:
        print(output_text)


def cmd_validate_names(args):
    stems = [Path(f).stem for f in (args.files or [])]
    if not stems:
        print("[ERROR] No files provided.")
        sys.exit(1)

    stem_list = "\n".join(f"  - {s}" for s in stems)
    user_prompt = (
        f"Naming convention:\n{args.convention}\n\n"
        f"File stems to validate:\n{stem_list}"
    )

    print(f"[INFO] Asking {args.model} to validate {len(stems)} file name(s)...")
    raw = _ollama_chat(args.model, _VALIDATE_SYSTEM, user_prompt)
    data = _parse_json_response(raw)

    results = data.get("results", [])
    _validate_name_results_integrity(stems, results)
    summary = data.get("summary", "")
    invalid_count = sum(1 for r in results if not r.get("valid"))

    for r in results:
        status = "OK  " if r.get("valid") else "FAIL"
        print(f"[{status}] {r.get('file', '?')}")
        for issue in r.get("issues", []):
            print(f"         issue   : {issue}")
        suggestion = r.get("suggestion", "")
        if suggestion:
            print(f"         suggest : {suggestion}")

    if summary:
        print(f"[SUMMARY] {summary}")

    if args.output:
        Path(args.output).write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        print(f"[OK] Results written to: {args.output}")

    if invalid_count > 0:
        sys.exit(2)


def _add_context_args(parser):
    parser.add_argument("--tracks",  nargs="*", metavar="NAME", help="Track names in the project")
    parser.add_argument("--markers", nargs="*", metavar="NAME", help="Marker names in the project")
    parser.add_argument("--items",   nargs="*", metavar="NAME", help="Sample item export names")
    parser.add_argument("--output",  metavar="FILE", help="Write JSON result to this file")


def main():
    parser = argparse.ArgumentParser(description="LLM-assisted utilities for ReaAssetFlow")
    parser.add_argument("--model", default=DEFAULT_MODEL,
                        help=f"Ollama model name (default: {DEFAULT_MODEL})")
    sub = parser.add_subparsers(dest="command", required=True)

    p_pattern = sub.add_parser(
        "suggest-pattern",
        help="Suggest a Reaper auto-name pattern based on project context",
    )
    _add_context_args(p_pattern)

    p_structure = sub.add_parser(
        "suggest-structure",
        help="Suggest a Wwise hierarchy structures array based on project context",
    )
    _add_context_args(p_structure)

    p_validate = sub.add_parser(
        "validate-names",
        help="Check WAV file stems against a naming convention",
    )
    p_validate.add_argument("--convention", required=True,
                            help="Naming convention description in plain language")
    p_validate.add_argument("--files", nargs="+", required=True, metavar="WAV")
    p_validate.add_argument("--output", metavar="FILE")

    args = parser.parse_args()

    if args.command == "suggest-pattern":
        cmd_suggest_pattern(args)
    elif args.command == "suggest-structure":
        cmd_suggest_structure(args)
    elif args.command == "validate-names":
        cmd_validate_names(args)


if __name__ == "__main__":
    main()
