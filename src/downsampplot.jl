"""
    downsamp_patch

Plot a signal as two lines and a fill_between polygon
"""
function downsamp_patch(
    ax::A,
    args...;
    listen_ax::Vector{A} = [ax],
    toplevel::Bool = true,
    kwargs...
) where {A<:Axis}
    rpatch = ResizeablePatch(ax, args...; kwargs...)
    connect_callbacks(ax, rpatch, listen_ax; toplevel = toplevel)
    return rpatch
end

def_colorargs(::Nothing, indices) = ["C$n" for n in indices]
def_colorargs(v::AbstractVector, ::Any) = v
def_colorargs(v, indices) = fill(v, length(indices))

"""
    plot_multi_patch

Plot a list of DownSampler objects
"""
function plot_multi_patch(
    ax::A,
    dts::AbstractVector{T},
    listen_ax::Vector{A} = [ax];
    toplevel = true,
    colorargs = nothing,
    plotkwargs...
) where {P<:PlotLib, A<:Axis{P}, T<:AbstractDynamicDownsampler}
    na = length(dts)
    indices = mod.(0:(na - 1), 10) # for Python consumption, base zero
    colorargs = def_colorargs(colorargs, indices)
    @compat patchartists = Vector{ResizeablePatch{T,P}}(undef, na)
    for i in 1:na
        patchartists[i] = downsamp_patch(ax, dts[i]; color = colorargs[i],
                                         plotkwargs...)
    end
    ad = ArtDirector(patchartists)
    connect_callbacks(ax, ad, listen_ax; toplevel = toplevel)
    if toplevel
        xbs = xbounds.(patchartists)
        ybs = ybounds.(patchartists)
        global_x = extrema_red(xbs)
        global_y = extrema_red(ybs)
        setlims(ax, global_x..., global_y...)
    end
    return ad, patchartists
end

struct ResizeablePatch{T<:AbstractDynamicDownsampler, P<:PlotLib} <: ResizeableArtist{T,P}
    dts::T
    baseinfo::RABaseInfo{P}
    exact::Bool
    function ResizeablePatch{T,P}(dts::T, baseinfo::RABaseInfo{P}, exact::Bool) where
        {T<:AbstractDynamicDownsampler, P<:MPL}
        new(dts, baseinfo, exact)
    end
    function ResizeablePatch{T,P}(dts::T, baseinfo::RABaseInfo{P}, exact::Bool) where
        {T<:AbstractDynamicDownsampler, P<:PQTG}
        r = new(dts, baseinfo, exact)
        push!(r.baseinfo.artists, Artist{P}(DownsampCurve(r)))
        return r
    end
end


function ResizeablePatch(dts::T, ra::R, exact::Bool = false) where
    {T<:AbstractDynamicDownsampler,P,R<:RABaseInfo{P}}
    ResizeablePatch{T,P}(dts, ra, exact)
end

function ResizeablePatch(
    dts::AbstractDynamicDownsampler, args...;
    exact::Bool = false, kwargs...
)
    return ResizeablePatch(dts, RABaseInfo(args...; kwargs...), exact)
end

function ResizeablePatch(
    ax::Axis{P}, dts::AbstractDynamicDownsampler, args...;
    exact::Bool = false, plotargs::Vector{Any} = [], plotkwargs...
) where {P<:PQTG}
    xbounds = time_interval(dts)
    ybounds = extrema(dts)
    artists = Vector{Artist{P}}()
    return ResizeablePatch(dts, ax, artists, xbounds, ybounds; exact=exact)
end

function ResizeablePatch(
    ax::Axis{P},
    dts::AbstractDynamicDownsampler,
    args...;
    exact::Bool = false,
    plotargs::Vector{Any} = [],
    plotkwargs...
) where {P<:MPL}
    plotline = make_dummy_line(ax, plotargs...; plotkwargs...)
    artists = [plotline]
    return ResizeablePatch(
        dts, ax, artists, time_interval(dts), extrema(dts); exact=exact
    )
end

function ResizeablePatch(
    ax::Axis,
    a::AbstractVector,
    fs,
    offset = zero(fs),
    args...;
    exact::Bool = false,
    plotargs::Vector{Any} = [],
    plotkwargs...
)
    dts = CacheAccessor(MaxMin, a, fs, offset, 1000)
    return ResizeablePatch(
        ax, dts, args...;
        exact=exact, plotargs=plotargs, plotkwargs...
    )
end

downsampler(r::ResizeablePatch) = r.dts

function fill_points(
    xs::A, ys::B, was_downsampled::Bool
) where {
    X<:Number,
    A<:AbstractVector{X},
    Y<:Number,
    T<:NTuple{2, Y},
    B<:AbstractVector{T}
}
    if was_downsampled
        npt = 2 * length(xs)
        @compat xpts = Vector{X}(undef, npt)
        @compat ypts = Vector{Y}(undef, npt)
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

update_args(ra::ResizeablePatch) = (ra.exact,)

function make_plotdata(
    dts::AbstractDynamicDownsampler{<:NTuple{2, <:Number}},
    xstart,
    xend,
    pixwidth,
    res,
    exact
)
    fill_points(downsamp_req(dts, xstart, xend, pixwidth, exact, Int32)...)
end

function update_artists(ra::ResizeablePatch{<:Any,MPL}, xpt, ypt)
    ra.baseinfo.artists[1].artist.set_data(xpt, ypt)
end

function update_artists(ra::ResizeablePatch{<:Any,PQTG}, xpt, ypt)
    ra.baseinfo.artists[1].artist.setData(xpt, ypt)
end

"Make a line with place-holder data"
function make_dummy_line(
    ax::A, plotargs...;
    name = nothing,
    plotkwargs...
) where
    {P<:MPL, A<:Axis{P}}
    label_karg = ifelse(
        name == nothing,
        Dict{Symbol, String}(),
        Dict(:label => name)
    )
    return Artist{P}(
        ax.ax.plot(0, 0, plotargs...; label_karg..., plotkwargs...)[1]
    )
end
