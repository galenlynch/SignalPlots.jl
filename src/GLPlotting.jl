__precompile__()
module GLPlotting

using
    PyPlot,
    PyCall,
    GLTimeseries,
    GLUtilities,
    MappedArrays,
    DSP

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
