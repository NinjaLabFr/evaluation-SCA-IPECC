#!/bin/bash
set -euo pipefail

CYAN_BOLD='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [local|docker]"
    echo "Default mode: local"
    exit 0
fi

MODE=${1:-"local"}
if [[ "$MODE" != "local" && "$MODE" != "docker" ]]; then
    echo "Error: unknown mode '$MODE' (expected 'local' or 'docker')" >&2
    exit 1
fi

echo -e "${CYAN_BOLD}$MODE usage selected${NC}"

ROOT_DIR="$(pwd)"

# Directory setup
dir="test_level3-1"
mkdir -p "$dir"
cd "$dir"

# 1/ venv + deps (local only)
if [[ "$MODE" == "local" ]]; then
    printf "\n${BOLD}1/ Creating virtual environment ...${NC}\n"
    python3 -m venv IPECCenv && source IPECCenv/bin/activate
    printf "\n${BOLD}2/ Installing dependencies ...${NC}\n"
    pip install -q -r "$ROOT_DIR/requirements.txt"
fi

# 3/ download
printf "\n${BOLD}3/ Downloading archives ...${NC}\n"
for i in 0 1; do
    dataset="ipecc_level_3-1_part_${i}.tar.zst"
    [[ -f "$dataset" ]] && echo "$dataset exists, skipping the download." \
        || wget -c "https://anssi.s3.sbg.io.cloud.ovh.net/ipecc/$dataset"
done

# 4/ decompress
printf "\n${BOLD}4/ Uncompressing archives ...${NC}\n"
if [[ $(uname -s) == "Linux" ]]; then
    printf "%s " ipecc_level_3-1_part_{0,1}.tar.zst | xargs -n 1 tar -I zstd -xf
elif [[ $(uname -s) == "Darwin" ]]; then
    printf "%s " ipecc_level_3-1_part_{0,1}.tar.zst | xargs -n 1 tar -xf
else
    echo "Please run this script on Linux or MacOS"
    exit 1
fi


cd "$ROOT_DIR"

# 5/ link
printf "\n${BOLD}5/ Linking dataset subsets ...${NC}\n"
if [[ "$MODE" == "local" ]]; then
    make link DATASET=ipecc_level_3-1_parts_0-1-combined.h5 DATA_DIR=test_level3-1 \
        PARTS="test_level3-1/ipecc_level_3-1_part_0.h5 test_level3-1/ipecc_level_3-1_part_1.h5"
else
    make docker-link DATASET=ipecc_level_3-1_parts_0-1-combined.h5 DATA_DIR=test_level3-1 \
        PARTS="test_level3-1/ipecc_level_3-1_part_0.h5 test_level3-1/ipecc_level_3-1_part_1.h5"
fi

# 6/ full SCA flow
printf "\n${BOLD}6/ Running SCA flow ...${NC}\n"
if [[ "$MODE" == "local" ]]; then
    make all DATASET=ipecc_level_3-1_parts_0-1-combined.h5 DATA_DIR=test_level3-1
else
    make docker-all DATASET=ipecc_level_3-1_parts_0-1-combined.h5 DATA_DIR=test_level3-1
fi