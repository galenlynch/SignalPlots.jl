# functions for making downsampling plot obejcts

"Make a line with place-holder data"
function make_dummy_line end

function make_dummy_line(ax::PyObject, plotargs...; plotkwargs...)
    return ax[:plot](0, 0, plotargs...; plotkwargs...)[1]
end

"Make a line using the plot properties of an existing line"
function make_dummy_line(ax::PyObject, l::PyObject)
    lineout = make_dummy_line(ax)
    lineout[:update_from](l)
    return lineout
end

"Make multiple lines"
function make_dummy_line(n::Integer, ax::PyObject, args...; kwargs...)
    plots = Vector{PyObject}(n)
    if n > 0
        plots[1] = make_dummy_line(ax, args...; kwargs...)
    end
    if n > 1
        for i in 2:n
            plots[i] = make_dummy_line(ax, plots[1])
        end
    end
    return plots
end

"""
    downsamp_patch

Plot a signal as two lines and a fill_between polygon
"""
function downsamp_patch(
    ax::PyObject,
    dts::DynamicDownsampler,
    xbounds::NTuple{2, I},
    ybounds::NTuple{2, I},
    plotline::PyObject,
    listen_ax::Vector{PyObject} = [ax]
) where I <: Real
    artists = [plotline]
    rpatch = ResizeablePatch(dts, ax, artists, xbounds, ybounds)
    ax[:set_autoscale_on](false)
    update_fnc = (x) -> axis_xlim_changed(rpatch, x)
    for lax in listen_ax
        conn_fnc = lax[:callbacks][:connect]
        conn_fnc("xlim_changed", update_fnc)
        conn_fnc("ylim_changed", update_fnc) # TODO: Is this necessary?
    end
    ax[:set_xlim]([xbounds[1], xbounds[2]])
    ax[:set_ylim]([ybounds[1], ybounds[2]])
    return rpatch
end
function downsamp_patch(
    ax::PyObject,
    dts::DynamicDownsampler,
    xbounds::NTuple{2, I},
    ybounds::NTuple{2, I},
    listen_ax::Vector{PyObject} = [ax],
    plotargs...;
    plotkwargs...
) where I <: Real
    plotline = make_dummy_line(ax, plotargs...; plotkwargs...)
    return downsamp_patch(ax, dts, xbounds, ybounds, plotline, listen_ax)
end
function downsamp_patch(
    ax::PyObject,
    a::AbstractVector,
    fs,
    offset = zero(fs),
    listen_ax::Vector{PyObject} = [ax],
    args...;
    kwargs...
)
    dts = CachingDynamicTs(a, fs, offset, 1000)
    xbounds = duration(a, fs, offset)
    ybounds = extrema(a)
    downsamp_patch(ax, dts, xbounds, ybounds, listen_ax, args...; kwargs...)
end

"""
    plot_multi_patch

Plot a list of DownSampler objects
"""
function plot_multi_patch(
    ax::PyObject,
    dts::AbstractVector{<:DynamicDownsampler},
    xbs::A,
    ybs::B,
    listen_ax::Vector{PyObject} = [ax];
    plotkwargs...
) where {
    S<:NTuple{2, <:Real},
    A<:AbstractArray{S},
    T<:NTuple{2, <:Real},
    B<:AbstractArray{T}
}
    na = length(dts)
    indicies = mod.(0:(na - 1), 10) # for Python consumption, base zero
    colorargs = ["C$n" for n in indicies]
    patchartists = Vector{PyObject}(na)
    for i in 1:na
        patchartists[i] = downsamp_patch(
            ax,
            dts[i],
            xbs[i],
            ybs[i],
            listen_ax,
            colorargs[i];
            plotkwargs...
        )
    end
    return patchartists
end
