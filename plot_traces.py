#!/usr/bin/env python3
import h5py
import matplotlib.pyplot as plt
import numpy as np
import sys


def plot_global(
    curves: dict,
    output_filename: str | None = None,
    show_max: bool = True,
    title: str = None,
    figsize: tuple = (20,10),
    y_min: int = None,
    y_axis_label: str = "Amplitude",
):
    """Plots curves on a single plot.

    Args:
        curves (dict): dictionary with entries curve_name: curve_values.
        output_filename (str | None, optional): filename where the plot will be stored (will plot if no value is provided).
        show_max (bool, optional): add a marker on the global maximum. Defaults to True.
        title (str, optional): title of the figure. Defaults to None.
        figsize (tuple, optional): value of figsize provided to matplotlib. Defaults to (20,10).
        y_min (int, optional): force the y-axis baseline. Defaults to None.
        y_axis_label (str, optional): y-axis label. Defaults to Amplitude.
    """

    plt.figure(figsize=figsize)

    # for windows users
    # mng = plt.get_current_fig_manager()
    # try:
    #     mng.resize(*mng.window.maxsize())
    # except:
    #     pass

    global_min = None
    global_max = None
    global_argmax = None
    samples_max = None
    for label, curve in curves.items():
        if np.all(np.isnan(curve)):
            continue
        local_min = np.nanmin(curve)
        local_max = np.nanmax(curve)
        if global_min is None or global_min < local_min:
            global_min = local_min
        if global_max is None or global_max < local_max:
            global_max = local_max
            global_argmax = np.nanargmax(curve)
        if samples_max is None or samples_max < len(curve):
            samples_max = len(curve)
        plt.plot(np.arange(samples_max), curve, label=label)

    if show_max:
        plt.scatter(global_argmax, global_max, color="red", s=50)
        plt.text(
            global_argmax,
            global_max,
            f"{global_max:.2f} @ {global_argmax}",
            color="red",
        )

    if y_min is not None:
        global_min = y_min
    absmax = max(abs(global_min), abs(global_max))
    margin = 0.1 * absmax

    plt.xlabel("Sample index")
    if title:
        plt.ylabel(y_axis_label)
        plt.title(title)

    plt.ylim(global_min - margin, global_max + margin)
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    if output_filename is None:
        plt.show()
    else:
        plt.savefig(output_filename)


def plot_subplots(
    output_filename: str,
    curves: dict,
    title: str = None,
    y_min: int = None,
):
    """Plot curves on individual plots vertically stacked.

    Args:
        output_filename (str): filename where the plot will be stored.
        curves (dict): dictionary with entries curve_name: curve_values.
        title (str, optional): title of the figure. Defaults to None.
        y_min (int, optional): force the y-axis baseline. Defaults to None.
    """
    n_vars = len(curves)
    fig, axes = plt.subplots(n_vars, 1, figsize=(10, 3 * n_vars), sharex=True)
    global_min = None
    global_max = None
    samples_max = None

    if n_vars == 1:
        axes = [axes]

    for i, (label, curve) in enumerate(curves.items()):
        ax = axes[i]

        if np.all(np.isnan(curve)):
            ax.set_ylabel(label)
            ax.grid(True)
            continue

        local_min = np.nanmin(curve)
        local_max = np.nanmax(curve)
        if global_min is None or global_min < local_min:
            global_min = local_min
        if global_max is None or global_max < local_max:
            global_max = local_max
        if samples_max is None or samples_max < len(curve):
            samples_max = len(curve)

        ax.plot(np.arange(samples_max), curve)
        ax.set_ylabel(label)
        ax.grid(True)

    if y_min is not None:
        global_min = y_min

    for ax in axes:
        ax.set_ylim(global_min, global_max * 1.1)

    axes[-1].set_xlabel("Sample index")
    fig.suptitle(title, fontsize=14)
    plt.tight_layout(rect=[0, 0, 1, 0.97])
    if output_filename is None:
        plt.show()
    else:
        plt.savefig(output_filename)


def main(traces):
    # set pastel ^^
    pastel_cmap = plt.get_cmap("Set3")
    plt.rcParams["axes.prop_cycle"] = plt.cycler(color=pastel_cmap.colors)

    plt.figure(figsize=(12, 5))
    for i, t in enumerate(traces):
        plt.plot(t, label=f"trace {start+i}")

    plt.title(f"Traces {start} to {end-1}")
    plt.xlabel("Sample")
    plt.ylabel("Amplitude")
    plt.legend()
    plt.tight_layout()
    plt.savefig("traces.png")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Plot traces from H5 file.")
    parser.add_argument("-f", "--file", required=True, help="Path to traces .h5 file.")
    parser.add_argument("-n", "--num", required=True, type=int, help="Number of traces to plot.")
    parser.add_argument("-o", "--offset", default=0, type=int, help="Start offset.")
    args = parser.parse_args()

    with h5py.File(args.file, "r") as file_handler:
        start = args.offset
        end = args.offset + args.num

        try:
            dataset = file_handler["em_curves"]
        except:
            try:
                dataset = file_handler["subtraces"]
            except:
                print(f"Error: .h5 file {args.file} does not contain any dataset with trace(s) to plot. Exiting ...")
                sys.exit(-1)

        if end > dataset.shape[0]:
            print(
                f"[ERROR] Requested traces {start}..{end-1}, "
                f"but file contains only {traces.shape[0]}.",
                file=sys.stderr,
            )
            sys.exit(1)

        # set pastel ^^
        pastel_cmap = plt.get_cmap("Set3")
        plt.rcParams["axes.prop_cycle"] = plt.cycler(color=pastel_cmap.colors)
        plot_global(
            curves={
                f"trace_{i}": dataset[i] for i in range(start, end)
            },
            output_filename="traces.png",
            show_max=False,
            title=f"Traces {start} to {end-1}",
            figsize=(12, 5),
        )
