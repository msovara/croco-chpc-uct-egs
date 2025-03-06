# croco-lengau-uct
This repository provides scripts, configuration files, and documentation for running CROCO on Lengau using Intel MPI, supporting ocean modelling research at UCT.


The main dependencies are:
- MPI (MPICH)
- zlib
- HDF5 (parallel enabled)
- netCDF-C (parallel enabled)
- netCDF-Fortran

## This script handles downloading and extracting all dependencies and CROCO source code.
```bash
#!/bin/bash
# CROCO Dependency Download Script
# Author: Mthetho Vuyo Sovara
# Date: 2025-03-05
# Description: This script downloads zlib, curl, HDF5, netCDF-C, netCDF-Fortran,
#              and CROCO source code. It skips downloads if files already exist.

# Set error handling
set -e  # Exit on error
set -u  # Exit on undefined variables
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

# Define installation directories
INSTALL_DIR="/mnt/lustre/users/msovara/SoftwareBuilds/CROCO/install"
SRC_DIR="${INSTALL_DIR}/src"

# Create directories
mkdir -p "${INSTALL_DIR}" "${SRC_DIR}"
cd "${SRC_DIR}"

# Function to download and extract a tarball
download_and_extract() {
    local url="$1"
    local expected_dir="$2"  # Explicitly specify the expected directory name
    local tarball=$(basename "${url}")
    local current_dir=$(pwd)
    
    # Skip download if tarball already exists
    if [ -f "${tarball}" ]; then
        echo "Tarball ${tarball} already exists. Skipping download."
    else
        echo "Downloading ${tarball}..."
        if ! wget --no-check-certificate "${url}"; then
            echo "ERROR: Failed to download ${url}"
            return 1
        fi
    fi
    
    # Skip extraction if directory already exists
    if [ -d "${expected_dir}" ]; then
        echo "Directory ${expected_dir} already exists. Skipping extraction."
    else
        echo "Extracting ${tarball}..."
        if ! tar -xzf "${tarball}"; then
            echo "ERROR: Failed to extract ${tarball}"
            return 1
        fi
        
        # Check if the extracted directory matches the expected directory
        if [ ! -d "${expected_dir}" ]; then
            echo "WARNING: Expected directory ${expected_dir} not found after extraction"
            # Try to find the actual directory that was created
            local extracted_dir=$(find . -type d -maxdepth 1 -newer "${tarball}" | grep -v "^\.$" | head -1)
            if [ -n "${extracted_dir}" ]; then
                echo "Found extracted directory: ${extracted_dir}"
                mv "${extracted_dir}" "${expected_dir}"
            else
                echo "ERROR: Could not determine extracted directory"
                return 1
            fi
        fi
    fi
    
    echo "Entering ${expected_dir}..."
    cd "${expected_dir}"
    return 0
}

# 1. Download zlib
echo "Downloading zlib..."
ZLIB_VERSION="1.3.1"
download_and_extract "https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz" "zlib-${ZLIB_VERSION}"
cd "${SRC_DIR}"

# 2. Download curl
echo "Downloading curl..."
CURL_VERSION="7.88.1"
download_and_extract "https://curl.se/download/curl-${CURL_VERSION}.tar.gz" "curl-${CURL_VERSION}"
cd "${SRC_DIR}"

# 3. Download HDF5
echo "Downloading HDF5..."
HDF5_VERSION="1.14.0"
download_and_extract "https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.14/hdf5-${HDF5_VERSION}/src/hdf5-${HDF5_VERSION}.tar.gz" "hdf5-${HDF5_VERSION}"
cd "${SRC_DIR}"

# 4. Download netCDF-C
echo "Downloading netCDF-C..."
NETCDF_C_VERSION="4.9.2"
download_and_extract "https://github.com/Unidata/netcdf-c/archive/refs/tags/v${NETCDF_C_VERSION}.tar.gz" "netcdf-c-${NETCDF_C_VERSION}"
cd "${SRC_DIR}"

# 5. Download netCDF-Fortran
echo "Downloading netCDF-Fortran..."
NETCDF_FORTRAN_VERSION="4.6.1"
download_and_extract "https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v${NETCDF_FORTRAN_VERSION}.tar.gz" "netcdf-fortran-${NETCDF_FORTRAN_VERSION}"
cd "${SRC_DIR}"

# 6. Download CROCO into the src directory
echo "Downloading CROCO..."
CROCO_DIR="${SRC_DIR}/CROCO"
if [ -d "${CROCO_DIR}" ]; then
    echo "Removing existing CROCO directory..."
    rm -rf "${CROCO_DIR}"
fi
echo "Cloning CROCO repository (branch v2.0.1)..."
if ! git clone --branch v2.0.1 https://gitlab.inria.fr/croco-ocean/croco.git "${CROCO_DIR}"; then
    echo "ERROR: Failed to clone CROCO repository"
    exit 1
fi

echo "Download and extraction complete. Files are in ${SRC_DIR}."

```
