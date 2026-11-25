#!/bin/bash

# Script for testing al the SCA flow over ASCAD IPECC Level 3.1 supporting both local and docker usage
# Usage: ./script.sh [local|docker]
# Default mode: local

CYAN_BOLD='\033[1;36m'
NC='\033[0m' # No Color

# Print help
if [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [local|docker]"
    echo "Default mode: local"
    exit 0
fi

# Default mode: local
MODE=${1:-"local"}

echo -e "${CYAN_BOLD}Running in $MODE mode${NC}"

# Directory setup
dir="test_level3-1"
mkdir -p "$dir"
cd "$dir"

# Creating virtual environment and installing dependencies (local mode only)
if [[ "$MODE" == "local" ]]; then
    printf "\n1/ Creating virtual environment ...\n"
    python3 -m venv IPECCenv && source IPECCenv/bin/activate
    printf "\n2/ Installing dependencies ...\n"
    pip install -q -r ../requirements.txt
fi

# Downloading datasets
printf "\n3/ Downloading archives ...\n"
for i in 0 1; do
    dataset="ipecc_level_3-1_part_${i}.tar.zst"
    [[ -f "$dataset" ]] && echo "$dataset exists, skipping the download." || wget -c "https://anssi.s3.sbg.io.cloud.ovh.net/ipecc/$dataset"
done

# Decompressing archives
printf "\n4/ Uncompressing archives ..."
if [[ $(uname -s) == "Linux" ]]; then
    printf "%s " ipecc_level_3-1_part_{0,1}.tar.zst | xargs -n 1 tar -I zstd -xf
elif [[ $(uname -s) == "Darwin" ]]; then
    printf "%s " ipecc_level_3-1_part_{0,1}.tar.zst | xargs -n 1 tar -xf
else
    echo "Please run this script on Linux or MacOS"
    exit 1
fi

# Linking datasets (local vs Docker)
printf "\n5/ Linking dataset subsets ..."
if [[ "$MODE" == "local" ]]; then
    python3 ../link_datasets.py ipecc_level_3-1_part_{0,1}.h5
else
    docker build -t ipecc . && docker run --rm -v "$(pwd)":/datasets ipecc python3 /app/link_datasets.py /datasets/ipecc_level_3-1_part_{0,1}.h5 -o /datasets/out.h5
fi

# Running SCA flow
printf "\n6/ Running SCA flow ..."
cd ..
if [[ "$MODE" == "local" ]]; then
    make all DATASET=ipecc_level_3-1_parts_0-1-combined.h5 DATA_DIR=test_level3-1
else
    docker build -t ipecc . && docker run --rm -v "$(pwd)/test_level3-1":/datasets ipecc DATASET=ipecc_level_3-1_parts_0-1-combined.h5 DATA_DIR=/datasets
fi