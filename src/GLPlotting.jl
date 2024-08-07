__precompile__()
module GLPlotting

using
    Compat,
    PyQtGraph,
    PyPlot,
    PyCall,
    GLTimeseries,
    GLUtilities,
    Missings,
    PointProcesses,
    ArgCheck

@static if VERSION >= v"0.7.0-DEV.2575"
    using Distributed, Statistics
end

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
    DownsampCurve,
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
    glbar,
    glstem_zeros!,
    glstem!,
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


const DownsampCurve = PyNULL()
const DownsampImage = PyNULL()
const py_gc = PyNULL()
const mpl = PyNULL()

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
    # Create pyqtgraph subclasses used by this package
    temp_downsampcurve =
        PyCall.@pydef_object mutable struct DownsampCurve <: pg.PlotCurveItem
            function __init__(
                self::PyObject,
                resizeablePatch::ResizeableArtist,
                args...;
                kwargs...
            )
                self.resizeablePatch = resizeablePatch
                pg.PlotCurveItem.__init__(self, args...; kwargs...)
            end

            function viewRangeChanged(self::PyObject, args...)
                axis_lim_changed(self.resizeablePatch)
            end
        end
    copy!(DownsampCurve, temp_downsampcurve)

    temp_downsampimage =
        PyCall.@pydef_object mutable struct DownsampImage <: pg.ImageItem
            function __init__(
                self::PyObject,
                resizeableSpec::ResizeableSpec,
                args...;
                kwargs...
            )
                self.resizeableSpec = resizeableSpec
                pg.ImageItem.__init__(self, args...; kwargs...)
            end

            function viewRangeChanged(self::PyObject, args...)
                axis_lim_changed(self.resizeableSpec)
            end
        end
    copy!(DownsampImage, temp_downsampimage)

    copy!(mpl, pyimport("matplotlib"))
    grayalpha = mpl.colors.LinearSegmentedColormap.from_list(
        "grayalpha",
        [(0,0,0,0), (0,0,0,1)]
    )
    mpl.colormaps.register(grayalpha, name="grayalpha")

    copy!(py_gc, pyimport("gc"))
end

end # module
