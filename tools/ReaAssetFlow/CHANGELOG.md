# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Renamed the product from ReaperToWwise to ReaAssetFlow.
- Renamed the REAPER entry script from `scripts/rtw_panel.lua` to
  `scripts/ReaAssetFlow.lua`.
- Moved the maintained source baseline into the ReaTools monorepo.

## [0.1.0] - 2026-04-22

### Added

- `tests/` — `pytest` coverage for pure helpers in `wwise_import.py`.
- `pyproject.toml` — pytest `pythonpath` so tests can import `wwise_import`.
- GitHub Actions workflow to run `pytest` and `py_compile` on Windows.
- `.editorconfig` for consistent indentation and line endings.
- `p4_policy` default in `wwise_import.py` `DEFAULT_CONFIG` (optional `config.local.json` override).

### Changed

- Renamed `scripts/rtw_import.lua` to `scripts/rtw_panel.lua` (Reaper actions / docs should load the new path).
- **Configuration**: removed tracked `config.json`; `wwise_import.py` uses `DEFAULT_CONFIG` with optional merge of root `config.json` / `config.local.json` if present. Reaper panel shows hint until `.wproj` is chosen via Browse.
- `requirements.txt` — `pytest` merged in; removed separate `requirements-dev.txt`.
- Pinned `waapi-client` to `0.8.1` in `requirements.txt`.
- `README.md` — Perforce policy, testing instructions, and script layout aligned with the repository.
- `rtw_panel.lua` — single ReaScript entry point; auto naming inlined (removed `rtw_auto_name.lua` / `auto_name_items.lua`).

### Removed

- `scripts/rtw_auto_name.lua`, `scripts/auto_name_items.lua` — consolidated into `rtw_panel.lua`.
- `config.json` from repo — defaults live in `wwise_import.py`; panel + `_state` for paths.
