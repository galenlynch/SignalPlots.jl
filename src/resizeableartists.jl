"""
Base type for resizeable artists, must implement a setdata method and have a
baseinfo field"
"""
abstract type ResizeableArtist{E<:AbstractDynamicDownsampler, P<:PlotLib} end

mutable struct RABaseInfo{P<:PlotLib}
    ax::Axis{P}
    artists::Vector{Artist{P}}
    datalimx::NTuple{2, Float64}
    datalimy::NTuple{2, Float64}
    threshdiff::Float64
    lastlimwidth::Float64
    lastlimcenter::Float64

    function RABaseInfo{P}(
    ax::Axis{P},
    artists::Vector{Artist{P}},
    datalimx::NTuple{2, Float64},
    datalimy::NTuple{2, Float64},
    threshdiff::Float64 = 0.0,
    lastlimwidth::Float64 = 0.0,
    lastlimcenter::Float64 = 0.0
) where P<:PlotLib
        return new(
            ax,
            artists,
            datalimx,
            datalimy,
            threshdiff,
            lastlimwidth,
            lastlimcenter
        )
    end
end

function RABaseInfo(
    ax::Axis{P},
    a::AbstractVector{Artist{P}},
    limx::NTuple{2, Real},
    limy::NTuple{2, Real}
) where P<:PlotLib
    return RABaseInfo{P}(
        ax,
        a,
        convert(NTuple{2, Float64}, limx),
        convert(NTuple{2, Float64}, limy)
    )
end

function RABaseInfo(ax::Axis{P}, artist::Artist{P}, args...) where P<:PlotLib
    return RABaseInfo(ax, [artist], args...)
end

abstract type ParallelSpeed end
struct ParallelFast <: ParallelSpeed end
struct ParallelSlow <: ParallelSpeed end

ParallelSpeed(::Type) = ParallelSlow()
ParallelSpeed(::D) where {D} = ParallelSpeed(D)

function ParallelSpeed(
    ::Type{D}
) where {E<:AbstractDynamicDownsampler, D<:ResizeableArtist{E}}
    ParallelSpeed(E)
end

function ParallelSpeed(::Type{M}) where {D, M<:MappedDynamicDownsampler{<:Any, D}}
    return ParallelSpeed(D)
end

struct FuncCall{A<:Tuple}
    f::Function
    args::A
    kwargs::Vector{Any}
end
function FuncCall(f::Function, args...; kwargs...)
    FuncCall{typeof(args)}(f, args, kwargs)
end
call(fc::FuncCall) = fc.f(fc.args...; fc.kwargs...)

xbounds(a::RABaseInfo) = a.datalimx
ybounds(a::RABaseInfo) = a.datalimy

xbounds(a::ResizeableArtist) = xbounds(a.baseinfo)
ybounds(a::ResizeableArtist) = ybounds(a.baseinfo)

function set_ax_home(a::ResizeableArtist)
    setlims(a.baseinfo.ax, a.baseinfo.datalimx..., a.baseinfo.datalimy...)
end

ratiodiff(a, b) = abs(a - b) / (b + eps(b))

function artist_is_visible(xb, xe, yb, ye, vxb, vxe, vyb, vye)
    xoverlap = check_overlap(xb, xe, vxb, vxe)
    yoverlap = check_overlap(yb, ye, vyb, vye)
    return xoverlap && yoverlap
end

function artist_is_visible(ra::ResizeableArtist, xstart, xend, ystart, yend)
    limx = ra.baseinfo.datalimx
    limy = ra.baseinfo.datalimy
    return artist_is_visible(
        xstart, xend, ystart, yend,
        limx[1], limx[2], limy[1], limy[2]
    )
end

function artist_should_redraw(
    ra::ResizeableArtist,
    xstart,
    xend,
    limwidth = xend - xstart,
    limcenter = (xend + xstart) / 2
)
    (ystart, yend) = axis_ylim(ra.baseinfo.ax)
    if artist_is_visible(ra, xstart, xend, ystart, yend)
        width_rd = ratiodiff(limwidth, ra.baseinfo.lastlimwidth)
        center_rd = ratiodiff(limcenter, ra.baseinfo.lastlimcenter)
        redraw = max(width_rd, center_rd) > ra.baseinfo.threshdiff
    else
        redraw = false
    end
    return redraw
end

function maybe_redraw(ra::ResizeableArtist, xstart, xend, px_width::Integer)
    limwidth = xend - xstart
    limcenter = (xend + xstart) / 2
    if artist_should_redraw(ra, xstart, xend, limwidth, limcenter)
        ra.baseinfo.lastlimwidth = limwidth
        ra.baseinfo.lastlimcenter = limcenter
        npx = compress_px(ra, xstart, xend, px_width)
        update_plotdata(ra, xstart, xend, npx)
        update_ax(ra.baseinfo.ax)
    end
end

function compress_px(
    ra::ResizeableArtist, xstart, xend, px_width::T
) where {T<:Integer}
    (xb, xe) = ra.baseinfo.datalimx
    if xb > xstart || xe < xend
        x_s_b = max(xb, xstart)
        x_e_b = min(xe, xend)
        compression = (x_e_b - x_s_b) / (xend - xstart)
        px_out = ceil(T, px_width * compression)
    else
        px_out = px_width
    end
    return px_out
end

function update_plotdata(ra::ResizeableArtist, xstart, xend, pixwidth)
    ds = downsampler(ra)
    args = update_args(ra)
    data = make_plotdata(ds, xstart, xend, pixwidth, args...)
    update_artists(ra, data...)
end

update_args(::ResizeableArtist) = ()

function update_plotdata(
    ras::Vector{<:ResizeableArtist},
    xstart,
    xend,
    pixwidths,
    jobchannel::RemoteChannel,
    datachannel::RemoteChannel,
    ::AbstractVector{ParallelSlow},
)
    for (i, ra) in enumerate(ras)
        update_plotdata(ra, xstart, xend, pixwidths[i])
    end
end

function update_artists end

function update_plotdata(
    ras::Vector{<:ResizeableArtist},
    xstart,
    xend,
    pixwidths,
    jobchannel::RemoteChannel,
    datachannel::RemoteChannel,
    ::AbstractVector{ParallelFast}
)
    na = length(ras)
    func_calls = Vector{FuncCall}(na)
    @. func_calls = plotdata_fnc(
        downsampler(ras), xstart, xend, pixwidths
    )
    for job in enumerate(func_calls)
        put!(jobchannel, job)
    end
    n = length(ras)
    while n > 0
        job_id, xs, ys = take!(datachannel)
        update_artists(ras[job_id], xs, ys)
        n = n - 1
    end
end

function plotdata_fnc(cdts::D, xstart, xend, pixwidth) where {D<:AbstractDynamicDownsampler}
    args = remote_plotdata_args(cdts)
    return FuncCall(
        remote_make_plotdata,
        xstart, xend, pixwidth, D, args...
    )
end

function remote_plotdata_args(mds::MappedDynamicDownsampler)
    args_base = remote_plotdata_args(mds.downsampler)
    return (mds.fmap, args_base)
end

function remote_make_plotdata(
    xstart, xend, pixwidth,
    ::Type{M}, mapfnc, args_base
) where {D<:AbstractDynamicDownsampler, M<:MappedDynamicDownsampler{<:Any, D}}
    xpt, ypt = remote_make_plotdata(xstart, xend, pixwidth, D, args_base...)
    ymapped = mapfnc(ypt)
    return (xpt, ymapped)
end
