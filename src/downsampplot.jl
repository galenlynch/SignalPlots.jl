function make_dummy_line(ax::PyObject, plotargs...; plotkwargs...)
    return ax[:plot](0, 0, plotargs...; plotkwargs...)[1]
end
function make_dummy_line(ax::PyObject, l::PyObject, args...; kwargs...)
    lineout = make_dummy_line(ax, args...; kwargs...)
    lineout[:update_from](l)
    return lineout
end
function make_dummy_line(n::Integer, ax::PyObject, args...; kwargs...)
    plots = Vector{PyObject}(n)
    if n > 0
        plots[1] = make_dummy_line(ax, args...; kwargs...)
    end
    if n > 1
        for i in 2:n
            plots[i] = make_dummy_line(ax, plots[1], args..., kwargs...)
        end
    end
    return plots
end

function make_fill(
    ax::PyObject,
    lowline::PyObject,
    highline::PyObject,
    match::Bool = true,
    alpha::AbstractFloat = 0.5,
    args...;
    kwargs...
)
    (lowx, lowy) = lowline[:get_data]()
    (highx, highy) = highline[:get_data]()
    @assert lowx == highx "inputs lines must share the same x points"
    p = ax[:fill_between](lowx, lowy, highy, args...; alpha = alpha, kwargs...)
    if match
        p[:set_facecolors](lowline[:get_color]())
    end
    return p
end

function to_patch_plot_coords(
    xs::AbstractVector,
    ys::A
) where {E<:Real, N, S<:NTuple{N, E}, A<:AbstractVector{S}}
    ny = length(ys)
    outs = ntuple((i) -> (xs, Vector{E}(ny)), N)
    for (y_ndx, y_group) in enumerate(ys)
        for series_no in 1:N
            outs[series_no][2][y_ndx] = y_group[series_no]
        end
    end
    return outs
end

"Used for make a callback to view data that does not require the data"
function make_cb(dts::DynamicDownsampler)
    return (xb, xe, ptmax) -> to_patch_plot_coords(downsamp_req(dts, xb, xe, ptmax)...)
end
function make_cb(
    a::AbstractVector,
    fs::Real,
    offset::Real = 0,
    sizehint::Integer = 1000
)
    dts = CachingDynamicTs(a, fs, offset, 1000)
    dts = DynamicTs(a, fs, offset)
    return make_cb(dts)
end

function downsamp_patch(
    ax::PyObject,
    cb::Function,
    xbounds::NTuple{2, I},
    ybounds::NTuple{2, I},
    plotlines::Vector{PyObject},
    plotpatch::PyObject,
    listen_ax::Vector{PyObject} = [ax]
) where I <: Real
    ax[:set_autoscale_on](false)
    artists = push!(plotlines, plotpatch)
    rartist = prp[:ResizeablePatch](ax, cb, artists, xbounds, ybounds) # graph objects must be vector
    println(listen_ax)
    for lax in listen_ax
        lax[:callbacks][:connect]("xlim_changed", rartist[:update])
        lax[:callbacks][:connect]("ylim_changed", rartist[:update])
    end
    return rartist
end
function downsamp_patch(
    ax::PyObject,
    cb::Function,
    xbounds::NTuple{2, I},
    ybounds::NTuple{2, I},
    listen_ax::Vector{PyObject} = [ax],
    plotargs...;
    plotkwargs...
) where I <: Real
    plotlines = make_dummy_line(2, ax, plotargs...; plotkwargs...)
    plotpatch = make_fill(ax, plotlines...)
    return downsamp_patch(ax, cb, xbounds, ybounds, plotlines, plotpatch, listen_ax)
end
function downsamp_patch(
    ax::PyObject,
    a::AbstractVector,
    fs::Real,
    offset::Real = 0,
    listen_ax::Vector{PyObject} = [ax],
    args...;
    kwargs...
)
    cb = make_cb(a, fs, offset)
    xbounds = duration(a, fs, offset)
    ybounds = extrema(a)
    downsamp_patch(ax, cb, xbounds, ybounds, listen_ax, args...; kwargs...)
end
