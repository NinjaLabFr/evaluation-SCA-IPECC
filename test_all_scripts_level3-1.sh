#!/bin/bash

dir="test_level3-1"
mkdir -p $dir
cd $dir

#creating venv and installing dependencies
python3 -m venv IPECCenv && source IPECCenv/bin/activate
pip install -r ../requirements.txt

# downloading and decompressing two parts of the dataset level 3.1
wget https://anssi.s3.sbg.io.cloud.ovh.net/ipecc/ipecc_level_3-1_part_{0,1}.tar.zst
printf "%s " ipecc_level_3-1_part_{0,1}.tar.zst | xargs -n 1 tar -I zstd -xf

# creating the virtual dataset which combines the subsets
python3 ../link_datasets.py ipecc_level_3-1_part_{0,1}.h5

# running SCA flow
cd ..
bash sca-flow.sh $dir/ipecc_level_3-1_parts_0-1-combined.h5 test_level3-1


