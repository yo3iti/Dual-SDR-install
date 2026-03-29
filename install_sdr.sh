#!/bin/bash
# install_sdr_fixed.sh - Fixed installation script for Raspberry Pi

set -e

echo "===== SDR Interface Installation (Fixed) ====="

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "WARNING: Don't run as root during build. Run specific commands with sudo."
    echo "Usage: ./install_sdr.sh"
    exit 1
fi

# ====================================================
# ============= STEP 1: Update system ================
# ====================================================

# Update system
echo "[1/10] Updating system..."
sudo apt-get update
sudo apt-get upgrade -y

# ====================================================
# ========STEP 2: Install System Dependencies ========
# ====================================================

# Install system dependencies
echo "[2/10] Installing system packages..."
sudo apt-get install -y \
    python3-pip \
    python3-dev \
    build-essential \
    libaio-dev \
    libzstd-dev \
    libiio-dev \
    libad9361-dev \
    libiio-utils \
    cmake \
    git \
    libusb-1.0-0-dev \
    pkg-config \
    libxml2-dev \
    bison \
    flex \
    libavahi-client-dev \
    libavahi-common-dev \
    libserialport-dev \
    libcdk5-dev

# Create build directory
BUILD_DIR="$HOME/programare/sdr_build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ====================================================
# ======== STEP 3: Create virtual environment ========
# ====================================================

# Create virtual environment
echo "[3/10] Creating virtual environment..."
VENV_PATH="$HOME/programare/sdr_build/venv"

if [ -d "$VENV_PATH" ]; then
    echo "Virtual environment already exists at $VENV_PATH"
    read -p "Remove and recreate? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$VENV_PATH"
    else
        echo "Using existing virtual environment"
    fi
fi

python3 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

# Upgrade pip in venv
pip install --upgrade pip wheel setuptools

# ====================================================
# ========= STEP 4: Install Python Packages ==========
# ====================================================

# Install Python packages
echo "[4/10] Installing Python packages in virtual environment..."
pip install numpy scipy matplotlib h5py pyyaml tqdm

# Install pyadi-iio for PlutoSDR
pip install pyadi-iio

# Install SoapySDR Python bindings
# cd "$BUILD_DIR/SoapySDR"
# cd python
# pip3 install .

# ====================================================
# ===== STEP 5: Install libiio FIRST (critical!) =====
# ====================================================

echo "[5/10] Installing libiio..."

# Remove conflicting packages
echo "Removing old libiio packages..."
sudo apt-get remove -y libiio* python3-libiio || true

# TODO - remove libiio.so.* libraries
# sudo rm -rf /usr/lib/aarch64-linux-gnu/libiio.so*
# sudo rm -rf /usr/local/lib/libiio.so*
# /usr/lib/aarch64-linux-gnu/ -> nu trebuie să fie nimic aici !!!!

if [ -d "libiio" ]; then
    rm -rf libiio
fi

git clone https://github.com/analogdevicesinc/libiio.git
cd libiio
git checkout v0.26
# Or latest:
#git checkout $(git describe --tags --abbrev=0)

mkdir -p build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DWITH_SERIAL_BACKEND=ON \
    -DENABLE_IPV6=ON

make -j$(nproc)
sudo make install
sudo ldconfig

# Verify libiio installation
if ! pkg-config --exists libiio; then
    echo "ERROR: libiio pkg-config not found"
    exit 1
fi

echo "libiio installed successfully"
cd "$BUILD_DIR"

# =========================================================
# ===== STEP 6: Install libad9361 with proper linking =====
# =========================================================

echo "[6/10] Installing libad9361..."

if [ -d "libad9361-iio" ]; then
    rm -rf libad9361-iio
fi

git clone https://github.com/analogdevicesinc/libad9361-iio.git
cd libad9361-iio

# Fix CMakeLists.txt to link libiio properly
cat > CMakeLists_fix.patch <<'EOF'
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -1,6 +1,9 @@
 cmake_minimum_required(VERSION 2.8.7)
 project(ad9361 C)
 
+# Find libiio
+find_package(PkgConfig REQUIRED)
+pkg_check_modules(LIBIIO REQUIRED libiio)
+
 set(LIBAD9361_VERSION_MAJOR 0)
 set(LIBAD9361_VERSION_MINOR 2)
 set(LIBAD9361_VERSION ${LIBAD9361_VERSION_MAJOR}.${LIBAD9361_VERSION_MINOR})
@@ -32,6 +35,8 @@ add_library(ad9361 SHARED ${LIBAD9361_SOURCES})
 set_target_properties(ad9361 PROPERTIES
 	VERSION ${LIBAD9361_VERSION}
 	SOVERSION ${LIBAD9361_VERSION_MAJOR}
+	LINK_FLAGS "${LIBIIO_LDFLAGS}"
+	COMPILE_FLAGS "${LIBIIO_CFLAGS}"
 )
 target_link_libraries(ad9361 LINK_PRIVATE ${LIBIIO_LIBRARIES})
 
EOF

