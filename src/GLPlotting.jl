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
    PointProcesses

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
    downsamp_patch,
    plot_spacing,
    plot_offsets,
    plotitem_to_ax,
    plot_vertical_spacing,
    point_boxes,
    point_boxes_multi,
    resizeable_spectrogram,
    qt_subplots,
    remove,
    raster_plot,
    add_labels,
    make_patch_collection,
    matplotlib_scalebar,
    make_lc_coords,
    electrode_circles,
    force_redraw


const DownsampCurve = PyNULL()
const DownsampImage = PyNULL()

include("plotlibs.jl")
include("util.jl")
include("resizeableartists.jl")
include("artdirector.jl")
include("redraw.jl")
include("downsampplot.jl")
include("verticallyspaced.jl")
include("spectrogram.jl")
include("ptplot.jl")
include("rasterplot.jl")
include("gloss.jl")

function __init__()
    # Create pyqtgraph subclasses used by this package
    temp_downsampcurve =
        PyCall.@pydef_object mutable struct DownsampCurve <: pg[:PlotCurveItem]
            function __init__(
                self::PyObject,
                resizeablePatch::ResizeableArtist,
                args...;
                kwargs...
            )
                self[:resizeablePatch] = resizeablePatch
                pg[:PlotCurveItem][:__init__](self, args...; kwargs...)
            end

            function viewRangeChanged(self::PyObject, args...)
                axis_lim_changed(self[:resizeablePatch])
            end
        end
    copy!(DownsampCurve, temp_downsampcurve)

    temp_downsampimage =
        PyCall.@pydef_object mutable struct DownsampImage <: pg[:ImageItem]
            function __init__(
                self::PyObject,
                resizeableSpec::ResizeableSpec,
                args...;
                kwargs...
            )
                self[:resizeableSpec] = resizeableSpec
                pg[:ImageItem][:__init__](self, args...; kwargs...)
            end

            function viewRangeChanged(self::PyObject, args...)
                axis_lim_changed(self[:resizeableSpec])
            end
        end
    copy!(DownsampImage, temp_downsampimage)

    grayalpha = matplotlib[:colors][:LinearSegmentedColormap][:from_list](
        "grayalpha",
        [(0,0,0,0), (0,0,0,1)]
    )
    register_cmap("grayalpha", grayalpha)
end

end # module
