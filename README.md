# install-yolo
## Jetson YOLO Wheel Installer
This repository contains scripts to simplify the installation of Ultralytics YOLO on a NVIDIA Jetson device. Currently this only works for JetPack 6.2.X. The primary script, install_yolo.sh, automates the process of detecting the JetPack/CUDA version, downloading verified PyTorch and related wheels, and setting up a Python virtual environment.

## Scripts
install_yolo.sh: The main installation script. It handles environment setup, CUDA keyring installation, and dependency management. It's designed to be a one-stop solution for getting a YOLO environment running.

known_wheels.sh: A data file that stores mappings of CUDA versions (e.g., CUDA 12.6) to the corresponding URLs for pre-built Python wheels for torch, torchvision, torchaudio, and onnxruntime. This allows the installer to use a verified, offline-capable list of dependencies.

## Features
**JetPack/CUDA Detection**: Automatically detects the installed JetPack and CUDA versions on the system.

**Verified Wheels**: Downloads pre-built wheels for torch, torchvision, torchaudio, and onnxruntime from a trusted source, with SHA256 checksum verification to ensure file integrity.

**Virtual Environment Setup**: Creates a dedicated Python virtual environment using uv to manage dependencies, keeping the system's Python installation clean.

**Dependency Installation**: Installs core packages like ultralytics, onnx, and numpy into the new virtual environment.

## How to Use
Clone the Repository:

``` Bash
git clone https://github.com/jetsonhacks/install-yolo
cd install-yolo
```

Run the Installer:

``` Bash
./install_yolo.sh
```

The script will automatically handle the installation process. Upon completion, it will provide instructions on how to activate the new virtual environment.

## Configuration
You can customize the installation by setting environment variables before running the script:

**PYTHON_VERSION**: Specifies the target Python version (e.g., 3.10). Defaults to 3.10.

**VENV_DIR**: The path to the virtual environment directory. Defaults to ~/yolo-venv.

**WHEELS_DIR**: The directory to download wheel files into. Defaults to ./whls.

**EXTRA_INDEX_URL**: An optional extra PyPI index URL to use for additional packages.

**REQ_FILE**: An optional path to a requirements.txt file to install additional dependencies.

Example with custom settings:

``` Bash
PYTHON_VERSION="3.9" VENV_DIR="/opt/yolo-env" ./install_yolo.sh
```

## Release Notes
### August, 2025
* Initial Release
* Tested on Jetson Orin Nano Super, JetPack 6.2.1
