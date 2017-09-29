function plot_vertical_spacing(
    ax::PyObject,
    As::A,
    fss::AbstractVector,
    offsets::AbstractVector = [],
) where {E<:AbstractVector, A<:AbstractVector{E}}
    na = length(As)
    if isempty(offsets)
        offsets = zeros(na)
    end
    xbounds = duration.(As, fss, offsets)
    ybounds = extrema.(As)
    extents = map((x) -> x[2] - x[1], ybounds)
    if na > 1
        y_spacing = plot_spacing(extents)
    else
        y_spacing = 0
    end
    y_offsets = plot_offsets(na, y_spacing)
    transforms = Vector{Function}(na)
    for (i, offset) in enumerate(y_offsets)
        transforms[i] = (x) -> x + y_offsets[i]
    end
    mappedybounds = map((x, y) -> map((z) -> z + y, x), ybounds, y_offsets)
    Ys = mappedarray.(transforms, As)
    dts = CachingDynamicTs.(Ys, fss, offsets)
    cbs = make_cb.(dts)
    indicies = mod.(0:(na - 1), 10) # for Python consumption, base zero
    colorargs = ["C$n" for n in indicies]
    artists = downsamp_patch.(ax, cbs, xbounds, mappedybounds, colorargs)
    min_x = mapreduce((x) -> x[1], min, Inf, xbounds)
    max_x = mapreduce((x) -> x[2], max, -Inf, xbounds)
    min_y = mappedybounds[1][1] - y_spacing * 0.1
    max_y = mappedybounds[end][2] + y_spacing * 0.1
    multi_xlim = [min_x, max_x]
    multi_ylim = [min_y, max_y]
    return (artists, multi_xlim, multi_ylim, dts, cbs)
end

function plot_pmap_vertical_spacing(
    ax::PyObject,
    As::A,
    fss::AbstractVector,
    offsets::AbstractVector = [],
) where {E<:AbstractVector, A<:AbstractVector{E}}
    na = length(As)
    if isempty(offsets)
        offsets = zeros(na)
    end
    xbounds = duration.(As, fss, offsets)
    ybounds = extrema.(As)
    extents = map((x) -> x[2] - x[1], ybounds)
    if na > 1
        y_spacing = plot_spacing(extents)
    else
        y_spacing = 0
    end
    y_offsets = plot_offsets(na, y_spacing)
    transforms = Vector{Function}(na)
    for (i, offset) in enumerate(y_offsets)
        transforms[i] = (x) -> x + y_offsets[i]
    end
    mappedybounds = map((x, y) -> map((z) -> z + y, x), ybounds, y_offsets)
    Ys = mappedarray.(transforms, As)

    # PMAP section
    pout = pmap(scavenger, Ys, fss, offsets)
    cachepaths = Vector{Vector{String}}(na)
    cachelengths = Vector{Vector{Int}}(na)
    for (i, out) in enumerate(pout)
        (cachepaths[i], cachelengths[i]) = out
    end

    # Gather results of PMAP
    dts = CachingDynamicTs.(Ys, fss, offsets, cachepaths, cachelengths)

    # proceed as normal
    cbs = make_cb.(dts)
    indicies = mod.(0:(na - 1), 10) # for Python consumption, base zero
    colorargs = ["C$n" for n in indicies]
    artists = downsamp_patch.(ax, cbs, xbounds, mappedybounds, colorargs)
    min_x = mapreduce((x) -> x[1], min, Inf, xbounds)
    max_x = mapreduce((x) -> x[2], max, -Inf, xbounds)
    min_y = mappedybounds[1][1] - y_spacing * 0.1
    max_y = mappedybounds[end][2] + y_spacing * 0.1
    multi_xlim = [min_x, max_x]
    multi_ylim = [min_y, max_y]
    return (artists, multi_xlim, multi_ylim, dts, cbs)
end

function scavenger(
    y::AbstractArray,
    f::Real,
    o::Real,
    sizehint::Integer = 300
)
    return scavenge_cache(CachingDynamicTs(y, f, o, sizehint, false))
end
