# version for multiple units, ticks are neurons(reps(spikes))
"""
    function raster_plot(
        ax::Py,
        ticks::AbstractVector{AbstractVector{<:AbstractVector{<:Number}}},
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

Make a rasterplot for the activity of multiple units, while also displaying the
discrete presence of some behavioral information, such as song syllables, for
each trial.

"""
function raster_plot(
    ax::Py,
    ticks::AbstractVector{<:AbstractVector{<:AbstractVector{<:Number}}},
    pre = 0,
    post = mapreduce(x -> mapreduce(maximum, max, x, init = 0), max, ticks, init = 0),
    patch_sets::AbstractVector{<:AbstractVector{<:AbstractVector}} = Vector{
        Vector{NTuple{2,Float64}},
    }[];
    tick_plot_args::Union{
        AbstractVector{<:AbstractVector{<:Pair{Symbol,<:Any}}},
        AbstractVector{<:Pair{Symbol,<:Any}},
    } = [:color => "k"],
    patch_plot_args::AbstractVector{<:AbstractVector{<:Pair{Symbol,<:Any}}} = Vector{
        Pair{Symbol,Any},
    }[
        [:facecolor => "#9ecae1"],
        [:facecolor => "#deebf7"],
    ],
    top_level::Bool = true,
)
    nunit = length(ticks)
    nunit == 0 && return
    ntrial = length(ticks[1])
    allsame(length, ticks) ||
        throw(ArgumentError("All units must have the same number of trials"))
    # Ticks
    tick_height = 1 / nunit
    baseoffset = 0.5 + tick_height / 2
    lcs = Vector{Py}(undef, nunit)
    if tick_plot_args isa AbstractVector{<:Pair{Symbol,<:Any}}
        tick_plot_args = fill(tick_plot_args, nunit)
    end
    for unitno = 1:nunit
        raster_coords = make_lc_vertical_coords(
            ticks[unitno],
            1,
            baseoffset + (unitno - 1) * tick_height,
            tick_height,
        )
        lcs[unitno] = PythonPlot.matplotlib.collections.LineCollection(
            raster_coords;
            tick_plot_args[unitno]...,
        )
        ax.add_collection(lcs[unitno])
    end
    patch_collections =
        raster_plot_patches(ax, patch_sets, ntrial; patch_plot_args = patch_plot_args)
    # Patches
    if top_level
        ax.set_xlim([-pre, post])
        ax.set_ylim([0.5, ntrial + 0.5])
    end
    lcs, patch_collections
end

# Version for a single unit, ticks are reps(spikes)
function raster_plot(
    ax::Py,
    ticks::AbstractVector{<:AbstractVector{<:Number}},
    args...;
    kwargs...,
)
    raster_plot(ax, [ticks], args...; kwargs...)
end

function raster_plot_patches(
    ax::Py,
    patch_sets::AbstractVector{<:AbstractVector{<:AbstractVector{<:NTuple{2,<:Number}}}},
    ntrial::Integer;
    patch_plot_args::AbstractVector{<:AbstractVector{<:Pair{Symbol,<:Any}}} = Vector{
        Pair{Symbol,String},
    }[
        [:facecolor => "#9ecae1"],
        [:facecolor => "#deebf7"],
    ],
)
    # Check inputs
    n_patchset = length(patch_sets)
    patch_collections = Vector{Py}(undef, n_patchset)
    n_patchset == 0 && return patch_collections
    n_plotargs = length(patch_plot_args)
    if n_plotargs == 0
        patch_plot_args = fill(Vector{Pair{Symbol,Any}}[], n_patchset)
    elseif n_plotargs != n_patchset
        throw(
            ArgumentError(
                "Patch plot args must be length zero or the same length as patch_sets",
            ),
        )
    end
    if mapreduce(x -> length(x) != ntrial, |, patch_sets, init = false)
        throw(ArgumentError("Number of trials not the same"))
    end
    # Make patches
    for (i, patch_set) in enumerate(patch_sets)
        patch_collections[i] = make_patch_collection(patch_set; patch_plot_args[i]...)
        ax.add_collection(patch_collections[i])
    end
    patch_collections
end

function raster_plot_patches(
    ax::Py,
    patch_sets::AbstractVector{<:AbstractVector{<:AbstractVector{<:Interval}}},
    args...;
    kwargs...,
)
    simple_patchsets = map(a -> map(b -> map(c -> bounds(c), b), a), patch_sets)
    raster_plot_patches(ax, simple_patchsets, args...; kwargs...)
end
