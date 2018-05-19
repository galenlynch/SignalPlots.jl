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
    end
    ad = ArtDirector(patchartists)
    connect_callbacks(ax, ad, listen_ax; toplevel = toplevel)
    if toplevel
        xbs = xbounds.(patchartists)
        ybs = ybounds.(patchartists)
        global_x = extrema_red(xbs)
        global_y = extrema_red(ybs)
        ax[:set_ylim]([global_y...])
        ax[:set_xlim]([global_x...])
    end
    return ad, patchartists
end

struct ResizeablePatch{T<:DynamicDownsampler} <: ResizeableArtist{T}
    dts::T
    baseinfo::RABaseInfo
end
downsampler(r::ResizeablePatch) = r.dts
baseinfo(r::ResizeablePatch) = r.baseinfo

function ResizeablePatch(dts::DynamicDownsampler, args...; kwargs...)
    return ResizeablePatch(dts, RABaseInfo(args...; kwargs...))
end
function ResizeablePatch(
    ax::PyObject,
    dts::DynamicDownsampler,
    args...;
    plotargs::Vector{Any} = [],
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
    plotargs::Vector{Any} = [],
    plotkwargs...
)
    dts = CachingDynamicTs(a, fs, offset, 1000)
    return ResizeablePatch(ax, dts, args...; plotargs=plotargs, plotkwargs...)
end

function fill_points(
    xs::A, ys::B, was_downsampled::Bool
) where {X<:Number, A<:AbstractVector{X}, Y<:Number, T<:NTuple{2, Y}, B<:AbstractVector{T}}
    if was_downsampled
        npt = 2 * length(xs)
        xpts = Vector{X}(npt)
        ypts = Vector{Y}(npt)
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
        xpts = convert(Vector{X}, xs)
        ypts = Y[y[1] for y in ys]
    end
    return (xpts, ypts)
end

function make_plotdata(
    dts::DynamicDownsampler{<:NTuple{2, <:Number}}, xstart, xend, pixwidth
)
    fill_points(downsamp_req(dts, xstart, xend, pixwidth)...)
end

function update_artists(ra::ResizeablePatch, xpt, ypt)
    ra.baseinfo.artists[1][:set_data](xpt, ypt)
end

"Make a line with place-holder data"
function make_dummy_line(ax::PyObject, plotargs...; plotkwargs...)
    return ax[:plot](0, 0, plotargs...; plotkwargs...)[1]::PyObject
end
