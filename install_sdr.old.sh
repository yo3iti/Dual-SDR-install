#!/bin/bash
# install_sdr.sh - Install SDR dependencies on Raspberry Pi

# variabile
BASE="/tmp"

# check and delete
FOLDERS=("SoapySDR" "SoapySDRPlay3" "libiio" "libad9361-iio")

set -e

echo "===== SDR Interface Installation ====="

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install system dependencies
echo "Installing system packages..."
sudo apt-get install -y \
    python3-pip \
    python3-dev \
    build-essential \
    libaio-dev \
    cmake \
    git \
    libusb-1.0-0-dev \
    pkg-config \
    libiio-dev \
    libad9361-dev \
    libiio-utils \
    libxml2-dev \
    bison \
    flex \
    libavahi-client-dev

# checking and deleting if folders exist
for DIR_NAME in "${FOLDERS[@]}"; do
    # Concatenare: combinăm calea de bază cu numele folderului
    FULL_PATH="${BASE}/${DIR_NAME}"

    if [ -d "$FULL_PATH" ]; then
        echo "Deleting: $FULL_PATH"
        rm -rf "$FULL_PATH"
    else
        echo "Did not find: $FULL_PATH"
    fi
done

# Install SoapySDR
echo "Installing SoapySDR..."
cd "$BASE"
git clone https://github.com/pothosware/SoapySDR.git
cd SoapySDR
mkdir -p build && cd build
cmake ..
make -j4
sudo make install
sudo ldconfig

# Install SoapySDRPlay3
echo "Installing SDRPlay support..."
# Download SDRPlay API from https://www.sdrplay.com/downloads/
# Install it, then:
cd "$BASE"
git clone https://github.com/pothosware/SoapySDRPlay3.git
cd SoapySDRPlay3
mkdir -p build && cd build
cmake ..
make -j4
sudo make install

# Install PlutoSDR support
echo "Installing PlutoSDR support..."
cd "$BASE"
git clone https://github.com/analogdevicesinc/libiio.git
cd libiio
mkdir -p build && cd build
cmake ..
make -j4
sudo make install

cd "$BASE"
git clone https://github.com/analogdevicesinc/libad9361-iio.git
cd libad9361-iio
mkdir -p build && cd build
cmake ..
make -j4
sudo make install

sudo ldconfig

# Install Python packages
echo "Installing Python packages..."
pip3 install --upgrade pip
pip3 install -r requirements.txt

echo ""
echo "===== Installation Complete ====="
echo ""
echo "Test SDRPlay: SoapySDRUtil --probe=driver=sdrplay"
echo "Test PlutoSDR: iio_info -n <pluto-ip>"