module SignalPlots

using ArgCheck: ArgCheck, @argcheck
using Distributed: Distributed, RemoteChannel, remote_do, workers
using DynamicTimeseries: DynamicTimeseries, AbstractDynamicDownsampler,
                         AbstractDynamicSpectrogram, CacheAccessor,
                         DynCachingStftPsd, DynamicPointBoxer,
                         DynamicPointDownsampler, MappedDynamicDownsampler,
                         MaxMin, downsamp_req, extent, make_shifter, time_interval
using EventIntervals: EventIntervals, Interval, Points, VariablePoints, bounds
using SignalIndices: allsame, ndx_wrap, stepsize
using SortedIntervals: check_overlap, extrema_red, reduce_extrema
using PyQtGraph: PyQtGraph, get_viewbox, linked_subplot_grid, pg, plotwindow,
                 qtc
using PythonCall: PythonCall, Py, pycopy!, pyconvert, pyfunc, pyimport, pylist,
                  pynew, pytuple
using PythonPlot: PythonPlot, clim, gca
using Statistics: Statistics, mean

export
    # Types
    Axis,
    Artist,
    MPL,
    PQTG,
    ParallelSpeed,
    ParallelSlow,
    ParallelFast,
    FuncCall,
    MergingPoints,

    # Functions
    add_labels,
    axis_xlim,
    axis_ylim,
    best_scalebar_size,
    convenient_plot_window,
    downsamp_patch,
    electrode_circles,
    electrode_grid,
    force_redraw,
    bar,
    stem_zeros!,
    stem!,
    histplot,
    kill_figure,
    make_lc_coords,
    make_patch_collection,
    matplotlib_scalebar,
    plot_annotated_spectrogram,
    plot_cnmfe_results!,
    plot_example_spectrogram,
    plot_offsets,
    plot_spacing,
    plot_vertical_spacing,
    plotitem_to_ax,
    point_boxes,
    point_boxes_multi,
    qt_subplots,
    raster_plot,
    remove,
    resizeable_spectrogram


const py_gc = pynew()
const mpl = pynew()
const np = pynew()

"""Convert a Julia array to a numpy ndarray for passing to pyqtgraph."""
tonumpy(x::AbstractArray) = np.asarray(x)

include("plotlibs.jl")
include("util.jl")
include("resizeableartists.jl")
include("artdirector.jl")
include("redraw.jl")
include("downsampplot.jl")
include("verticallyspaced.jl")
include("spectrogram.jl")
include("ptplot.jl")
include("plotting_util.jl")
include("plotshapes.jl")
include("rasterplot.jl")
include("histplot.jl")
include("stem.jl")
include("cnmfe.jl")
include("waveforms.jl")
include("swarm.jl")
include("gloss.jl")

function __init__()
    pycopy!(mpl, pyimport("matplotlib"))
    grayalpha = mpl.colors.LinearSegmentedColormap.from_list(
        "grayalpha",
        pylist([pytuple((0, 0, 0, 0)), pytuple((0, 0, 0, 1))]),
    )
    mpl.colormaps.register(grayalpha, name = "grayalpha")

    pycopy!(np, pyimport("numpy"))
    pycopy!(py_gc, pyimport("gc"))
end

end # module
