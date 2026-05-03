# unsloth-uv-installer

A drop-in alternative to `curl -fsSL https://unsloth.ai/install.sh | sh` that uses [`uv`](https://github.com/astral-sh/uv) to manage every Python dependency.

## Motivation

I love [Unsloth](https://unsloth.ai) — almost everything just works. But when I tried installing on a fresh **Ubuntu 24.04 LTS** box, the official installer's `pip install torch` step failed midway, and there's no clean recovery path: the venv was left half-populated and every subsequent `unsloth studio` invocation failed.

Switching the Python side of the install to `uv` fixes most of that:

- **Atomic & resumable.** `uv` resolves the full dep graph up front and writes a `uv.lock`. Reruns are idempotent — interrupted installs heal on retry instead of leaving you stuck.
- **Tracked.** Deps live in `pyproject.toml` instead of being scattered across multiple requirements files invoked with mixed `--no-deps` flags.
- **Faster.** Parallel downloads + a global cache.

This installer is a thin shell around the same Unsloth packages and the same `llama.cpp` prebuilt helper that the official installer uses — it just swaps `pip` for `uv`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/htansetiawan/unsloth-uv-installer/main/install-unsloth-uv.sh | bash
```

Then launch:

```bash
unsloth studio   # http://localhost:8888
```

Override the project location if you want:

```bash
UNSLOTH_PROJECT_DIR=~/code/unsloth bash install-unsloth-uv.sh
```

## What it does

1. Bootstraps `uv` if missing.
2. Creates a uv project at `~/unsloth-studio/` with `pyproject.toml` + `uv.lock`.
3. `uv add`s `unsloth`, `unsloth-zoo`, and the studio backend deps (mirrors the official `studio/backend/requirements/studio.txt`, plus the implicit `python-multipart`).
4. Pre-installs the pinned `transformers==5.3.0` / `5.5.0` side-target dirs the studio training subprocess prepends to `sys.path`.
5. Fetches prebuilt `llama.cpp` into `~/.unsloth/llama.cpp/` via the helper that ships with `unsloth` (`install_llama_prebuilt.py`).
6. Symlinks `~/.local/bin/unsloth` to the new venv.

## What it does NOT do

Kept small on purpose — re-add if you need them:

- No React frontend rebuild — the `frontend/dist/` bundled inside the installed `studio` package is used as-is.
- No source build of `llama.cpp` — only the prebuilt fetcher runs. For GPUs without a prebuilt you'll still need `cmake`, `git`, `build-essential`, `libcurl4-openssl-dev` and the official `setup.sh` source-build path.
- No Colab / Tauri desktop / ROCm / Metal special cases, and no desktop shortcuts.

## Credit

All the heavy lifting is still Unsloth's. Huge thanks to the Unsloth team — please go support [unsloth.ai](https://unsloth.ai) and the [unslothai/unsloth](https://github.com/unslothai/unsloth) repo.
