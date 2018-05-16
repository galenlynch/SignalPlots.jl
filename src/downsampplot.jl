"""
    downsamp_patch

Plot a signal as two lines and a fill_between polygon
"""
function downsamp_patch(
    ax::PyObject,
    args...;
    listen_ax::Vector{PyObject} = [ax],
    toplevel::Bool = true,
    kwargs...
)
    rpatch = ResizeablePatch(ax, args...; kwargs...)
    connect_callbacks(ax, rpatch, listen_ax; toplevel = toplevel)
    return rpatch
end

"""
    plot_multi_patch

Plot a list of DownSampler objects
"""
function plot_multi_patch(
    ax::PyObject,
    dts::AbstractVector{<:DynamicDownsampler},
    listen_ax::Vector{PyObject} = [ax];
    toplevel = true,
    plotkwargs...
)
    na = length(dts)
    indicies = mod.(0:(na - 1), 10) # for Python consumption, base zero
    colorargs = ["C$n" for n in indicies]
    patchartists = Vector{ResizeablePatch}(na)
    for i in 1:na
        patchartists[i] = downsamp_patch(ax, dts[i], colorargs[i]; plotkwargs...)
        connect_callbacks(ax, patchartists[i], listen_ax; toplevel = toplevel)
    end
    if toplevel
        xbs = xbounds.(patchartists)
        ybs = ybounds.(patchartists)
        global_x = extrema_red(xbs)
        global_y = extrema_red(ybs)
        ax[:set_ylim]([global_y...])
        ax[:set_xlim]([global_x...])
    end
    return patchartists
end

struct ResizeablePatch{T<:DynamicDownsampler} <: ResizeableArtist
    dts::T
    baseinfo::RABaseInfo
end

function ResizeablePatch(dts::DynamicDownsampler, args...; kwargs...)
    return ResizeablePatch(dts, RABaseInfo(args...; kwargs...))
end
function ResizeablePatch(
    ax::PyObject,
    dts::DynamicDownsampler,
    plotargs...;
    plotkwargs...
)
    plotline = make_dummy_line(ax, plotargs...; plotkwargs...)
    artists = [plotline]
    return ResizeablePatch(dts, ax, artists, duration(dts), extrema(dts))
end
function ResizeablePatch(
    ax::PyObject,
    a::AbstractVector,
    fs,
    offset = zero(fs),
    args...;
    kwargs...
)
    dts = CachingDynamicTs(a, fs, offset, 1000)
    return ResizeablePatch(ax, dts, args...; kwargs...)
end

function fill_points(xs, ys, was_downsampled)
    if was_downsampled
        npt = 2 * length(xs)
        xpts = Vector{Float64}(npt)
        ypts = Vector{Float64}(npt)
        for (x_i, x) in enumerate(xs) # Enumerate over input
            # Calculate the corresponding position in the output
            i = (x_i - 1) * 2 + 1
            # First two points have the same x (vertical line)
            xpts[i] = x
            xpts[i + 1] = x
            # These two points are the min and max y values
            ypts[i] = ys[x_i][1]
            ypts[i + 1] = ys[x_i][2]
        end
    else
        xpts = Vector{Float64}(xs)
        ypts = Float64[y[1] for y in ys]
    end
    return (xpts, ypts)
end

function update_plotdata(ra::ResizeablePatch, xstart, xend, pixwidth)
    (xpt, ypt) = fill_points(downsamp_req(ra.dts, xstart, xend, pixwidth)...)
    ra.baseinfo.artists[1][:set_data](xpt, ypt)
end


"Make a line with place-holder data"
function make_dummy_line(ax::PyObject, plotargs...; plotkwargs...)
    return ax[:plot](0, 0, plotargs...; plotkwargs...)[1]::PyObject
end
