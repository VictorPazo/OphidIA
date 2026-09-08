# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

OphidIA (repo name `snakes_of_imt`) is an academic capstone project: a cross-platform Flutter mobile app that
classifies Brazilian snake species from a photo, using a PyTorch/ConvNeXt-Tiny model served over a separate FastAPI
backend. The current model covers **246 species across 59 genera** (~61% of Brazil's snakes) at 76.8% top-1 / 90.0%
top-3 accuracy; it was trained outside this repo (`D:\treino_v2`) on the `D:\serpentes_512` dataset.
The app also shows species info (venom type, antivenom) and a map of
nearby sighting records via Google Maps.

The repo contains three loosely-coupled parts:
- **`lib/`** — the Flutter/Dart app (this is the main thing Claude Code will be asked to edit).
- **`lib/models/*.py`** — the standalone FastAPI inference server + PyTorch training/eval scripts (not part of the
  Flutter build; run separately with Python).
- **`lib/scripts/*.py`** — a one-off ETL pipeline for populating the Supabase `snakes` table from GBIF data (see
  `lib/scripts/README.md` for the 3-step fetch → enrich → insert flow).

## Commands

Flutter/Dart (run from repo root):
```bash
flutter pub get              # install dependencies
flutter run                  # run the app on a connected device/emulator
flutter analyze              # static analysis (flutter_lints)
flutter test                 # run all tests
flutter test test/widget_test.dart   # run a single test file
```
Note: `test/widget_test.dart` is still the default Flutter counter-app template and does not test this app's actual
widgets — don't treat it as a meaningful example of test coverage or app behavior.

Python inference backend (`lib/models/`):
```bash
cd lib/models
pip install -r requirements.txt   # torch/torchvision, fastapi, uvicorn, python-multipart, pillow
python main.py                # not directly runnable; serve with uvicorn, e.g.:
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
`requirements.txt` also carries the training/eval-only extras (numpy, matplotlib, scikit-learn, pandas) used by the
`.py` scripts in the same folder; the server itself doesn't need them. Installing `torch` from PyPI gives the CPU
build — for GPU, use `--index-url https://download.pytorch.org/whl/cu130` as noted in the file.
The server resolves `classes.json` and `best_model.pth` relative to its own file, so it can be started from any
directory. It exposes a single `POST /predict` endpoint (multipart image upload) returning
`{snake_id, specie, confidence}`, where **`snake_id` is null** for any species not yet mapped in `SPECIE_TO_ID`
(currently only the 26 *Bothrops* rows) — callers must handle that.

`best_model.pth` is **not in git** (107 MB, over GitHub's 100 MB per-file limit; `*.pth` is gitignored). It ships as a
release asset — download it into `lib/models/` before starting the server (see `SETUP.md` step 3):
`https://github.com/VictorPazo/OphidIA/releases/download/ModeloConvNeXt-Tiny_v2/best_model.pth`. Each release's
description names the commit whose `classes.json` it pairs with; a mismatched pair silently swaps predictions. `ARCHITECTURE`, `IMG_SIZE` and `DROPOUT` at the top of
`main.py` must match `D:\treino_v2\config_utilizada.json` — a mismatch in the transform degrades accuracy silently
rather than raising.

Python Supabase-population pipeline (`lib/scripts/`):
```bash
cd lib/scripts
pip install -r requirements.txt
python fetch_gbif.py <Genus>
python enrich.py <Genus>
python insert_supabase.py <Genus>   # keep dry_run=True in the script until data is reviewed
```

## Architecture

**Screens** (`lib/screens/`) are simple `StatefulWidget`/`StatelessWidget` pages, barrel-exported through
`screens.dart` (which also re-exports `package:flutter/material.dart`, so screen files only need
`import 'screens.dart';`). Navigation is straightforward `Navigator.push`/bottom-nav index switching, not a router
package. `home.dart` hosts the Google Map + nearby-sightings view; `camera.dart` handles capture/upload and calls the
inference service; `snake_information.dart` renders a `SnakeModel` fetched from Supabase.

**Services** (`lib/services/`) wrap all external I/O and are barrel-exported through `services.dart`. Each service is
a thin class around a single `Supabase.instance.client` or `http` call — no shared base class or DI container:
- `AuthService` — Supabase Auth (signup/login), including password-strength validation and Portuguese-language error
  mapping for known Supabase auth error messages.
- `StorageService` / `UploadService` — both upload images to the Supabase `user-history` storage bucket and return an
  `UploadResult`; they are near-duplicates (one returns a signed URL scoped to the current user, the other a public
  URL under a shared `uploads/` path) — check which one a call site actually needs before assuming they're
  interchangeable or before consolidating them.
- `SnakeInformationService` — fetches a `SnakeModel` row from the Supabase `snakes` table by id.
- `IbgeService` — looks up Brazilian municipalities by state (UF) from the public IBGE API, used in the registration
  city/state picker.
- `IAService` (in `agent_service.dart`) — calls the FastAPI `/predict` endpoint with a captured/picked image file.
  **`baseUrl` is a hardcoded local IP/placeholder** ("colocar ip aqui") — it must point at wherever `lib/models`'
  FastAPI server is actually running (same LAN IP:8000 during development), so update it when the inference server's
  host changes.

**Models** (`lib/models/*.dart`) are plain Dart data classes with a `fromMap` factory matching the Supabase table
schema (snake_case keys from Postgres mapped to Dart fields), e.g. `SnakeModel`, `UploadResult`. Don't confuse these
with the Python files that also live under `lib/models/` — the `.dart` and `.py` files in that directory are
unrelated (Dart data models vs. the PyTorch training/inference code); it's a naming collision, not a shared module.

**Localization**: `easy_localization` with `assets/translations/{en-US,pt-BR}.json`, default/fallback locale is
`pt-BR` (set in `lib/main.dart`). Wrap new user-facing strings with `.tr()` and add keys to both translation files
rather than hardcoding Portuguese or English text — though most existing UI strings are still hardcoded Portuguese
and haven't been migrated yet.

**Backend**: Supabase (Postgres + Auth + Storage) is initialized once in `lib/main.dart` with a hardcoded project URL
and anon key, then accessed everywhere via `Supabase.instance.client`. Relevant tables/buckets: `snakes` (species
info), `user-history` (storage bucket for uploaded photos). The FastAPI/PyTorch inference server is a separate
process from Supabase and is not deployed anywhere — it's expected to be run locally/on a LAN host during
development.
