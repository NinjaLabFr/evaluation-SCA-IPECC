import h5py
import numpy as np
import os
from scalib.metrics import SNR
from scalib.modeling import Lda, LdaAcc
from compute_snr import compute_snr


def print_banner():
    header = r"""
    ┌──────────────────────────────────────────┐
    |      Template attacks using SCALib       |
    ╰──────────────────────────────────────────╯                  
      
    """
    print(header)


def compute_success(prediction_probas, truth):
    # Compute the classes corresponding to the max probabilities
    prediction_classes = np.argmax(prediction_probas.squeeze(0), axis=1)
    # Compare to the ground truth
    correct = np.sum(prediction_classes == truth[:, 0])
    success_rate = correct / len(prediction_classes)
    return success_rate * 100


def template_attack(
    file_handler: h5py.File,
    input_target: int,
    snr_threshold: float,
    learn_ratio: float = 0.8,
    chunk_size: int = 1000,
):
    """_summary_

    Args:
        file_handler (h5py.File): H5 file handler containing subtraces and the corresponding variables.
        input_target (int): name of the target variable.
        snr_threshold (float): threshold on SNR to consider a point is of interest.
        learn_ratio (float, optional): proportion of learning traces in the dataset. Defaults to 0.8.
        chunk_size (int, optional): number of traces provided to SCALIB in a batch. Defaults to 1000.

    Returns:
        float: success rate
    """
    traces = file_handler["subtraces"]
    x = file_handler["inputs"]

    nb_traces = traces.shape[0]
    train_selection_idx = slice(0, round(nb_traces * learn_ratio))
    predict_selection_idx = slice(round(nb_traces * learn_ratio), nb_traces)

    # SNR to select POIs
    print("\n\033[94m1. Perform SNR (to select POIs) \033[0m")
    snr_values = compute_snr(
        file_handler,
        nb_traces=train_selection_idx.stop - train_selection_idx.start,
        chunk_size=1000,
        first_trace_index=train_selection_idx.start,
    )[input_target]
    pois = np.where(snr_values > snr_threshold)[0].tolist()
    print("POIs:", len(pois))
    lda_acc = LdaAcc(nc=2, pois=[pois])

    # Build the template using SCALIB LDA (on profiling traces)
    print("\n\n\033[94m2. Build templates \033[0m")
    for chunk_start in range(
        train_selection_idx.start, train_selection_idx.stop, chunk_size
    ):
        chunk_end = min(chunk_start + chunk_size, train_selection_idx.stop)
        idx = slice(chunk_start, chunk_end)

        print(f"\rProcessing subtraces {chunk_start}:{chunk_end}", end="")
        lda_acc.fit_u(traces[idx], x[input_target][idx].astype(np.uint16))
    print()
    lda = Lda(lda_acc, p=1)

    # Perform attack (prediction on he remaining traces)
    print("\n\033[94m3. Predict \033[0m")
    predictions = []
    ground_truth = []
    for chunk_start in range(
        predict_selection_idx.start, predict_selection_idx.stop, chunk_size
    ):
        chunk_end = min(chunk_start + chunk_size, predict_selection_idx.stop)
        idx = slice(chunk_start, chunk_end)

        print(f"\rProcessing subtraces {chunk_start}:{chunk_end}", end="")
        pred_chunk = lda.predict_proba(traces[idx])
        predictions.append(pred_chunk)
        ground_truth.append(x[input_target][idx].astype(np.uint16))

    print()
    predictions = np.concatenate(predictions, axis=1)
    ground_truth = np.concatenate(ground_truth, axis=0)

    # Evaluate the attack performances
    sr = compute_success(predictions, ground_truth)
    return sr


if __name__ == "__main__":
    import argparse

    print_banner()
    parser = argparse.ArgumentParser(description="LDA aka Template Attacks")
    parser.add_argument(
        "-d",
        "--dataset",
        type=str,
        required=True,
        help="Subtraces Hdf5 file.",
    )
    parser.add_argument(
        "-i",
        "--input-target",
        type=str,
        required=True,
        help="Name of the input we attack.",
    )
    parser.add_argument(
        "-t",
        "--threshold",
        type=float,
        required=True,
        help="Threshold to set for SNR to select POIs",
    )

    args = parser.parse_args()

    # Load data
    if not os.path.exists(args.dataset):
        raise FileNotFoundError(f"Error: {args.dataset} not found!")

    h5file = h5py.File(args.dataset, "r")

    sr = template_attack(
        file_handler=h5file, input_target=args.input_target, snr_threshold=args.threshold
    )

    h5file.close()

    print(f"\nGlobal success rate: \033[92m {sr:.2f}% \033[0m")
