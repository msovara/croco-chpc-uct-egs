# croco-lengau-uct
This repository provides scripts, configuration files, and documentation for running CROCO on Lengau using Intel MPI, supporting ocean modelling research at UCT.

# Author: Mthetho Vuyo Sovara
## Last Update: 11 March 2025
## Developer Notes


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
# Date: 2025-03-03
# Date: 2025-03-11
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
=======

# Define installation directories
INSTALL_DIR=/mnt/lustre/users/msovara/SoftwareBuilds/CROCO/croco_deps
CROCO_DIR=/mnt/lustre/users/msovara/SoftwareBuilds/CROCO/croco
mkdir -p $INSTALL_DIR/src
mkdir -p $CROCO_DIR
cd $INSTALL_DIR/src

# Load required modules
module purge
module load gcc/9.2.0
module load chpc/compmech/mpich/4.2.2/oneapi2023-ssh
module load chpc/cmake/3.21.4/intel_2021u1

# Set environment variables
export CC=gcc
export CXX=g++
export FC=gfortran
export MPICC=/home/apps/chpc/compmech/mpich-4.2.2-oneapi2023/bin/mpicc
export MPICXX=/home/apps/chpc/compmech/mpich-4.2.2-oneapi2023/bin/mpicxx
export MPIF90=/home/apps/chpc/compmech/mpich-4.2.2-oneapi2023/bin/mpif90
export PATH=$INSTALL_DIR/bin:$PATH
export LD_LIBRARY_PATH=$INSTALL_DIR/lib:$INSTALL_DIR/lib64:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=$INSTALL_DIR/lib/pkgconfig:$PKG_CONFIG_PATH

# 1. Install zlib
echo "Installing zlib..."
wget https://zlib.net/zlib-1.3.tar.gz
tar xzf zlib-1.3.tar.gz
cd zlib-1.3
./configure --prefix=$INSTALL_DIR
make -j8
make install
cd ..

# 2. Install HDF5
echo "Installing HDF5..."
wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.14/hdf5-1.14.0/src/hdf5-1.14.0.tar.gz
tar xzf hdf5-1.14.0.tar.gz
cd hdf5-1.14.0
./configure --prefix=$INSTALL_DIR \
    --enable-parallel \
    --enable-shared \
    --enable-fortran \
    CC=$MPICC \
    FC=$MPIF90 \
    CFLAGS="-O3 -fPIC"
make -j8
make install
cd ..

# 3. Install netCDF-C
echo "Installing netCDF-C..."
wget https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.9.2.tar.gz -O netcdf-c-4.9.2.tar.gz
tar xzf netcdf-c-4.9.2.tar.gz
cd netcdf-c-4.9.2
./configure --prefix=$INSTALL_DIR \
    --enable-parallel-tests \
    --enable-shared \
    CC=$MPICC \
    CPPFLAGS="-I$INSTALL_DIR/include" \
    LDFLAGS="-L$INSTALL_DIR/lib" \
    CFLAGS="-O3 -fPIC"
make -j8
make install
cd ..

# 4. Install netCDF-Fortran
echo "Installing netCDF-Fortran..."
wget https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.1.tar.gz -O netcdf-fortran-4.6.1.tar.gz
tar xzf netcdf-fortran-4.6.1.tar.gz
cd netcdf-fortran-4.6.1
./configure --prefix=$INSTALL_DIR \
    --enable-shared \
    CC=$MPICC \
    FC=$MPIF90 \
    CPPFLAGS="-I$INSTALL_DIR/include" \
    LDFLAGS="-L$INSTALL_DIR/lib" \
    CFLAGS="-O3 -fPIC" \
    FCFLAGS="-O3 -fPIC"
make -j8
make install
cd ..

# Create activation script
cat << 'EOF' > $INSTALL_DIR/activate_croco_env.sh
#!/bin/bash
module purge
module load gcc/9.2.0
module load chpc/compmech/mpich/4.2.2/oneapi2023-ssh
module load chpc/cmake/3.21.4/intel_2021u1

export INSTALL_DIR=$HOME/croco_deps
export CROCO_DIR=$HOME/croco
export PATH=$INSTALL_DIR/bin:$PATH
export LD_LIBRARY_PATH=$INSTALL_DIR/lib:$INSTALL_DIR/lib64:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=$INSTALL_DIR/lib/pkgconfig:$PKG_CONFIG_PATH

# NetCDF environment variables
export NETCDF=$INSTALL_DIR
export NETCDF_ROOT=$INSTALL_DIR
export NETCDF_INCLUDE=$INSTALL_DIR/include
export NETCDF_LIB=$INSTALL_DIR/lib
export NETCDF_CONFIG=$INSTALL_DIR/bin/nc-config
export NETCDF_FORTRAN_ROOT=$INSTALL_DIR

# HDF5 environment variables
export HDF5_ROOT=$INSTALL_DIR
export HDF5_INCLUDE=$INSTALL_DIR/include
export HDF5_LIB=$INSTALL_DIR/lib
EOF

chmod +x $INSTALL_DIR/activate_croco_env.sh

# Create README
cat << 'EOF' > $INSTALL_DIR/README.md
# CROCO Dependencies Installation

This directory contains all the dependencies required for CROCO:
- zlib 1.3
- HDF5 1.14.0 (parallel enabled)
- netCDF-C 4.9.2 (parallel enabled)
- netCDF-Fortran 4.6.1

To use these dependencies:
1. Source the activation script:
   ```
   source $HOME/croco_deps/activate_croco_env.sh
   ```

2. When building CROCO, make sure to point to these installations:
   ```
   cmake .. \
       -DNETCDF_ROOT=$INSTALL_DIR \
       -DHDF5_ROOT=$INSTALL_DIR \
       ...
   ```
EOF

echo "
Dependencies installation complete!

Next steps:
1. Source the environment:
   source $INSTALL_DIR/activate_croco_env.sh

2. Install CROCO using these dependencies.

See $INSTALL_DIR/README.md for more details.
"
```
## To use these dependencies:
### 1. Source the activation script:
   ```bash
   source $INSTALL_DIR/activate_croco_env.sh
```
Verify the environment variables are set correctly:
```bash
echo $NETCDF
echo $HDF5_ROOT

```
