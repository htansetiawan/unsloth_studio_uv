#!/usr/bin/env bash
# Install Unsloth Studio into a uv-managed project.
# Replaces:  curl -fsSL https://unsloth.ai/install.sh | sh
#
# Effects:
#   - Creates a uv project at $PROJECT_DIR (default: ~/unsloth-studio)
#   - Tracks deps in pyproject.toml + uv.lock
#   - Pre-installs transformers 5.3.0 / 5.5.0 into side-target dirs (used by
#     studio's training subprocess, mirrors official setup.sh behavior)
#   - Fetches prebuilt llama.cpp into ~/.unsloth/llama.cpp
#   - Symlinks ~/.local/bin/unsloth to the project venv
#
# Skipped vs official installer:
#   - React frontend build (frontend/dist/ already ships with the studio pkg)
#   - Source build of llama.cpp (only the prebuilt fetcher is used)
#   - Desktop shortcuts, Colab/Tauri/ROCm/Metal special cases

set -euo pipefail

PROJECT_DIR="${UNSLOTH_PROJECT_DIR:-$HOME/unsloth-studio}"
LLAMA_DIR="$HOME/.unsloth/llama.cpp"
T5_530="$HOME/.unsloth/studio/.venv_t5_530"
T5_550="$HOME/.unsloth/studio/.venv_t5_550"

echo "==> Project dir: $PROJECT_DIR"

# 1. Ensure uv is available.
if ! command -v uv >/dev/null 2>&1; then
    echo "==> Installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# 2. Create / re-enter uv project.
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
if [ ! -f pyproject.toml ]; then
    uv init --name unsloth-studio --python 3.13 --bare .
fi

# 3. Add deps. Tracked in pyproject.toml. Pins mirror the official
#    studio/backend/requirements/*.txt files.
echo "==> Adding core unsloth + studio deps"
uv add "unsloth>=2026.4.8" unsloth-zoo

uv add \
    typer fastapi uvicorn pydantic \
    matplotlib pandas nest_asyncio \
    "datasets==4.3.0" \
    pyjwt easydict addict \
    "huggingface-hub==0.36.2" \
    "structlog>=24.1.0" \
    diceware ddgs \
    python-multipart

# 4. Pre-install pinned transformers tiers used by the studio training
#    subprocess (it prepends these dirs to sys.path at runtime).
echo "==> Pre-installing transformers 5.3.0 / 5.5.0 side-target dirs"
mkdir -p "$T5_530" "$T5_550"
uv pip install --target "$T5_530" --no-deps \
    "transformers==5.3.0" "huggingface_hub==1.8.0" "hf_xet==1.4.2"
uv pip install --target "$T5_530" tiktoken
uv pip install --target "$T5_550" --no-deps \
    "transformers==5.5.0" "huggingface_hub==1.8.0" "hf_xet==1.4.2"
uv pip install --target "$T5_550" tiktoken

# 5. Fetch prebuilt llama.cpp via the helper that ships with unsloth.
echo "==> Installing prebuilt llama.cpp"
PY="$PROJECT_DIR/.venv/bin/python"
HELPER="$("$PY" -c 'import importlib.util, pathlib
spec = importlib.util.find_spec("studio")
print(pathlib.Path(spec.origin).parent / "install_llama_prebuilt.py")')"
mkdir -p "$LLAMA_DIR"
"$PY" "$HELPER" \
    --install-dir "$LLAMA_DIR" \
    --llama-tag latest \
    --published-repo unslothai/llama.cpp \
    --simple-policy

# 6. Symlink unsloth CLI onto PATH.
echo "==> Symlinking unsloth CLI"
mkdir -p "$HOME/.local/bin"
ln -sf "$PROJECT_DIR/.venv/bin/unsloth" "$HOME/.local/bin/unsloth"

cat <<EOF

==> Done.
    Project   : $PROJECT_DIR
    llama.cpp : $LLAMA_DIR
    CLI       : $(command -v unsloth || echo "$HOME/.local/bin/unsloth")

Launch:
    unsloth studio
    # or, equivalently, from the project dir:
    cd $PROJECT_DIR && uv run unsloth studio

Update later:
    cd $PROJECT_DIR && uv lock --upgrade && uv sync
EOF
