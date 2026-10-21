import h5py
import numpy as np
import os
from plot_traces import plot_global, plot_subplots
from scalib.metrics import SNR


def print_banner():
    header = r"""
    ┌──────────────────────────────────────────┐
    |             SNR based on SCALib          |
    ╰──────────────────────────────────────────╯                  
    """
    print(header)


def compute_snr(
    file_handler: h5py.File,
    nb_traces: int = None,
    chunk_size: int = 1000,
    first_trace_index: int = 0,
):
    """Computes SNR for each of the intermediate targeted variable.

    Args:
        file_handler (h5py.File): H5 file handler containing subtraces and the corresponding variables.
            values (generated using the splitting script).
        chunk_size (int): SCALIB API allows incremental procesing of the data.
            This parameter tunes the size of a chunk (it may be adapted to the curve size
            and the available memory). Defaults to 1000.
        first_trace_index (int): first trace to consider in the dataset. Defaults to 0.

    Returns:
        np.ndarray: array of the computed SNRs.
    """

    # Load traces
    traces = file_handler["subtraces"]
    x = file_handler["inputs"]

    inputs_list = []
    for iname in file_handler["inputs"].dtype.fields:
        inputs_list.append(iname)

    print("Traces shape:", traces.shape)
    print("Inputs shape:", x.shape)
    if nb_traces is not None:
        assert (
            nb_traces <= traces.shape[0]
        ), "too much traces required compared to dataset size"
    else:
        nb_traces = traces.shape[0]
    last_trace_index = first_trace_index + nb_traces
    print(f"Will process {nb_traces} traces starting from index {first_trace_index}.")

    # Setup SNR
    snr = SNR(nc=2, use_64bit=True)

    # Incremental processing
    for chunk_start in range(first_trace_index, last_trace_index, chunk_size):
        chunk_end = min(chunk_start + chunk_size, last_trace_index)

        print(f"\rProcessing subtraces {chunk_start}:{chunk_end}", end="")

        traces_c = traces[chunk_start:chunk_end]
        inputs_c = x[chunk_start:chunk_end]

        # convert to a format handled by SCALIB, the array is conerted to uint16 to match the defition (see
        # https://scalib.readthedocs.io/en/stable/source/api/scalib.metrics.SNR.html#scalib.metrics.SNR)
        x_c = np.ndarray(
            shape=(inputs_c.shape[0], len(x.dtype)), dtype=np.uint16
        )
        for i, iname in enumerate(inputs_list):
            x_c[:, i] = inputs_c[iname][:, 0]

        snr.fit_u(traces_c, x_c)

    print()

    # SNR result
    snr_val = snr.get_snr()

    return {iname: snr_val[i] for i, iname in enumerate(inputs_list)}


if __name__ == "__main__":
    import argparse

    print_banner()
    parser = argparse.ArgumentParser(
        description="Incremental SNR computation with plotting"
    )
    parser.add_argument(
        "-d",
        "--dataset",
        type=str,
        required=True,
        help="Subtraces Hdf5 file.",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=str,
        required=True,
        help="Output directory for SNR plots.",
    )

    args = parser.parse_args()

    # Load data
    if not os.path.exists(args.dataset):
        raise FileNotFoundError(f"Error: {args.dataset} not found!")

    h5file = h5py.File(args.dataset, "r")

    snr_val = compute_snr(file_handler=h5file, chunk_size=1000)

    h5file.close()

    # Print max values
    print("\n\033[1mMax SNR for :\033[0m")
    maxs = []
    for variable_name, snr in snr_val.items():
        m = np.max(snr)
        print(f"\t{variable_name}: {m:.4f}")
        maxs.append([variable_name, m])

    maxs_sorted = sorted(maxs, key=lambda x: x[1], reverse=True)
    print()
    print(f"global max is for {maxs_sorted[0][0]} with {maxs_sorted[0][1]:.4f}")
    print(f"2nd global max is for {maxs_sorted[1][0]} with {maxs_sorted[1][1]:.4f}")

    # Plot results

    plot_global(
        output_filename=os.path.join(args.output, "snr.png"),
        curves=snr_val,
        show_max=True,
        title="SNR",
        y_min = 0,
        y_axis_label="SNR values",
    )

    plot_subplots(
        output_filename=os.path.join(args.output, "snr-subplots.png"),
        curves=snr_val,
        title="SNR per input",
    )
