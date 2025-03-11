# croco-lengau-uct
This repository provides scripts, configuration files, and documentation for running CROCO on Lengau using Intel MPI, supporting ocean modelling research at UCT.

# Author: Mthetho Vuyo Sovara
## Last Update: 11 March 2025
## Developer Notes

The main required dependencies for building CROCO v2.0.1 on LENGAU with Intel compilers:
- zlib 1.3
- curl 7.88.1
- HDF5 1.14.0 (parallel enabled)
- netCDF-C 4.9.2 (parallel enabled)
- netCDF-Fortran 4.6.1

```bash
#!/bin/bash

# Set error handling
set -e  # Exit on error
set -u  # Exit on undefined variables

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
