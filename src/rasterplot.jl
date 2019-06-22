function raster_plot(
    ax::PyObject,
    ticks::AbstractVector{<:AbstractVector{<:Number}},
    pre = 0,
    post = mapreduce(maximum, max, ticks, init = 0),
    patch_sets::Union{
        Nothing,
        AbstractVector{<:AbstractVector{<:AbstractVector}}
    } = nothing;
    tick_plot_args = (:color => "k",),
    patch_plot_args = [(:facecolor => "#9ecae1",), (:facecolor => "#deebf7",)],
    top_level::Bool = true
)
    ntrial = length(ticks)
        # Ticks
    raster_coords = make_lc_vertical_coords(ticks)
    lc = PyPlot.matplotlib.collections.LineCollection(
        raster_coords; tick_plot_args...
    )
    ax.add_collection(lc)
    patch_collections = raster_plot_patches(
        ax, patch_sets, ntrial; patch_plot_args = patch_plot_args
    )
    # Patches
    if top_level
        ax.set_xlim([-pre, post])
        ax.set_ylim([0, ntrial + 1])
    end
    lc, patch_collections
end

function raster_plot_patches(
    ax::PyObject,
    patch_sets::AbstractVector{
        <:AbstractVector{<:AbstractVector{<:NTuple{2, <:Number}}}
    },
    ntrial::Integer;
    patch_plot_args = [(:facecolor => "#9ecae1",), (:facecolor => "#deebf7",)]
)
    patch_trials = length.(patch_sets)
    all(ntrial .== patch_trials) || error("Number of trials not the same")
    n_patchset = length(patch_sets)
    length(patch_plot_args) == n_patchset || error("Patch plot args not right size")
    patch_collections = Vector{PyObject}(undef, n_patchset)
    for (i, patch_set) in enumerate(patch_sets)
        patch_collections[i] = make_patch_collection(
            patch_set; patch_plot_args[i]...
        )
        ax.add_collection(patch_collections[i])
    end
    patch_collections
end

function raster_plot_patches(
    ax::PyObject,
    patch_sets::AbstractVector{
        <:AbstractVector{<:AbstractVector{<:Interval}}
    },
    args...;
    kwargs...
)
    simple_patchsets = map(a -> map(b -> map(c -> bounds(c), b), a), patch_sets)
    raster_plot_patches(ax, simple_patchsets, args...; kwargs...)
end

function raster_plot_patches(ax::PyObject, patch_sets::Nothing, args...; kwargs...)
    Vector{PyObject}()
end
