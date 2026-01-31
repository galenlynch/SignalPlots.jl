const XType = Union{AbstractVector,AbstractRange}
const MplAxType = Union{Py,Axis{MPL}}

# Assumes regular x
function bar(
    ax::MplAxType,
    xs::XType,
    ys::AbstractVector{<:Number};
    align_center::Bool = true,
    relative_width::Real = 1,
    plot_kwargs...,
)
    length(xs) >= 2 || error("Lazy coding")
    0 <= relative_width <= 1 || throw(ArgumentError("relative_width is wrong"))
    align = ifelse(align_center, "center", "edge")

    dx = stepsize(xs)
    width = dx * relative_width
    ax.bar(xs, ys; width = width, align = align, plot_kwargs...)
end

# Assumes regular x
function bar(
    ax::MplAxType,
    xs::XType,
    ys::AbstractVector{<:AbstractVector{<:Number}};
    colors = nothing,
    labels = nothing,
    plot_kwargs...,
)
    nseries = length(ys)
    if !isnothing(colors) && length(colors) != nseries
        error("Length of colors, $(length(colors)), does not match $nseries")
    end
    if !isnothing(labels) && length(labels) != nseries
        error("Labels not long enough")
    end
    bottoms = zeros(length(xs))
    outs = Vector{Tuple{Vararg{Py}}}(undef, nseries)
    for i = 1:nseries
        if isnothing(colors)
            color_kwarg = Dict{Symbol,Any}()
        else
            color_kwarg = Dict(:color => colors[i])
        end
        if isnothing(labels)
            label_kwarg = Dict{Symbol,Any}()
        else
            label_kwarg = Dict(:label => labels[i])
        end
        outs[i] = bar(
            xs,
            ys[i];
            bottom = bottoms,
            color_kwarg...,
            label_kwarg...,
            plot_kwargs...,
        )
        bottoms .+= ys[i]
    end
    outs
end

bar(xs::XType, args...; kwargs...) = bar(gca(), xs, args...; kwargs...)

function histplot(
    ax::MplAxType,
    bin_edges::XType,
    ys;
    adjust_lims::Bool = true,
    relative_width = 1,
    kwargs...,
)
    ret = bar(
        ax,
        bin_edges[1:(end-1)],
        ys;
        relative_width = relative_width,
        align_center = false,
        kwargs...,
    )
    adjust_lims && ax.set_xlim(bin_edges[1], bin_edges[end])
    ret
end

histplot(bin_edges::XType, args...; kwargs...) =
    histplot(gca(), bin_edges, args...; kwargs...)

function scatter(ax, X::AbstractMatrix; kwargs...)
    ax.scatter(X[1, :], X[2, :])
end
