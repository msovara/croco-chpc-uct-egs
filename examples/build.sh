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
    set -u  # Re-enable checking for unbound variables
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

# Debugging: Print FC and MPIF90
echo "FC is set to: ${FC}"
echo "MPIF90 is set to: ${MPIF90}"

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

# Patch easy.c for Intel 18.0.2 compiler compatibility
echo "Patching easy.c for Intel 18.0.2 compiler compatibility..."
sed -i 's/static curl_simple_lock s_lock = CURL_SIMPLE_LOCK_INIT;/static atomic_int s_lock = ATOMIC_VAR_INIT(0);/' "${SRC_DIR}/curl-7.88.1/lib/easy.c"

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

# Check if the build directory exists
if [ ! -d "${CROCO_DIR}/install/src/CROCO/OCEAN" ]; then
    echo "ERROR: CROCO build directory not found: ${CROCO_DIR}/install/src/CROCO/OCEAN"
    exit 1
fi

# Enter the build directory
cd "${CROCO_DIR}/install/src/CROCO/OCEAN" || {
    echo "ERROR: Failed to enter CROCO build directory"
    exit 1
}

# Confirm cleanup
read -p "Are you sure you want to clean the CROCO build directory? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup aborted."
    exit 1
fi

# Clean previous build
echo "Cleaning previous CROCO build..."
rm -f *.o *.f90 *.mod *.a croco

# Modify jobcomp to use Intel compilers
echo "Modifying jobcomp script..."
sed -i "s|^FC=.*$|FC=ifort|" jobcomp
sed -i "s|^CC=.*$|CC=${MPICC}|" jobcomp
sed -i "s|^FFLAGS=.*$|FFLAGS=\"${FCFLAGS} -I${INSTALL_DIR}/include\"|" jobcomp
sed -i "s|^LDFLAGS=.*$|LDFLAGS=\"-L${INSTALL_DIR}/lib -lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lz\"|" jobcomp

# Debugging: Print modified jobcomp
echo "Modified jobcomp script:"
cat jobcomp

# Run the compilation script
echo "Compiling CROCO with jobcomp..."
./jobcomp > "${LOG_DIR}/croco_build.log" 2>&1 || {
    echo "ERROR: CROCO compilation failed. See ${LOG_DIR}/croco_build.log for details."
    exit 1
}

# Check if compilation was successful
if [ -f "croco" ]; then
    echo "CROCO built successfully"
    # Install to destination
    mkdir -p "${INSTALL_DIR}/bin"
    cp croco "${INSTALL_DIR}/bin/"
    check_build "CROCO"
else
    echo "ERROR: CROCO executable not found after compilation"
    exit 1
fi

echo "Build completed successfully!"
