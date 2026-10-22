#!/bin/bash

dir="test_level3-1"
mkdir -p $dir
cd $dir

#creating venv and installing dependencies*
echo ""
echo "1/ Creating virtual environment ..."
python3 -m venv IPECCenv && source IPECCenv/bin/activate
echo ""
echo "2/ Installing dependencies ..."
pip install -r ../requirements.txt

# downloading two parts of the dataset level 3.1
echo ""
echo "3/ Downloading archives ..."
for i in 0 1; do
    dataset="ipecc_level_3-1_part_${i}.tar.zst"
    [[ -f "$dataset" ]] && echo "$dataset exists, skipping the download." || wget "https://anssi.s3.sbg.io.cloud.ovh.net/ipecc/$dataset"
done

# decompressing
echo ""
echo "4/ Uncompressing archives ..."
if [[ $(uname -s) == "Linux" ]]; then
	printf "%s " ipecc_level_3-1_part_{0,1}.tar.zst | xargs -n 1 tar -I zstd -xf
elif [[ $(uname -s) == "Darwin" ]]; then
	printf "%s " ipecc_level_3-1_part_{0,1}.tar.zst | xargs -n 1 tar -xf
else 
	echo "Please run this script on Linux or MacOS" 
	exit 1
fi;

# creating the virtual dataset which combines the subsets
echo ""
echo "5/ linking dataset subsets ..."
python3 ../link_datasets.py ipecc_level_3-1_part_{0,1}.h5

# running SCA flow
echo ""
echo "6/ Running SCA flow ..."
cd ..
bash sca-flow.sh $dir/ipecc_level_3-1_parts_0-1-combined.h5 test_level3-1