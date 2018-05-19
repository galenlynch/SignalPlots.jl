"""
    plot_spacing(extents[, scale_factor = 1.2])

Calculate the spacing between dataseries for plotting, which is the mean of the
extents times an optional scale factor.
"""
function plot_spacing(
    extents::A, scale_factor::Number = 1.2
) where {E<:Number, A<:AbstractVector{E}}
    return scale_factor * mean(extents)
end

function plot_spacing(
    extents::A, args...
) where {T<:NTuple{2, Number}, A<:AbstractVector{T}}
    plot_spacing(map((t) -> t[2] - t[1], extents), args...)
end

function plot_spacing(
    series::A, args...
) where {E<:AbstractVector, A<:AbstractVector{E}}
    return plot_spacing(extent(series), args...)
end

"""
    plot_offsets(n_line, spacing[, offset = 0])

Calculate the offset for each of `n_line` number of plots with `spacing` in
between them. Optionally start the first line at `offset`.
"""
function plot_offsets end
function plot_offsets(
    n_line::Integer,
    spacing::A,
    offset::B = A(0)
) where {A<:Number, B<:Number}
    T = promote_type(A, B)
    if spacing == 0
        out = fill(T(offset), n_line)
    else
        out = Vector{T}(spacing * (0:(n_line - 1)) + offset)
    end
    return out
end
function plot_offsets(
    series::A,
    offset::Number = 0,
    args...
) where {E<:AbstractVector, A<:AbstractVector{E}}
    n = length(series)
    spacing = plot_spacing(series, args...)
    return plot_offsets(n, spacing, offset)
end
function plot_offsets(
    ::A,
    args...
) where {E<:Number, A<:AbstractVector{E}}
    return E[0]
end

function ax_pix_width(ax::PyObject)
    fig = ax[:figure]::PyPlot.Figure
    scale = fig[:dpi_scale_trans][:inverted]()::PyObject
    bbox = ax[:get_window_extent]()[:transformed](scale)::PyObject

    width = bbox[:width]::Float64
    dpi = fig[:dpi]::Float64

    return width * dpi
end

axis_limits(ax::PyObject) = ax[:viewLim]::PyObject

function axis_xlim(ax::PyObject)
    bbox = axis_limits(ax)
    return (bbox[:xmin]::Float64, bbox[:xmax]::Float64)
end

function axis_ylim(ax::PyObject)
    bbox = axis_limits(ax)
    return (bbox[:ymin]::Float64, bbox[:ymax]::Float64)
end
