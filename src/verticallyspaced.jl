"""
    plot_vertical_spacing

plot a vector of signals with equal y-spacing between them.

    The spacing between signals is calculated from y-extent of the signals.
    """
function plot_vertical_spacing(
    ax::B,
    ts::A;
    listen_ax::Vector{B} = [ax],
    y_spacing::Real = -1, # automatic if less than zero
    linewidth::Number = 2,
    toplevel::Bool = true,
    colorargs = nothing,
) where {B<:Axis,E,D<:AbstractDynamicDownsampler{E},A<:AbstractVector{D}}
    nts = length(ts)
    if y_spacing < 0
        if nts > 1
            extents = extrema.(ts)
            y_spacing = plot_spacing(extents)
        else
            y_spacing = 0
        end
    end
    y_offsets = plot_offsets(nts, y_spacing)
    mts = Vector{MappedDynamicDownsampler{E,D}}(undef, nts)
    for (i, offset) in enumerate(y_offsets)
        y_transform = make_shifter(offset)
        mts[i] = MappedDynamicDownsampler(ts[i], y_transform)
    end
    ad, patchartists = plot_multi_patch(
        ax,
        mts,
        listen_ax;
        linewidth = linewidth,
        toplevel = false,
        colorargs,
    )
    if toplevel
        xb = extrema_red(time_interval.(mts))
        yb = (extrema(mts[1])[1], extrema(mts[end])[2])
        y_expansion = y_spacing * 0.1
        expanded_ybounds = (yb[1] - y_expansion, yb[2] + y_expansion)
        setlims(ax, xb..., expanded_ybounds...)
    end
    return ad, patchartists, y_offsets
end

function plot_vertical_spacing(
    ax::Axis,
    As::A,
    fss::AbstractVector{<:Real},
    offsets::AbstractVector = [],
    args...;
    kwargs...,
) where {E<:Number,B<:AbstractVector{E},A<:AbstractVector{B}}
    plot_offs = isempty(offsets) ? zeros(E, length(As)) : offsets
    dts = CacheAccessor.(MaxMin, As, fss, plot_offs)
    return plot_vertical_spacing(ax, dts, args...; kwargs...)
end

function plot_vertical_spacing(
    ax::Axis,
    As::AbstractVector{<:AbstractVector{<:Number}},
    fs::Number,
    args...;
    kwargs...,
)
    plot_vertical_spacing(ax, As, fill(fs, size(As)), args...; kwargs...)
end
