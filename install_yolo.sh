#!/usr/bin/env bash
# env_setup.sh — Jetson-friendly YOLO installer using uv pip + system site packages
# - Detects JetPack/CUDA
# - Loads wheel mappings from known_wheels.sh
# - Installs CUDA keyring + libcusparselt
# - Creates venv with --system-site-packages
# - Installs matched wheels (verified) + remaining deps with `uv pip`

set -Eeuo pipefail

# --------------------------- CONFIG ----------------------------------
PYTHON_VERSION="${PYTHON_VERSION:-3.10}"      # Match your wheel ABI (cp310 in examples)
VENV_DIR="${VENV_DIR:-$HOME/yolo-venv}"
WHEELS_DIR="${WHEELS_DIR:-./whls}"
EXTRA_INDEX_URL="${EXTRA_INDEX_URL:-}"        # e.g., https://pypi.org/simple
REQ_FILE="${REQ_FILE:-}"                      # Optional requirements.txt
NVCC="/usr/local/cuda/bin/nvcc"
INSTALL_PACKAGES=(
  "ultralytics[export]"
  "onnx"
  "onnxruntime"
  "onnxslim"
  "numpy<2"
)

# ------------------------- UTILITIES ---------------------------------
log()  { printf "\n==> %s\n" "$*"; }
warn() { printf "!! %s\n" "$*" >&2; }
die()  { warn "$*"; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing '$1'"; }

need sudo; need wget; need dpkg; need apt-get; need curl

ARCH="$(uname -m)"
[[ "$ARCH" == "aarch64" ]] || warn "Non-aarch64 host ($ARCH). Jetson wheels may not match."

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  [[ "${VERSION_CODENAME:-}" == "jammy" ]] || warn "Assumes Ubuntu 22.04 (jammy); detected ${VERSION_CODENAME:-unknown}"
fi

# ----------------- Detect JetPack (L4T) / CUDA -----------------------
get_jetpack_version() {
  if dpkg -s nvidia-l4t-core >/dev/null 2>&1; then
    dpkg -s nvidia-l4t-core | awk -F': ' '/^Version:/{print $2}'
  elif [[ -r /etc/nv_tegra_release ]]; then
    sed -nE 's/^# R([0-9]+).*/\1/p' /etc/nv_tegra_release
  fi
}
get_cuda_version() {
  if command -v $NVCC >/dev/null 2>&1; then
    $NVCC --version | awk -F'release ' '/release/{print $2}' | awk -F',' '{print $1}'
    return
  fi
  if [[ -f /usr/local/cuda/version.json ]]; then
    grep -oE '"cuda":\s*"[^"]+"' /usr/local/cuda/version.json | sed -E 's/.*"cuda":\s*"([^"]+)".*/\1/'
    return
  fi
  if [[ -f /usr/local/cuda/version.txt ]]; then
    awk '{print $NF}' /usr/local/cuda/version.txt
    return
  fi
}

L4T_VER="$(get_jetpack_version || true)"
CUDA_VER="$(get_cuda_version || true)"
CUDA_MM="$(printf "%s" "${CUDA_VER:-}" | awk -F. '{print $1"."$2}')"

log "Detected L4T/JetPack package version: ${L4T_VER:-unknown}"
log "Detected CUDA version: ${CUDA_VER:-unknown}"

# ------------------ Load known wheel mappings ------------------------
KNOWN_FILE="./known_wheels.sh"
declare -a WHEELS_KNOWN=()

if [[ -f "$KNOWN_FILE" ]]; then
  log "Loading wheel mappings from $KNOWN_FILE"
  # shellcheck disable=SC1090
  source "$KNOWN_FILE"
  # Map CUDA x.y -> KNOWN_WHEELS_x_y variable contents
  var_name="KNOWN_WHEELS_${CUDA_MM//./_}"
  if [[ -n "${!var_name:-}" ]]; then
    # Split the newline-separated string into array
    mapfile -t WHEELS_KNOWN < <(printf "%s\n" "${!var_name}" | sed '/^\s*$/d')
    log "Found ${#WHEELS_KNOWN[@]} predefined wheels for CUDA ${CUDA_MM}."
  else
    warn "No predefined wheels for CUDA ${CUDA_MM}."
  fi
else
  warn "known_wheels.sh not found; no predefined wheel mappings will be used."
fi

# ---------------- CUDA keyring + libcusparselt -----------------------
log "Installing NVIDIA CUDA keyring and libcusparselt…"
CUDA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/arm64/cuda-keyring_1.1-1_all.deb"
CUDA_KEYRING_DEB="cuda-keyring_1.1-1_all.deb"

sudo apt-get update -y
[[ -f "$CUDA_KEYRING_DEB" ]] || wget -q "$CUDA_KEYRING_URL" -O "$CUDA_KEYRING_DEB"

if ! dpkg -s cuda-keyring >/dev/null 2>&1; then
  sudo dpkg -i "$CUDA_KEYRING_DEB"
  sudo apt-get update -y
else
  log "cuda-keyring already installed; skipping dpkg -i"
fi

sudo apt-get install -y --no-install-recommends libcusparselt0 libcusparselt-dev

# ---------------------- uv + Python + venv ---------------------------
if ! command -v uv >/dev/null 2>&1; then
  log "Installing uv…"
  curl -fsSL https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

log "Ensuring Python ${PYTHON_VERSION} is available via uv…"
uv python install "${PYTHON_VERSION}"

if [[ ! -d "${VENV_DIR}" ]]; then
  log "Creating venv at ${VENV_DIR} (with --system-site-packages)…"
  uv venv --python "${PYTHON_VERSION}" --system-site-packages "${VENV_DIR}"
else
  log "Found existing venv at ${VENV_DIR}; reusing."
fi
PY_BIN="${VENV_DIR}/bin/python"

# ------------------ Download + verify known wheels -------------------
mkdir -p "${WHEELS_DIR}"
declare -a LOCAL_WHEELS=()

if (( ${#WHEELS_KNOWN[@]} )); then
  log "Fetching and verifying JetPack/CUDA-matched wheels for CUDA ${CUDA_MM}…"
  for url in "${WHEELS_KNOWN[@]}"; do
    file_url="${url%%#*}"
    file_name=$(basename "${file_url}")
    hash_part="${url#*#sha256=}"
    
    if [[ -z "$hash_part" || "$hash_part" == "$url" ]]; then
      warn "Skipping ${file_name}: no SHA256 checksum found in URL."
      continue
    fi

    file_path="${WHEELS_DIR}/${file_name}"

    if [[ ! -f "$file_path" ]]; then
      log "Downloading ${file_name}…"
      wget -q --show-progress "${file_url}" -O "${file_path}"
    else
      log "Found ${file_name}; skipping download."
    fi

    log "Verifying SHA256 for ${file_name}..."
    if ! printf "%s  %s\n" "${hash_part}" "${file_path}" | sha256sum --check --status; then
      die "SHA256 checksum mismatch for ${file_name}!"
    fi
    log "Verification successful for ${file_name}."
    LOCAL_WHEELS+=( "$file_path" )
  done
fi

# Include any user-provided wheels already in WHEELS_DIR
shopt -s nullglob
for w in "${WHEELS_DIR}"/*.whl; do
  [[ " ${LOCAL_WHEELS[*]} " == *" ${w} "* ]] || LOCAL_WHEELS+=( "$w" )
done
shopt -u nullglob

# ------------------- Install wheels via uv pip -----------------------
if (( ${#LOCAL_WHEELS[@]} )); then
  log "Installing ${#LOCAL_WHEELS[@]} local wheels via uv pip (no deps)…"
  uv pip install --python "${PY_BIN}" --no-deps "${LOCAL_WHEELS[@]}"
else
  log "No local wheels found; proceeding with PyPI-only installs."
fi

# --------------- Install remaining deps from indexes -----------------
log "Installing remaining packages with uv pip…"
PIP_ARGS=( --python "${PY_BIN}" )
[[ -n "${EXTRA_INDEX_URL}" ]] && PIP_ARGS+=( --extra-index-url "${EXTRA_INDEX_URL}" )

if [[ -n "${REQ_FILE}" && -f "${REQ_FILE}" ]]; then
  uv pip install "${PIP_ARGS[@]}" -r "${REQ_FILE}"
fi
if (( ${#INSTALL_PACKAGES[@]} )); then
  uv pip install "${PIP_ARGS[@]}" "${INSTALL_PACKAGES[@]}"
fi

"${PY_BIN}" -V
uv pip list --python "${PY_BIN}" | sed -n '1,80p'

log "Environment ready at ${VENV_DIR}"
echo
echo "To use it interactively later:"
echo "  source '${VENV_DIR}/bin/activate'"
echo
echo "You can verify the Yolo installation by running:"
echo "    yolo version"
echo