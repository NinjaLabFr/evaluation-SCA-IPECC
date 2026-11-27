import os
import numpy as np
from numpy.lib.format import open_memmap


def compute_kappas(scalar: np.array, phi: np.array):
    """Computes the values of kappa and kappa' based on input data.

    Args:
        scalar (np.array): array containing the values of the scalar as arrays of bytes.
        phi (np.array): array containing the values of phi as arrays of bytes.

    Returns:
        np.array, np.array: numpy arrays containing the values of kappa and kappa'
    """

    nb_traces_global = phi.shape[0]

    MASK_256 = (1 << 256) - 1

    kappas = np.zeros(
        dtype=np.uint8,
        shape=(nb_traces_global, 32),
    )
    kappaPs = np.zeros(
        dtype=np.uint8,
        shape=(nb_traces_global, 32),
    )

    for i in range(nb_traces_global):

        v_phi = int.from_bytes(phi[i], byteorder="big")
        v_k = int.from_bytes(scalar[i], byteorder="big")

        v_phi_256 = v_phi & MASK_256
        v_k_use = v_k >> 1

        v_kappa = v_k_use ^ v_phi_256
        kappas[i] = list(v_kappa.to_bytes(32, byteorder="big"))

        v_phi_256 = (v_phi_256 << 1) & MASK_256
        v_kappa_prime = v_k_use ^ v_phi_256
        kappaPs[i] = list(v_kappa_prime.to_bytes(32, byteorder="big"))

    return kappas, kappaPs


def print_banner():
    banner = r"""
    ┌──────────────────────────────────────────┐
    |         Compute kappa and kappa'         |
    ╰──────────────────────────────────────────╯ 
    """
    print(banner)

    """

    Args:
        dir_files (str): directory where the numpy files containing data can be found.

    Raises:
        FileNotFoundError: if one or more data files are missing.

    Returns:
        int: number of processed entries.
    """


if __name__ == "__main__":
    import argparse
    import h5py

    print_banner()
    parser = argparse.ArgumentParser(
        description="Compute kappa and kappa' from phi and k arrays."
    )
    parser.add_argument(
        "-d",
        "--dataset",
        type=str,
        required=True,
        help="Dataset Hdf5 file.",
    )
    parser.add_argument(
        "-t",
        "--temp-dir",
        type=str,
        default="/tmp",
        help="Directory to store temporary results.",
    )

    args = parser.parse_args()

    # Load data
    if not os.path.exists(args.dataset):
        raise FileNotFoundError(f"{args.dataset} not found!")

    # Check file type is HDF5
    if not args.dataset.endswith('.h5'):
        raise ValueError(f"Error: dataset file {args.dataset} is not a HDF5 file!")

    with h5py.File(args.dataset, "r") as file_handler:
        if not "scalar" in file_handler["inputs"]:
            raise ValueError("Error: dataset inputs/scalar not found in the file!")
        if not "phi" in file_handler["inputs"]:
            raise ValueError("Error: dataset inputs/phi not found in the file!")

        k = file_handler["inputs/scalar"]
        phi = file_handler["inputs/phi"]

        kappas, kappaPs = compute_kappas(k, phi)

    np.save(os.path.join(args.temp_dir, "inputs_kappa.npy"), kappas)
    np.save(os.path.join(args.temp_dir, "inputs_kappaP.npy"), kappaPs)

    print(f"Successfully processed {phi.shape[0]} scalar multiplication operations.")
