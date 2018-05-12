__precompile__()
module GLPlotting

using
    PyPlot,
    PyCall,
    GLTimeseries,
    GLUtilities,
    MappedArrays,
    DSP

const prp = PyNULL()

function __init__()
    copy!(prp, pyimport("py_resizeable_plots.resizeable_artists"))
end

export
    # Functions
    downsamp_patch,
    plot_spacing,
    plot_offsets,
    plot_vertical_spacing,
    resizeable_spectrogram

include("util.jl")
include("resizeableartists.jl")
include("downsampplot.jl")
include("verticallyspaced.jl")
include("spectrogram.jl")

end # module