# Apply patch if CMakeLists doesn't already link libiio
if ! grep -q "pkg_check_modules(LIBIIO" CMakeLists.txt; then
    patch -p1 < CMakeLists_fix.patch || true
fi

mkdir -p build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DLIBIIO_INCLUDEDIR=/usr/local/include \
    -DLIBIIO_LIBDIR=/usr/local/lib

make -j$(nproc)
sudo make install
sudo ldconfig

echo "libad9361 installed successfully"
cd "$BUILD_DIR"

# ====================================================
# =========== STEP 7: Install SoapySDR ===============
# ====================================================

echo "[7/10] Installing SoapySDR..."

if [ -d "SoapySDR" ]; then
    rm -rf SoapySDR
fi

git clone https://github.com/pothosware/SoapySDR.git
cd SoapySDR
git checkout soapy-sdr-0.8.1  # Stable version

mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc)
sudo make install
sudo ldconfig

echo "SoapySDR installed successfully"
cd "$BUILD_DIR"

# =============================================================
# ===== STEP 8: Install SDRPlay API (if you have SDRPlay) =====
# =============================================================

echo "[8/10] SDRPlay setup..."
echo "NOTE: SDRPlay requires manual API installation from https://www.sdrplay.com/downloads/"
echo "After installing SDRPlay API, install SoapySDRPlay3:"
echo ""

# ====================================================
# ========== STEP 9: Install SoapySDRPlay3 ===========
# ====================================================

echo "[9/10] SoapySDRPlay3 setup..."
read -p "Do you have SDRPlay API installed? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "SoapySDRPlay3" ]; then
        rm -rf SoapySDRPlay3
    fi
    
    git clone https://github.com/pothosware/SoapySDRPlay3.git
    cd SoapySDRPlay3
    mkdir -p build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    
    echo "SoapySDRPlay3 installed successfully"
else
    echo "Skipping SoapySDRPlay3 installation"
fi

# ====================================================
# =========== STEP 10: Final - testing ===============
# ====================================================

echo ""
echo "===== Installation Complete ====="
echo ""
echo "Installed components:"
echo "  - libiio (for PlutoSDR)"
echo "  - libad9361 (for PlutoSDR)"
echo "  - SoapySDR"
echo "  - Python packages"
echo ""
echo "Testing installations:"
echo ""

echo "[10/10] Testing..."
# Test libiio
echo "Testing libiio..."
if command -v iio_info &> /dev/null; then
    echo "✓ iio_info available"
    iio_info -V
else
    echo "✗ iio_info not found"
fi

# Test SoapySDR
echo ""
echo "Testing SoapySDR..."
if command -v SoapySDRUtil &> /dev/null; then
    echo "✓ SoapySDRUtil available"
    SoapySDRUtil --info
else
    echo "✗ SoapySDRUtil not found"
fi

echo "[5/5] Setting up activation script..."

# Create activation helper
# așa se creează un fișier
cat > "$HOME/programare/activate_sdr.sh" <<'EOF'
#!/bin/bash
# Activate SDR virtual environment

VENV_PATH="$HOME/sdr_venv"

if [ -d "$VENV_PATH" ]; then
    source "$VENV_PATH/bin/activate"
    echo "SDR virtual environment activated"
    echo "Python: $(which python3)"
    echo "To deactivate: type 'deactivate'"
else
    echo "ERROR: Virtual environment not found at $VENV_PATH"
    exit 1
fi
EOF

chmod +x "$HOME/programare/activate_sdr.sh"

echo ""
echo "===== Installation Complete ====="
echo ""
echo "Virtual environment created at: $VENV_PATH"
echo ""
echo "To use the SDR tools:"
echo "  source ~/activate_sdr.sh"
echo "  # OR"
echo "  source $VENV_PATH/bin/activate"
echo ""
echo "Then run your scripts:"
echo "  python3 record_dual.py --sdr pluto"
echo ""
echo "To deactivate:"
echo "  deactivate"
echo ""

# Test imports
echo "Testing Python packages in venv..."
python3 << 'PYEOF'
import sys
success = True

packages = {
    'numpy': 'NumPy',
    'scipy': 'SciPy',
    'matplotlib': 'Matplotlib',
    'h5py': 'HDF5',
    'yaml': 'PyYAML',
    'tqdm': 'TQDM',
    'adi': 'pyadi-iio (PlutoSDR)'
}

for module, name in packages.items():
    try:
        __import__(module)
        print(f"✓ {name}")
    except ImportError:
        print(f"✗ {name}")
        success = False

sys.exit(0 if success else 1)
PYEOF

echo ""
echo "Add this to your ~/.bashrc to auto-activate on login (optional):"
echo "  source $VENV_PATH/bin/activate"

echo ""
echo "Quick start:"
echo ""
echo "For PlutoSDR (USB):"
echo "  iio_info -u ip:192.168.2.1"
echo "  python3 -c 'import adi; sdr=adi.Pluto(\"ip:192.168.2.1\"); print(sdr)'"
echo ""
echo "For SDRPlay:"
echo "  SoapySDRUtil --probe=driver=sdrplay"
echo ""
echo "Clean up build files:"
echo "  rm -rf $BUILD_DIR"