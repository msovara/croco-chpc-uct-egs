## 🌊 CROCO-Lengau-UCT 🌊

This repository provides scripts, configuration files, and documentation for running CROCO on Lengau using Intel Compilers and MPI, supporting ocean modelling research at UCT.
___
📅 Last Update: 11 March 2025 \
👨‍💻 Author: Mthetho Vuyo Sovara \
📝 Developer Notes 

## Example usage: 
Clone the repo and try the example:

```bash
git clone https://github.com/msovara/croco-chpc-uct-egs.git
cd msovara/examples
./download.sh
```
____
## 🛠️ Developer Guide
The main dependencies are:

- MPI (Intel)
- zlib
- curl
- HDF5 (parallel enabled) 
- netCDF-C (parallel enabled) 
- netCDF-Fortran

### 🚀 Script 1: ```download.sh```
This script handles downloading and extracting all dependencies and CROCO source code.

### 🛠️ Script 2: ```build.sh```
This script handles building and installing all dependencies and CROCO.

____
## 📋 User Notes
 
The CROCO model has been installed in the ```/home/apps/chpc/earth``` directory where earth system science applications on LENGAU are typically installed. To use CROCO, you must first load the CROCO module and Matlab (for pre-processing) into your shell environment:
```bash
module avail 2>&1 | grep -i croco
module load chpc/earth/croco/2.0.1
module load chpc/math/matlab/R2021a
```

### 🖥️ Script 3: ```lengau_jobscript``` 
Example PBS Job Script for Running CROCO on Lengau
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
### 📋 Load performance tools
```bash
module load chpc/perf/vtune

# Run with performance monitoring
mpirun -np $PBS_NP amplxe-cl -collect hotspots -result-dir=$OUTDIR/vtune_results -- croco croco.in
```
