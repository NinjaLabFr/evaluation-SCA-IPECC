#!/bin/bash
set -euo pipefail

CYAN_BOLD='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

# Print help (must come before MODE is used)
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [local|docker]"
    echo "Default mode: local"
    exit 0
fi

# Default mode: local
MODE=${1:-"local"}

# Validate mode
if [[ "$MODE" != "local" && "$MODE" != "docker" ]]; then
    echo "Error: unknown mode '$MODE' (expected 'local' or 'docker')" >&2
    exit 1
fi

echo -e "${CYAN_BOLD}$MODE usage selected${NC}"

# Directory setup
dir="test_level3-1"
mkdir -p "$dir"
cd "$dir"

# Creating virtual environment and installing dependencies (local mode only)
if [[ "$MODE" == "local" ]]; then
    printf "\n${BOLD}1/ Creating virtual environment ...${NC}\n"
    python3 -m venv IPECCenv && source IPECCenv/bin/activate
    printf "\n${BOLD}2/ Installing dependencies ...${NC}\n"
    pip install -q -r ../requirements.txt
fi

# Downloading datasets
printf "\n${BOLD}3/ Downloading archives ...${NC}\n"
for i in 0 1; do
    dataset="ipecc_level_3-1_part_${i}.tar.zst"
    [[ -f "$dataset" ]] && echo "$dataset exists, skipping the download." || wget -c "https://anssi.s3.sbg.io.cloud.ovh.net/ipecc/$dataset"
done

# Decompressing archives
printf "\n${BOLD}4/ Uncompressing archives ...${NC}\n"
if [[ $(uname -s) == "Linux" ]]; then
    printf "%s " ipecc_level_3-1_part_{0,1}.tar.zst | xargs -n 1 tar -I zstd -xf
elif [[ $(uname -s) == "Darwin" ]]; then
    printf "%s " ipecc_level_3-1_part_{0,1}.tar.zst | xargs -n 1 tar -xf
else
    echo "Please run this script on Linux or MacOS"
    exit 1
fi

# Linking datasets (local vs Docker)
printf "\n${BOLD}5/ Linking dataset subsets ...${NC}\n"
if [[ "$MODE" == "local" ]]; then
    make link DATASET=ipecc_level_3-1_parts_0-1-combined.h5 DATA_DIR=. PARTS="ipecc_level_3-1_part_0.h5 ipecc_level_3-1_part_1.h5"
else
    cd ..
    docker build -t ipecc . && docker run --rm -v "$(pwd)/test_level3-1":/datasets ipecc link DATASET=ipecc_level_3-1_parts_0-1-combined.h5 DATA_DIR=/datasets PARTS="/datasets/ipecc_level_3-1_part_0.h5 /datasets/ipecc_level_3-1_part_1.h5"
fi

# Running SCA flow
printf "\n${BOLD}6/ Running SCA flow ...${NC}\n"

if [[ "$MODE" == "local" ]]; then
    cd ..
    make all DATASET=ipecc_level_3-1_parts_0-1-combined.h5 DATA_DIR=test_level3-1
else
    docker build -t ipecc . && docker run --rm  -v "$(pwd)/test_level3-1":/datasets ipecc all DATASET=ipecc_level_3-1_parts_0-1-combined.h5 DATA_DIR=/datasets
fi