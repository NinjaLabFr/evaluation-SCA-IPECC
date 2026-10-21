#!/usr/bin/env bash

dataset="$1"
data_dir="$2"

if [ -z "$data_dir" ]; then
  echo "Usage: $0 <dataset> <data_directory>"
  exit 1
fi

python3 compute_kappas.py -d "$dataset" -t "$data_dir"
python3 splitting.py -d "$dataset" -t "$data_dir" -r
python3 compute_snr.py -d "$data_dir"/subtraces.h5  -o "$data_dir"
python3 template_attack.py -d "$data_dir"/subtraces.h5 -i kappa_prime -t 0.0009
