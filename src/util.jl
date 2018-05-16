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
