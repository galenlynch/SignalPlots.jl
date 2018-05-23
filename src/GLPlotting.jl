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
const DownsampCurve = PyNULL()

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
    temp_downsampcurve =
        PyCall.@pydef_object mutable struct DownsampCurve <: pg[:PlotCurveItem]
            function __init__(
                self,
                resizeableArtist::ResizeableArtist,
                args...;
                kwargs...
            )
                self[:resizeableArtist] = resizeableArtist
                pg[:PlotCurveItem][:__init__](self,args...;kwargs...)
            end

            function viewRangeChanged(self::PyObject, args...)
                axis_lim_changed(self[:resizeableArtist])
            end
        end
    copy!(DownsampCurve, temp_downsampcurve)
end

end # module
