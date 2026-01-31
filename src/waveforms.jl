function waveform_overlapped_plot(ax::Py, args...; kwargs...)
    lc, basis = waveform_overlapped_collection(ax, args...; kwargs...)
    ax.add_collection(lc)
    ax.set_xlim([basis[1], basis[end]])
    ax.autoscale(axis = "y")
    lc
end

function waveform_overlapped_collection(
    spk_clips::AbstractVector{<:AbstractVector{<:Number}},
    fs::Number,
    basis::Union{Nothing,AbstractRange,AbstractVector} = nothing;
    basis_conversion::Number = 1000,
    color = (0, 0, 0, 0.1),
    linewidths = 0.3,
    plot_kwargs::Dict{Symbol,Any} = Dict{Symbol,Any}(),
)
    nspk = length(spk_clips)
    nspk > 0 || throw(ArgumentError("spk_clips must not be empty"))
    if ! allsame(length, spk_clips)
        throw(ArgumentError("Length of spike clips must be identical"))
    end
    n_support = length(spk_clips[1])
    if isnothing(basis)
        half_support = fld(n_support, 2)
        basis = basis_conversion * ((-half_support):1:half_support) / fs
    end
    spk_points = make_lc_coords(basis, spk_clips)
    lc = PythonPlot.matplotlib.collections.LineCollection(
        spk_points;
        color = color,
        linewidths = linewidths,
        plot_kwargs...,
    )
    lc, basis
end
