🌊 CROCO-Lengau-UCT 🌊

This repository provides scripts, configuration files, and documentation for running CROCO on Lengau using Intel MPI, supporting ocean modelling research at UCT.
___
📅 Last Update: 11 March 2025 \
👨‍💻 Author: Mthetho Vuyo Sovara \
📝 Developer Notes 

The main dependencies are:

- MPI (Intel)
- zlib
- curl
- HDF5 (parallel enabled) 
- netCDF-C (parallel enabled) 
- netCDF-Fortran

### 🚀 Script 1: ```download.sh```
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

### 🛠️ Script 2: ```build.sh```
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
```
___
## 📋 User Notes

The CROCO model has been installed in the ```/home/apps/chpc/earth``` directory where applications on LENGAU are typically installed. To use CROCO, you must first load the CROCO module and Matlab (for pre-processing) into your shell environment:
```bash
module avail 2>&1 | grep -i croco
module load chpc/earth/croco/2.0.1
module load chpc/math/matlab/R2021a
```
___
## 🖥️ Example PBS Job Script for Running CROCO on Lengau

```bash
#!/bin/bash
#PBS -N croco_benguela
#PBS -l walltime=12:00:00
#PBS -l select=2:ncpus=24:mpiprocs=24
#PBS -q normal
#PBS -P CHPC22XXXXXXX
#PBS -m abe
#PBS -M your.email@example.com

# Change to the directory where the job was submitted from
cd $PBS_O_WORKDIR

# Load the CROCO module
module load chpc/earth/croco/2.0.1

# Print job information
echo "Running on host: $(hostname)"
echo "Running on nodes: $(cat $PBS_NODEFILE | sort | uniq | tr '\n' ' ')"
echo "Number of MPI processes: $PBS_NP"
echo "Start time: $(date)"

# Create a directory for output files
OUTDIR="output_$(date +%Y%m%d_%H%M%S)"
mkdir -p $OUTDIR

# Copy input files to work directory if needed
# cp /path/to/input/files/* .

# Run CROCO with MPI
mpirun -np $PBS_NP croco croco.in > $OUTDIR/croco.log 2>&1

# Post-processing (if needed)
# python /path/to/post_processing.py

# Copy results to storage location (if needed)
# cp -r $OUTDIR /mnt/lustre/users/msovara/CROCO_Results/

echo "End time: $(date)"
echo "Job completed"
```
___
### 🛠️ Job Variations:

#### 1. For a small test run:
```bash
#PBS -N croco_test
#PBS -l walltime=01:00:00
#PBS -l select=1:ncpus=24:mpiprocs=24
#PBS -q debug
```

#### 2. For a large production run:
```bash
#PBS -N croco_production
#PBS -l walltime=48:00:00
#PBS -l select=8:ncpus=24:mpiprocs=24
#PBS -q large
```

#### 3. For a high-resolution run with OpenMP (Not applicable here): 
```bash
#PBS -N croco_highres
#PBS -l walltime=24:00:00
#PBS -l select=4:ncpus=24:mpiprocs=12:ompthreads=2
```

### Additional Options:

#### 1. To restart from a previous run:
```bash
# Copy restart files
cp /path/to/previous/run/restart*.nc .

# Modify croco.in to use restart files
sed -i 's/NRREC.*=.*0/NRREC = 1/' croco.in

# Run CROCO
mpirun -np $PBS_NP croco croco.in > $OUTDIR/croco.log 2>&1
```

#### 2. To run multiple simulations in sequence:
```bash
# Run first simulation
mpirun -np $PBS_NP croco croco_sim1.in > $OUTDIR/croco_sim1.log 2>&1

# Run second simulation
mpirun -np $PBS_NP croco croco_sim2.in > $OUTDIR/croco_sim2.log 2>&1
```
___
### 🛠️ Load performance tools
```bash
module load chpc/perf/vtune

# Run with performance monitoring
mpirun -np $PBS_NP amplxe-cl -collect hotspots -result-dir=$OUTDIR/vtune_results -- croco croco.in
```
