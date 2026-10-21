#!/usr/bin/env python3
"""
Description: Combines the split HDF5 subsets into a single virtual dataset (VDS) https://support.hdfgroup.org/documentation/hdf5/latest/_v_d_s_t_n.html
Usage: python3 link_datasets.py ipecc_level_1-0_part_0.h5 ipecc_level_1-0_part_1.h5 ... [-o out.h5]
"""

import argparse
import operator
import os
import sys

import h5py


def get_prefix_and_part(filename):
    name = os.path.basename(filename)
    if name.endswith(".h5"):
        name = name[:-3]
    if "_part_" not in name:
        raise ValueError(f"{filename}: expected a name like 'ipecc_level_<X>-<Y>_part_<N>.h5'")
    prefix, _, part = name.rpartition("_part_")
    return prefix, part


def collect_dataset_paths(filename):
    """Return a list of every dataset path inside a file."""
    paths = []

    def visitor(name, obj):
        if isinstance(obj, h5py.Dataset):
            paths.append(name)

    with h5py.File(filename, "r") as f:
        f.visititems(visitor)
    return paths


def run(args):
    # check that all inputs come from the same configuration 
    prefix = None
    files = []
    for filename in args.files:
        p, part = get_prefix_and_part(filename)
        if prefix is None:
            prefix = p
        elif p != prefix:
            raise ValueError(f"{filename} belongs to a different configuration ({p} vs {prefix})")
        files.append((int(part) if part.isdigit() else part, filename))

    # sorting them
    files.sort(key=operator.itemgetter(0))
    parts = [str(num) for num, _ in files]
    files = [filename for _, filename in files]

    if args.output is None:
        args.output = f"{prefix}_parts_{'-'.join(parts)}-combined.h5"

    paths = collect_dataset_paths(files[0])

    with h5py.File(args.output, "w", libver="latest") as out:
        for path in paths:
            # read the shape and dtype of this dataset from every file to ensure the structure matches
            sources = []
            for filename in files:
                with h5py.File(filename, "r") as f:
                    if path not in f:
                        raise ValueError(f"'{path}' is missing from {filename}")
                    ds = f[path]
                    sources.append((filename, ds.shape, ds.dtype))

            first_shape, first_dtype = sources[0][1], sources[0][2]
            for filename, shape, dtype in sources:
                if dtype != first_dtype:
                    raise ValueError(f"{path}: dtype differs in {filename} ({dtype} vs {first_dtype})")
                if shape[1:] != first_shape[1:]:
                    raise ValueError(f"{path}: shape differs in {filename} ({shape} vs {first_shape})")

            # the combined dataset 
            total = sum(shape[0] for _, shape, _ in sources)
            new_shape = (total,) + first_shape[1:]

            parent = os.path.dirname(path)
            if parent:
                out.require_group(parent)

            layout = h5py.VirtualLayout(shape=new_shape, dtype=first_dtype)
            offset = 0
            for filename, shape, dtype in sources:

                layout[offset:offset + shape[0]] = h5py.VirtualSource(filename, path, shape=shape, dtype=dtype)

                offset += shape[0]

            out.create_virtual_dataset(path, layout)
            print(f"  {path}: {new_shape} {first_dtype}")

    print(f"\nWrote '{args.output}'")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="+")
    parser.add_argument("-o", "--output", default=None)
    args = parser.parse_args()

    try:
        run(args)
    except ValueError as err:
        sys.exit(f"Error: {err}")


if __name__ == "__main__":
    main()