"""
Base type for resizeable artists, must implement a setdata method and have a
baseinfo field"
"""
abstract type ResizeableArtist{E<:DynamicDownsampler} end

mutable struct RABaseInfo
    ax::PyObject
    artists::Vector{PyObject}
    datalimx::NTuple{2, Float64}
    datalimy::NTuple{2, Float64}
    threshdiff::Float64
    lastlimwidth::Float64
    lastlimcenter::Float64

    function RABaseInfo(
    ax::PyObject,
    artists::Vector{PyObject},
    datalimx::NTuple{2, Float64},
    datalimy::NTuple{2, Float64},
    threshdiff::Float64 = 0.0,
    lastlimwidth::Float64 = 0.0,
    lastlimcenter::Float64 = 0.0
)
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
    ax::PyObject,
    a::AbstractVector{PyObject},
    limx::NTuple{2, Real},
    limy::NTuple{2, Real}
)
    return RABaseInfo(
        ax,
        a,
        convert(NTuple{2, Float64}, limx),
        convert(NTuple{2, Float64}, limy)
    )
end

function RABaseInfo(ax::PyObject, artist::PyObject, args...)
    return RABaseInfo(ax, [artist], args...)
end

abstract type ParallelSpeed end
struct ParallelFast <: ParallelSpeed end
struct ParallelSlow <: ParallelSpeed end

ParallelSpeed(::Type) = ParallelSlow()
ParallelSpeed(::D) where {D} = ParallelSpeed(D)

function ParallelSpeed(
    ::Type{D}
) where {E<:DynamicDownsampler, D<:ResizeableArtist{E}}
    ParallelSpeed(E)
end

function ParallelSpeed(::Type{M}) where {S, D, M<:MappedDynamicDownsampler{S, D}}
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
    a.baseinfo.ax[:set_ylim]([a.baseinfo.datalimy...])
    a.baseinfo.ax[:set_xlim]([a.baseinfo.datalimx...])
end

ratiodiff(a, b) = abs(a - b) / (b + eps(b))

function artist_is_visible(ra::ResizeableArtist, xstart, xend, ystart, yend)
    xoverlap = check_overlap(
        xstart, xend, ra.baseinfo.datalimx[1], ra.baseinfo.datalimx[2]
    )
    yoverlap = check_overlap(
        ystart, yend, ra.baseinfo.datalimy[1], ra.baseinfo.datalimy[2]
    )
    return xoverlap && yoverlap
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

function maybe_redraw(ra::ResizeableArtist, xstart, xend, px_width)
    limwidth = xend - xstart
    limcenter = (xend + xstart) / 2
    if artist_should_redraw(ra, xstart, xend, limwidth, limcenter)
        ra.baseinfo.lastlimwidth = limwidth
        ra.baseinfo.lastlimcenter = limcenter
        update_plotdata(ra, xstart, xend, px_width)
        ra.baseinfo.ax[:figure][:canvas][:draw_idle]()
    end
end

function update_plotdata(ra::ResizeableArtist, xstart, xend, pixwidth)
    ds = downsampler(ra)
    data = make_plotdata(ds, xstart, xend, pixwidth)
    update_artists(ra, data...)
end

function update_plotdata(
    ras::Vector{<:ResizeableArtist},
    xstart,
    xend,
    pixwidth,
    jobchannel::RemoteChannel,
    datachannel::RemoteChannel,
    ::AbstractVector{ParallelSlow}
)
    for ra in ras
        update_plotdata(ra, xstart, xend, pixwidth)
    end
end

function update_artists end

function update_plotdata(
    ras::Vector{<:ResizeableArtist},
    xstart,
    xend,
    pixwidth,
    jobchannel::RemoteChannel,
    datachannel::RemoteChannel,
    ::AbstractVector{ParallelFast}
)
    na = length(ras)
    func_calls = Vector{FuncCall}(na)
    @. func_calls = plotdata_fnc(
        downsampler(ras), xstart, xend, pixwidth
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

function plotdata_fnc(cdts::D, xstart, xend, pixwidth) where {D<:DynamicDownsampler}
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
) where {T, A, D<:CachingDynamicTs{T, A}, S, M<:MappedDynamicDownsampler{S, D}}
    xpt, ypt = remote_make_plotdata(xstart, xend, pixwidth, D, args_base...)
    ymapped = mapfnc(ypt)
    return (xpt, ymapped)
end
