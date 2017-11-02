function plot_spacing(
    extents::A,
    spacing::Number = 1.2
) where {E<:Number, A<:AbstractVector{E}}
    return spacing * mean(extents)
end
function plot_spacing(
    series::A,
    args...
) where {E<:AbstractVector, A<:AbstractVector{E}}
    return plot_spacing(extent(series), args...)
end

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
    return 0:0
end
