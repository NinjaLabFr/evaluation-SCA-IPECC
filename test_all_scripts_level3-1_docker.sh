#!/bin/bash

dir="test_level3-1"
mkdir -p $dir
cd $dir

# downloading two parts of the dataset level 3.1
for i in 0 1; do
    dataset="ipecc_level_3-1_part_${i}.tar.zst"
    [[ -f "$dataset" ]] && echo "$dataset exists, skipping the download." || wget "https://anssi.s3.sbg.io.cloud.ovh.net/ipecc/$dataset"
done

# decompressing
if [[ $(uname -s) == "Linux" ]]; then
	printf "%s " ipecc_level_3-1_part_{0,1}.tar.zst | xargs -n 1 tar -I zstd -xf
elif [[ $(uname -s) == "Darwin" ]]; then
	printf "%s " ipecc_level_3-1_part_{0,1}.tar.zst | xargs -n 1 tar -xf
else 
	echo "Please run this script on Linux or MacOS" 
	exit 1
fi;

# creating the virtual dataset which combines the subsets
python3 ../link_datasets.py ipecc_level_3-1_part_{0,1}.h5

# running SCA flow
cd ..
docker build -t ipecc . && docker run  -v test_level3-1:/datasets ipecc  /datasets/ipecc_level_3-1_parts_0-1-combined.h5 /datasets/