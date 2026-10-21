import h5py
import numpy as np
import os

filename = "traces.npy"
inputNames = ["scalar", "phi", "kappa", "kappaP", "Px", "Py"]


def print_banner():
    banner = r"""
    ┌──────────────────────────────────────────┐
    |             Split and Resync             |
    ╰──────────────────────────────────────────╯                  
    """
    print(banner)


def detect_negative_peaks(
    trace: np.ndarray | list,
    threshold: int = -6500,
    start: int = 0,
    expected_len: int = 425_000,
    margin: int = 15_000,
):
    """Detects negative peaks (ie below a threshold).

    Args:
        trace (_type_): _description_
        threshold (int, optional): threshold for the peak detection (a peak is a value below this threshold). Defaults to -6500.
        start (int, optional): first trace sample ot consider for peak detection. Defaults to 0.
        expected_len (int, optional): expected length of a pattern. Defaults to 425_000.
        margin (int, optional): margin for pattern length (two successive peak distance must belong to (expected_len-margin, expected_len+margin) ). Defaults to 15_000.

    Returns:
        np.array: array of detected peaks
    """
    t_abs = np.where(trace <= threshold)[0].astype(np.uint32)
    t_abs = t_abs[t_abs > start]
    filtered = []
    if len(t_abs) > 0:
        ref = t_abs[0]
        filtered.append(ref)
        for k in range(1, len(t_abs)):
            diff = t_abs[k] - ref
            if expected_len - margin <= diff:  # <= expected_len + margin:
                filtered.append(t_abs[k])
                ref = t_abs[k]
    return np.array(filtered, dtype=np.uint32)


def split_trace(
    trace: np.ndarray | list,
    subtraces_start_points: list,
    subtraces_length: int = 510_000,
    max_num_subtraces=254,
):
    """Split a trace into subtraces.

    Args:
        trace (_type_):
        subtraces_start_points (list): list of subtraces starting points.
        subtraces_length (int, optional): maximal size of the subtraces. Defaults to 510_000.
        max_num_subtraces (int, optional): maximal number of extracted subtraces. Defaults to 254.

    Returns:
        _type_: _description_
    """
    subtraces = []
    for i, start in enumerate(subtraces_start_points[:max_num_subtraces]):
        end = min(len(trace), start + subtraces_length)
        mini = trace[start:end]
        subtraces.append(mini)
    return np.array(subtraces, dtype=trace.dtype)


def prepare_inputs(
    inputs: dict,
    nb_subtraces: int,
):
    """From input values used during trace acquisition, extract bit corresponding to the first `nb_subtraces` subtraces.

    Args:
        inputs (dict[str,np.array]): Dictionary of inputs processed and that need to be splitted in bits corresponding to the subtraces.
        nb_subtraces (int): number of subtraces for which we extract inputs.

    Returns:
        np.array: numpy array with a particular dtype so that the syntax output["kappa"][4] returns the 5-th bit of input kappa.
    """

    input_dtype = np.dtype([(input_name, "u1", (1,)) for input_name in inputs])
    output = np.full((nb_subtraces,), 0xFF, dtype=input_dtype)

    for input_name, value in inputs.items():
        value = np.unpackbits(inputs[input_name].astype(np.uint8))[::-1]
        for j in range(nb_subtraces):
            # in the case of the scalar, he two first bits are somehow processed together
            # since register is initialized to [3]P hence this case has to be specific
            if input_name == "scalar":
                output[input_name][j] = value[j + 2]
            else:
                output[input_name][j] = value[j + 1]

    return output


def check_negative_peak_position(
    subtraces: np.ndarray | list, threshold: int, indice_min: int, indice_max: int
):
    """Select only subtraces where a *small* sample is present in a provided time window.

    Args:
        subtraces (np.ndarray | list): subtraces to process.
        threshold (int): below the provided threshod, a sample is considered small.
        indice_min (int): first indice of the considered time window.
        indice_max (int): last indice of the considered time window.

    Returns:
        (np.array, list): array only containing kept subtraces plus a list of the corresponding indices in the original array (`subtraces` argument).
    """
    valid_indices = []
    for indice, subtrace in enumerate(subtraces):
        peaks_in_window = np.where(subtrace[indice_min : indice_max + 1] <= threshold)[
            0
        ].astype(np.uint32)
        if len(peaks_in_window) > 0:
            valid_indices.append(indice)

    return (
        np.array([subtraces[i] for i in valid_indices], dtype=subtraces.dtype),
        valid_indices,
    )


