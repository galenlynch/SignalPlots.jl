__precompile__()
module GLPlotting

using
    PyPlot,
    PyCall,
    GLTimeseries,
    GLUtilities

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
    pg,
    DownsampCurve,

    # Functions
    downsamp_patch,
    plot_spacing,
    plot_offsets,
    plot_vertical_spacing,
    resizeable_spectrogram,
    get_viewbox

const pg = PyNULL()
const qtc = PyNULL()
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

function __init__()
    copy!(pg, pyimport("pyqtgraph"))
    copy!(qtc, pg[:Qt][:QtCore])

    # Create pyqtgraph subclasses used by this package
    temp_downsampcurve =
        PyCall.@pydef_object mutable struct DownsampCurve <: pg[:PlotCurveItem]
            function __init__(
                self::PyObject,
                resizeablePatch::ResizeablePatch,
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
end

end # module
