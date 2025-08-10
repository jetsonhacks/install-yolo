# known_wheels.sh — JetPack/CUDA → wheel URL mappings
# Store each CUDA major.minor version's wheels as a newline-separated string.
# The installer will split them safely.

# CUDA 12.6 (JetPack 6.2) — cp310 aarch64 examples
KNOWN_WHEELS_12_6=$(cat <<'EOF'
https://pypi.jetson-ai-lab.io/jp6/cu126/+f/62a/1beee9f2f1470/torch-2.8.0-cp310-cp310-linux_aarch64.whl#sha256=62a1beee9f2f147076a974d2942c90060c12771c94740830327cae705b2595fc
https://pypi.jetson-ai-lab.io/jp6/cu126/+f/907/c4c1933789645/torchvision-0.23.0-cp310-cp310-linux_aarch64.whl#sha256=907c4c1933789645ebb20dd9181d40f8647978e6bd30086ae7b01febb937d2d1
https://pypi.jetson-ai-lab.io/jp6/cu126/+f/81a/775c8af36ac85/torchaudio-2.8.0-cp310-cp310-linux_aarch64.whl#sha256=81a775c8af36ac859fb3f4a1b2f662d5fcf284a835b6bb4ed8d0827a6aa9c0b7
https://pypi.jetson-ai-lab.io/jp6/cu126/+f/4eb/e6a8902dc7708/onnxruntime_gpu-1.23.0-cp310-cp310-linux_aarch64.whl#sha256=4ebe6a8902dc7708434b2e1541b3fe629ebf434e16ab5537d1d6a622b42c622b
EOF
)

# CUDA 12.4 (JetPack 6.0 / 6.1) — add your URLs below
KNOWN_WHEELS_12_4=$(cat <<'EOF'
# 
# https://example.com/torch-...cp310-linux_aarch64.whl#sha256=...
# https://example.com/torchvision-...cp310-linux_aarch64.whl#sha256=...
# https://example.com/torchaudio-...cp310-linux_aarch64.whl#sha256=...
# https://example.com/onnxruntime_gpu-...cp310-linux_aarch64.whl#sha256=...
EOF
)

# CUDA 11.8 (JetPack 5.x) — add your URLs below
KNOWN_WHEELS_11_8=$(cat <<'EOF'
# https://example.com/torch-...cp38/39/310-linux_aarch64.whl#sha256=...
# ...
EOF
)