def extract_subtraces(
    traces: np.ndarray,
    inputs: dict,
    output_filename: str,
    refined_filtering: bool = True,
    nb_traces: int = None,
    progression: bool = False,
) -> None:
    """Splits traces in subtraces corresponding to a single bit processing and conjointly stores the corresponding bit values of the scalar, kappa and kappa'.

    Args:
        curves (np.ndarray): array containing the traces to split.
        inputs (dict[str, np.ndarray]): dictionnary containing the different inputs.
        output_filename (str): filename for the subtraces dataset.
        nb_traces (int | None): number of traces to process (None means all). Defaults to None.
        refined_filtering (bool, optional): if True, apply a filtering step withdrawing subtraces for which the detected peak is not ina specified timezone. Defaults to True.
        progression (bool, optional): if True, print a dynamic counter to monitor progression. Defaults to False.
    """
    nb_traces_to_process = traces.shape[0]
    if nb_traces:
        if nb_traces <= nb_traces_to_process:
            nb_traces_to_process = nb_traces
        else:
            raise ValueError(
                f"Argument nb_traces is to large (maximum {nb_traces_to_process})"
            )

    # the extracted subtrace will be of size (at most) PATTERN_LEN
    SUBTRACE_LEN = 510_000
    # the peak whould correspond to the PEAK_OFFSET-th sample of a subtrace
    SUBTRACE_OFFSET = 10_000

    # creates the file that will contain the results
    if not (output_filename.endswith(".h5") or output_filename.endswith(".hdf5")):
        output_filename += ".h5"
    h5file = h5py.File(output_filename, "w")
    subtraces_dset = h5file.create_dataset(
        "subtraces", (0, SUBTRACE_LEN), dtype=np.int16, maxshape=(None, SUBTRACE_LEN)
    )
    # use a specific dtype to be able to select the input by its name
    relevant_inputs = ["scalar", "kappa", "kappa_prime", "phi"]
    dtype_list = []
    for input_name in inputs:
        if input_name not in relevant_inputs:
            raise ValueError(f"Unexpected input {input_name} in provided dict.")
        else:
            dtype_list.append((input_name, "u1", (1,)))
    input_dtype = np.dtype(dtype_list)
    inputs_dset = h5file.create_dataset(
        "inputs", (0,), dtype=input_dtype, maxshape=(None,)
    )

    total_subtraces = 0
    write_ptr = 0
    print("\n\033[94mWriting patterns \033[0m")
    for i in range(nb_traces_to_process):
        trace = traces[i]

        # splitting
        peak_locations = detect_negative_peaks(trace, start=1171000)

        start_positions = peak_locations - SUBTRACE_OFFSET
        start_positions[np.where(start_positions < 0)] = 0
        subtraces = split_trace(
            trace, start_positions, subtraces_length=510_000, max_num_subtraces=254
        )
        assert len(subtraces) == 254

        # add inputs
        trace_inputs = prepare_inputs(
            inputs={name: value[i] for name, value in inputs.items()},
            nb_subtraces=len(subtraces),
        )

        # Here we remove first and last subtraces because they have a different leakage behavior.
        subtraces = subtraces[1:-1]
        trace_inputs = trace_inputs[1:-1]

        # if refined filtering: additional step to check that there is a small enough sample (from the peak)
        # inside a determined window where it should occur.
        if refined_filtering:
            minis_filt, valid_idx = check_negative_peak_position(
                subtraces, threshold=-4000, indice_min=6000, indice_max=6300
            )
            # removing rejected subtraces
            inputs_filt = trace_inputs[valid_idx]
        else:
            minis_filt = subtraces
            inputs_filt = trace_inputs

        # resize datasets
        total_subtraces += len(minis_filt)
        subtraces_dset.resize(total_subtraces, axis=0)
        inputs_dset.resize(total_subtraces, axis=0)

        # writing the subtraces
        for k in range(len(minis_filt)):
            mini = minis_filt[k]
            ilen = min(len(mini), SUBTRACE_LEN)
            subtraces_dset[write_ptr, :ilen] = mini[:ilen]
            inputs_dset[write_ptr] = inputs_filt[k]
            write_ptr += 1

            # dynamic counter
            if progression:
                print(f"\rWriting subtraces {write_ptr}/{total_subtraces}", end="")

    h5file.close()
    print()


if __name__ == "__main__":
    import argparse

    print_banner()
    parser = argparse.ArgumentParser(
        description="Splitting of full scalar multiplication inputs and traces into scalar multiplication iteration inputs and subtraces. Resynchronization of scalar multiplication iteration subtraces is optional."
    )
    parser.add_argument(
        "-d",
        "--dataset",
        type=str,
        required=True,
        help="Dataset Hdf5 file.",
    )
    parser.add_argument(
        "-n",
        "--nbtraces",
        type=int,
        default=None,
        help="Number of traces to process (optional) - If not specified, all traces are processed",
    )
    parser.add_argument(
        "-r",
        "--refined-filtering",
        action="store_true",
        help="Apply resynchronization to subtraces (optional)",
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
        raise FileNotFoundError(f"Error: {args.dataset} not found!")

    kappas = np.load(os.path.join(args.temp_dir, "inputs_kappa.npy"))
    kappaPs = np.load(os.path.join(args.temp_dir, "inputs_kappaP.npy"))

    with h5py.File(args.dataset, "r") as file_handler:
        if not "em_curves" in file_handler:
            raise ValueError("Error: dataset em_curves not found in the file!")
        if not "scalar" in file_handler["inputs"]:
            raise ValueError("Error: dataset inputs/scalar not found in the file!")
        if not "phi" in file_handler["inputs"]:
            raise ValueError("Error: dataset inputs/phi not found in the file!")

        # listing relevant inputs to store wih the subtraces
        inputs = {
            "scalar": file_handler["inputs/scalar"],
            "phi": file_handler["inputs/phi"],
            "kappa": kappas,
            "kappa_prime": kappaPs,
        }

        nb_traces = file_handler["em_curves"].shape[0]
        if args.nbtraces is not None and args.nbtraces < nb_traces:
            nb_traces = args.nbtraces

        extract_subtraces(
            traces=file_handler["em_curves"],
            inputs=inputs,
            output_filename=os.path.join(args.temp_dir, "subtraces.h5"),
            nb_traces=nb_traces,
            refined_filtering=args.refined_filtering,
            progression=True,
        )
