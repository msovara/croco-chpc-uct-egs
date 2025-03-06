# croco-lengau-uct
This repository provides scripts, configuration files, and documentation for running CROCO on Lengau using Intel MPI, supporting ocean modelling research at UCT.


The main dependencies are:
- MPI (MPICH)
- zlib
- HDF5 (parallel enabled)
- netCDF-C (parallel enabled)
- netCDF-Fortran

## Script 1: ```download.sh```
This script handles downloading and extracting all dependencies and CROCO source code.
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
___

## Script 2: ```build.sh```
This script handles building and installing all dependencies and CROCO.
```bash
#!/bin/bash
# CROCO Dependency and CROCO Build Script
# Author: Mthetho Vuyo Sovara
# Date: 2025-03-05
# Description: This script builds and installs zlib, curl, HDF5, netCDF-C, netCDF-Fortran,
#              and CROCO using Intel compilers and MPI.

# Set error handling
set -e  # Exit on error
set -u  # Exit on undefined variables
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

# Define installation directories
INSTALL_DIR="/mnt/lustre/users/msovara/SoftwareBuilds/CROCO/install"
CROCO_DIR="/mnt/lustre/users/msovara/SoftwareBuilds/CROCO"
SRC_DIR="${INSTALL_DIR}/src"
LOG_DIR="${INSTALL_DIR}/logs"

# Create directories
mkdir -p "${INSTALL_DIR}" "${LOG_DIR}"
cd "${SRC_DIR}"

# Load Intel compilers and MPI
echo "Loading Intel compiler modules..."
module purge
if ! module load chpc/parallel_studio_xe/18.0.2/2018.2.046; then
    echo "ERROR: Failed to load Intel compiler module. Exiting."
    exit 1
fi

MPI_VARS_PATH="/apps/compilers/intel/parallel_studio_xe_2018_update2/compilers_and_libraries/linux/mpi/bin64/mpivars.sh"
if [ ! -f "${MPI_VARS_PATH}" ]; then
    echo "ERROR: MPI environment file not found: ${MPI_VARS_PATH}"
    exit 1
fi

# Source MPI environment with temporary disabling of strict variable checking
(
    set +u  # Temporarily disable checking for unbound variables
    source "${MPI_VARS_PATH}"
)

# Set environment variables
export CC=icc
export CXX=icpc
export FC=ifort
export MPICC=mpiicc
export MPICXX=mpiicpc
export MPIF90=mpiifort
export CFLAGS="-O3 -xHost"
export FCFLAGS="-O3 -xHost"
export PATH="${INSTALL_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${INSTALL_DIR}/lib:${INSTALL_DIR}/lib64:${LD_LIBRARY_PATH:-}"

# Initialize PKG_CONFIG_PATH if not already set
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}"

# Verify compiler setup
echo "Checking compiler versions:"
if ! "${CC}" --version | grep -i intel; then
    echo "WARNING: CC (${CC}) does not appear to be an Intel compiler"
fi

if ! "${FC}" --version | grep -i intel; then
    echo "WARNING: FC (${FC}) does not appear to be an Intel compiler"
fi

if ! "${MPICC}" --version | grep -i intel; then
    echo "WARNING: MPICC (${MPICC}) does not appear to be an Intel MPI wrapper"
fi

# Function to clean old builds
clean_old_builds() {
    local dir="$1"
    if [ -d "${dir}" ]; then
        echo "Cleaning old build directory: ${dir}"
        rm -rf "${dir}"
    fi
}

# Function to check build success and record to log
check_build() {
    local component="$1"
    local status=$?
    if [ ${status} -ne 0 ]; then
        echo "ERROR: ${component} build failed with status ${status}"
        exit ${status}
    fi
    echo "$(date): ${component} build completed successfully" >> "${LOG_DIR}/build_log.txt"
}

# 1. Build zlib
echo "Building zlib..."
cd "zlib-1.3.1"
./configure --prefix="${INSTALL_DIR}"
make -j$(nproc)
make install
check_build "zlib"
cd "${SRC_DIR}"

# 2. Build curl
echo "Building curl..."
cd "curl-7.88.1"
./configure --prefix="${INSTALL_DIR}" \
    --with-zlib="${INSTALL_DIR}" \
    --with-ssl=/usr \
    --enable-ipv6 \
    --enable-unix-sockets
make -j$(nproc)
make install
check_build "curl"
cd "${SRC_DIR}"

# 3. Build HDF5
echo "Building HDF5..."
cd "hdf5-1.14.0"
./configure --prefix="${INSTALL_DIR}" \
    --enable-parallel \
    --enable-shared \
    --enable-fortran \
    CC="${MPICC}" \
    FC="${MPIF90}" \
    CFLAGS="${CFLAGS}" \
    FCFLAGS="${FCFLAGS}"
make -j$(nproc)
make install
check_build "HDF5"
cd "${SRC_DIR}"

# 4. Build netCDF-C
echo "Building netCDF-C..."
cd "netcdf-c-4.9.2"
./configure --prefix="${INSTALL_DIR}" \
    --enable-parallel-tests \
    --enable-shared \
    --with-hdf5="${INSTALL_DIR}" \
    CC="${MPICC}" \
    CPPFLAGS="-I${INSTALL_DIR}/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib" \
    CFLAGS="${CFLAGS}"
make -j$(nproc)
make install
check_build "netCDF-C"
cd "${SRC_DIR}"

# 5. Build netCDF-Fortran
echo "Building netCDF-Fortran..."
cd "netcdf-fortran-4.6.1"
./configure --prefix="${INSTALL_DIR}" \
    --enable-shared \
    CC="${MPICC}" \
    FC="${MPIF90}" \
    CPPFLAGS="-I${INSTALL_DIR}/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib" \
    CFLAGS="${CFLAGS}" \
    FCFLAGS="${FCFLAGS}"
make -j$(nproc)
make install
check_build "netCDF-Fortran"
cd "${SRC_DIR}"

# 6. Build CROCO
echo "Building CROCO..."
cd "${CROCO_DIR}"
clean_old_builds "build"
mkdir -p build
cd build

# Configure CROCO
echo "Configuring CROCO..."
cmake .. \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DNETCDF_DIR="${INSTALL_DIR}" \
    -DHDF5_DIR="${INSTALL_DIR}" \
    -DCMAKE_C_COMPILER="${MPICC}" \
    -DCMAKE_Fortran_COMPILER="${MPIF90}" \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_Fortran_FLAGS="${FCFLAGS}"
make -j$(nproc)
make install
check_build "CROCO"

echo "Build completed successfully!"
```
