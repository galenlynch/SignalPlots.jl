"""
    plot_vertical_spacing

plot a vector of signals with equal y-spacing between them.

The spacing between signals is calculated from y-extent of the signals.
"""
function plot_vertical_spacing(
    ax::PyObject,
    As::A,
    fss::AbstractVector,
    offsets::AbstractVector = [],
    listen_ax::Vector{PyObject} = [ax];
    y_spacing::Real = -1,
    linewidth::Number = 2
) where {E<:AbstractVector, A<:AbstractVector{E}}
    na = length(As)
    if isempty(offsets)
        offsets = zeros(na)
    end
    xbounds = duration.(As, fss, offsets)
    ybounds = extrema.(As)
    extents = map((x) -> x[2] - x[1], ybounds)
    if y_spacing < 0
        if na > 1
            y_spacing = plot_spacing(extents)
        else
            y_spacing = 0
        end
    end
    y_offsets = plot_offsets(na, y_spacing)
    transforms = Vector{Function}(na)
    for (i, offset) in enumerate(y_offsets)
        transforms[i] = (y) -> y + y_offsets[i]
    end
    mappedybounds = map((x, y) -> map((z) -> z + y, x), ybounds, y_offsets)
    Ys = mappedarray.(transforms, As)
    dts = CachingDynamicTs.(Ys, fss, offsets)
    patchartists = plot_multi_patch(
        ax,
        dts,
        xbounds,
        mappedybounds,
        listen_ax;
        linewidth = linewidth
    )
    min_x = mapreduce((x) -> x[1], min, Inf, xbounds)
    max_x = mapreduce((x) -> x[2], max, -Inf, xbounds)
    min_y = mappedybounds[1][1] - y_spacing * 0.1
    max_y = mappedybounds[end][2] + y_spacing * 0.1
    multi_xlim = [min_x, max_x]
    multi_ylim = [min_y, max_y]
    return (patchartists, multi_xlim, multi_ylim)
end

# Version for downsampler input
function plot_vertical_spacing(
    ax::PyObject,
    ts::A,
    listen_ax::Vector{PyObject} = [ax];
    y_spacing::Real = -1,
    linewidth::Number = 2,
    toplevel = true
) where {E<:DynamicDownsampler, A<:AbstractVector{E}}
    nts = length(ts)
    y_transforms = Vector{Function}(nts)
    mappedybounds = Vector{NTuple{2, Float64}}(nts)
    extents = Vector{Float64}(nts)
    xbounds = Vector{NTuple{2, Float64}}(nts)
    for i in 1:nts
        xbounds[i] = duration(ts[i])
        (xs, ys, was_downsamped) = downsamp_req(
            ts[i], xbounds[i][1], xbounds[i][2], 1
        )
        mappedybounds[i] = ys[1]
        extents[i] = mappedybounds[i][2] - mappedybounds[i][1]
    end
    if y_spacing < 0
        if nts > 1
            y_spacing = plot_spacing(extents)
        else
            y_spacing = 0
        end
    end
    y_offsets = plot_offsets(nts, y_spacing)
    for (i, offset) in enumerate(y_offsets)
        thisoffset = y_offsets[i]
        y_transforms[i] = make_shifter(thisoffset)
        mappedybounds[i] = (
            mappedybounds[i][1] + thisoffset,
            mappedybounds[i][2] + thisoffset
        )
    end
    mts = MappedDynamicDownsampler.(ts, y_transforms)
    (patchartists, x_bounds, y_bounds) = plot_multi_patch(
        ax, mts, xbounds, mappedybounds, listen_ax;
        linewidth = linewidth, toplevel = false
    )
    y_expansion = y_spacing * 0.1
    expanded_ybounds = (global_y[1] - y_expansion, global_y[2] + y_expansion)
    if toplevel
        ax[:set_ylim]([expanded_ybounds...])
        ax[:set_xlim]([x_bounds...])
    end
    return (patchartists, x_bounds, expanded_ybounds)
end

