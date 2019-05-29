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

function waveform_overlapped_plot(ax::PyObject, args...; kwargs...)
    lc, basis = waveform_overlapped_collection(ax, args...; kwargs...)
    ax.add_collection(lc)
    ax.set_xlim([basis[1], basis[end]])
    ax.autoscale(axis = "y")
    lc
end

function waveform_overlapped_collection(
    spk_clips::AbstractVector{<:AbstractVector{<:Number}},
    fs::Number,
    basis::Union{Nothing, AbstractRange, AbstractVector} = nothing;
    basis_conversion::Number = 1000,
    color = (0, 0, 0, 0.1),
    linewidths = 0.3,
    plot_kwargs::Dict{Symbol, Any} = Dict{Symbol, Any}()
)
    nspk = length(spk_clips)
    nspk > 0 || throw(ArgumentError("spk_clips must not be empty"))
    if ! allsame(length, spk_clips)
        throw(ArgumentError("Length of spike clips must be identical"))
    end
    n_support = length(spk_clips[1])
    if basis == nothing
        half_support = fld(n_support, 2)
        basis = basis_conversion * (-half_support:1:half_support) / fs
    end
    spk_points = make_lc_coords(basis, spk_clips)
    lc = PyPlot.matplotlib.collections.LineCollection(
        spk_wavs;
        color = color,
        linewidths = linewidths,
        plot_kwargs...
    )
    lc, basis
end

function make_lc_vertical_coords(xs::AbstractVector{<:AbstractVector{<:Number}})
    nrep = length(xs)
    nsp = length.(xs)
    total_sp = sum(nsp)
    @compat outs = Array{Float32}(undef, total_sp, 2, 2)
    pos = 1
    for repno = 1:nrep
        this_nsp = nsp[repno]
        outs[pos:(pos + this_nsp - 1), :, :] = vertical_line_coords(
            xs[repno], repno
        )
        pos += this_nsp
    end
    outs
end

function make_lc_coords(
    xs::Union{AbstractVector, AbstractRange},
    ys::AbstractVector{<:AbstractVector{<:Number}}
)
    nrep = length(ys)
    nbasis = length(xs)
    @compat out = Array{Float32, 3}(undef, nrep, nbasis, 2)
    out[:, :, 1] .= reshape(xs, 1, nbasis)
    for repno = 1:nrep
        out[repno, :, 2] = ys[repno]
    end
    out
end

function make_lc_coords(
    xs::Union{AbstractVector, AbstractRange},
    ys::AbstractMatrix
)
    nrep = size(ys, 2)
    nbasis = length(xs)
    @compat out = Array{Float32, 3}(undef, nrep, nbasis, 2)
    out[:, :, 1] .= reshape(xs, 1, nbasis)
    pys = permutedims(ys)
    out[:, :, 2] .= ifelse.(ismissing.(pys), NaN, pys)
    out
end

function vertical_line_coords(xs::AbstractVector{<:Number}, ycenter, height = 1)
    nx = length(xs)
    outs = Array{Float64, 3}(undef, nx, 2, 2)
    half_height = height / 2
    y_high = ycenter + half_height
    y_low = ycenter - half_height
    @inbounds @simd for i in 1:nx
        outs[i, :, 1] .= xs[i]
        outs[i, 1, 2] = y_high
        outs[i, 2, 2] = y_low
    end
    outs
end

function make_patch_collection(
    ints::AbstractVector{<:AbstractVector};
    height = 1,
    ycenters = 1:length(ints),
    kwargs...
)
    nrep = length(ints)
    nint = length.(ints)
    nint_total = sum(nint)
    rects = Vector{PyObject}(undef, nint_total)
    pos = 1
    for (i, int_rep) in enumerate(ints)
        rects[pos:(pos + nint[i] - 1)] =
            make_rect_patches(int_rep, ycenters[i], height)
        pos += nint[i]
    end
    PyPlot.matplotlib.collections.PatchCollection(
        rects; match_original = false, kwargs...
    )
end

function make_patch_collection(
    ints::AbstractVector{<:Union{Interval, NTuple{2, <:Number}}};
    height = 1,
    ycenter = 1,
    kwargs...
)
    PyPlot.matplotlib.collections.PatchCollection(
        make_rect_patches(ints, ycenter, height);
        match_original = false, kwargs...
    )
end

function add_labels(
    ax::PyObject,
    xcenters::AbstractVector{<:Number},
    labelstrs::AbstractVector{<:AbstractString},
    ybase::Real,
    ha = "center",
    va = "bottom";
    kwargs...
)
    nx = length(xcenters)
    @compat th = Vector{PyObject}(undef, nx)
    for (i, x) in enumerate(xcenters)
        th[i] = ax.text(x, ybase, labelstrs[i]; ha = ha, va = va, kwargs...)
    end
    th
end

function make_rect_patches(
    ints::AbstractVector{<:NTuple{2, <:Number}},
    ycenter,
    height = 1
)
    half_height = height / 2
    y_bottom = ycenter - half_height
    n_int = length(ints)
    rects = Vector{PyObject}(undef, n_int)
    for (i, (xb, xe)) in enumerate(ints)
        rects[i] = PyPlot.matplotlib.patches.Rectangle(
            (xb, y_bottom), xe - xb, height
        )
    end
    rects
end

function make_rect_patches(ints::AbstractVector{<:Interval}, args...)
    simple_ints = bounds.(ints)
    make_rect_patches(simple_ints, args...)
end

function matplotlib_scalebar(
    ax::PyObject, size::Number, label::AbstractString;
    textfirst::Bool = true,
    loc = 4, # Refer to matplotlib loc documentation
    axes_pos::AbstractArray = [0, 0], # In axes coordinates (not data)
    horizontal::Bool = true,
    color = "k",
    textprops::Union{Nothing, Dict{String, <:Any}} = nothing,
    sep::Real = 2, # Separation between text and bar
    trans::Symbol = :transAxes
)
    # Make the bar
    dims = horizontal ? (size, 0) : (0, size)
    art = PyPlot.matplotlib.patches.Rectangle((0,0), dims...; ec = color)

    # Make the bar scale with data axes
    atb = PyPlot.matplotlib.offsetbox.AuxTransformBox(ax.transData)
    atb.add_artist(art)

    # Make the text
    ta = PyPlot.matplotlib.offsetbox.TextArea(
        label; minimumdescent = false, textprops = textprops
    )

    # Join the bar and text together
    if horizontal
        packer = PyPlot.matplotlib.offsetbox.VPacker
    else
        packer = PyPlot.matplotlib.offsetbox.HPacker
    end
    childs = textfirst ? [ta, atb] : [atb, ta]
    p = packer(children = childs, align = "center", pad = 0, sep = sep)

    # Anchor them
    sb = PyPlot.matplotlib.offsetbox.AnchoredOffsetbox(
        loc,
        child = p,
        bbox_to_anchor = axes_pos,
        bbox_transform = getproperty(ax, trans),
        frameon = false
    )

    # Add them to the axis
    ax.add_artist(sb)

    sb
end

nearest_multiple(x, b::T) where T<:Integer = b * round(T, x / b)
nearest_multiple(x, b) = b * round(x / b)

function prefix(pow10)
    range = floor(Int, pow10 / 3)
    pre =
        range == -5 ? "f" :
        range == -4 ? "p" :
        range == -3 ? "n" :
        range == -2 ? "µ" :
        range == -1 ? "m" :
        range == 0 ? "" :
        range == 1 ? "k" :
        range == 2 ? "M" :
        range == 3 ? "G" :
        range == 4 ? "T" :
        range == 5 ? "P" : "?"
end

"Adjust the fraction away from 0 and 1, if possible, otherwise return `nothing`"
function edgefix(frac, base_offset)
    adjustment_dir = ifelse(frac == 0, 1, ifelse(frac == 1, -1, 0))
    adjusted = ifelse(
        (adjustment_dir != 0) & (base_offset >= 0),
        nothing,
        base_offset * adjustment_dir + frac
    )
end

"""
    function best_scalebar_size(
        axis_begin::Real,
        axis_end::Real,
        target_frac::AbstractFloat,
        axis_unit_pow10::Integer = 0;
        bases = [10, 5, 2, 1],
        base_penalties = [0, 5, 10, 20],
        target_frac_penalty = 50
    )
    -> (scalebar_ax_size::Float64, scalebar_units::Int, scalebar_prefix::String)

Finds the best scale bar size for an axis with limits `axis_begin` and
`axis_end`, where the target scale bar fraction of the axis is `target_frac`.
`target_frac` must be between `0` and `1`. The axis may optionally have units
other than natural (e.g. if axis units are uV, then set `axis_unit_pow10 = -6`).

Returns the size of the scalebar in axis units, `scalebar_ax_size`, the display
size, `scalebar_units`, as well as the base 10 prefix for the scalebar units,
`scalebar_prefix`, e.g. 'k' for `10^3`, 'm' for `10^-3` etc.

Rounding is done to match the scalebar to the nearest base specified in `bases`.
Which base is chosen based on `base_penalties` and `target_frac_penalty` to
minimize `target_frac_penalty * abs(frac_at_base - target_frac) + base_penalty`.
`base_penalties` and `bases` must be the same length.
"""
function best_scalebar_size(
    axis_begin::Real,
    axis_end::Real,
    target_frac::AbstractFloat,
    axis_unit_pow10::Integer = 0;
    bases = [100, 50, 10, 5, 2, 1],
    base_penalties = [0, 5, 10, 20, 30, 40],
    target_frac_penalty = 30
)
    @argcheck 0 < target_frac < 1
    @argcheck length(bases) == length(base_penalties)

    ax_r = axis_end - axis_begin
    if ax_r == 0
        scalebar_ax_size = 0
        scalebar_units = 0
        scalebar_prefix = "?"
    else
        exact_size = target_frac * ax_r

        pow10 = floor(Int, log(10, exact_size + eps()))
        pow10_offset = -3 * floor(Int, pow10 / 3)

        multiplier = 10.0 ^ pow10_offset
        disp_number = round(Int, exact_size * multiplier)
        roundeds = nearest_multiple.(disp_number, bases)
        scaled_fracs = roundeds / (multiplier * ax_r)
        base_fracs = bases / (multiplier * ax_r)
        fixed_fracs = edgefix.(scaled_fracs, base_fracs)
        ok_ndxs = findall(!isequal(nothing), fixed_fracs) # ! and isequal can curry
        isempty(ok_ndxs) && error("No scalebar candidate sizes survived!")
        costs =
            target_frac_penalty * abs.(fixed_fracs[ok_ndxs] .- target_frac) .+
            base_penalties[ok_ndxs]
        base_ndx = ok_ndxs[argmin(costs)]

        scalebar_ax_size = fixed_fracs[base_ndx] * ax_r
        scalebar_units = round(Int, scalebar_ax_size * multiplier)
        scalebar_prefix = prefix(-pow10_offset + axis_unit_pow10)
    end

    scalebar_ax_size, scalebar_units, scalebar_prefix
end

function electrode_grid(assembly_type::Symbol; kwargs...)
    if assembly_type == :PI
        patches = circle_collection(PI_XS, PI_YS, PI_PITCH / 2)
    elseif assembly_type == :PI_14
        patches = circle_collection(PI_14_XS, PI_14_YS, PI_PITCH / 2)
    elseif assembly_type == :GRID
        patches = rect_collection(FLEX_XS, FLEX_YS, FLEX_PITCH)
    elseif assembly_type == :HARBI
        patches = circle_collection(
            HARBI_XS, HARBI_YS, HARBI_PITCH / 2
        )
    elseif assembly_type == :DMITRIY
        patches = circle_collection(DMITRIY_XS, DMITRIY_YS, PI_PITCH / 2)
    else
        error("Unrecognized assembly_type $assembly_type")
    end

    PyPlot.matplotlib.collections.PatchCollection(
        patches; match_original = false, kwargs...
    )
end

function circle_collection(xs, ys, rad)
    nx = length(xs)
    @argcheck nx == length(ys)
    patches = Vector{PyObject}(undef, nx)
    for i in 1:nx
        patches[i] = PyPlot.matplotlib.patches.Circle((xs[i], ys[i]), rad)
    end
    patches
end

function rect_collection(xs, ys, dx, dy)
    nx = length(xs)
    @argcheck nx == length(ys)
    patches = Vector{PyObject}(undef, nx)
    x_off = dx / 2
    y_off = dy / 2
    for i in 1:nx
        patches[i] = PyPlot.matplotlib.patches.Rectangle(
            (xs[i] - x_off, ys[i] - y_off), dx, dy
        )
    end
    patches
end

rect_collection(xs, ys, dx) = rect_collection(xs, ys, dx, dx)

function scatter_packed(ax, x::AbstractVector, y::AbstractVector; s = 5, kwargs...)
    points = ax.scatter(xsorted, ysorted; s = s, kwargs...)
    scatter_packed(ax, points, s; kwargs...)
end

function scatter_packed(ax, points, s)
    orig_xy = permutedims(ax.transData.transform(points.get_offsets()))
    new_xy = swarm_points!(orig_xy, dia)
end

function ax_dia(ax; s = 5, kwargs...)
    default_lw = PyPlot.matplotlib.rcParams["patch.linewidth"]
    lw = get(kwargs, :linewidth, get(kwargs, :lw, default_lw))
    dpi = ax.figure.dpi
    (sqrt(s) + lw) * (dpi / 72)
end

function swarm_points!(orig_xy::AbstractMatrix, dia::Number)
    sort!(orig_xy; dims = 2)
    off = 1
    np = size(orig_xy, 2)
    while off <= np
        pos = off + 1
        while pos <= np && orig_xy[:, off] == orig_xy[:, pos]
            pos += 1
        end
        pack_points!(view(orig_xy, :, off:pos - 1), dia)
        off = pos
    end
    orig_xy
end

function swarm_points(orig_xy::AbstractMatrix, ax::PyObject; kwargs...)
    orig_xy_pts = permutedims(ax.transData.transform(permutedims(orig_xy)))
    dia = 7 * ax_dia(ax; kwargs...)
    @show dia
    swarmed = swarm_points!(orig_xy_pts, dia)
    @show swarmed
    permutedims(ax.transData.inverted().transform(permutedims(swarmed)))
end

function pack_points!(orig_xy, dia)
    @show dia
    @show orig_xy
    np = size(orig_xy, 2)
    @show np
    # Do nothing if np == 1
    rad = dia / 2
    if np == 2
        orig_xy[1, 1] -= rad
        orig_xy[1, 2] += rad
    elseif np == 3
        off = sqrt(3)
        orig_xy[:, 1] += [0, rad * 2 * off / 3]
        orig_xy[:, 2] += [-rad, -off * rad / 3]
        orig_xy[:, 3] += [rad, -off * rad / 3]
    elseif np == 4
        orig_xy[:, 1] += [-rad, rad]
        orig_xy[:, 2] += [rad, rad]
        orig_xy[:, 3] += [rad, -rad]
        orig_xy[:, 4] += [-rad, -rad]
    elseif np == 5
        rc = dia * sqrt(50 + 10 * sqrt(5)) / 10
        for i = 1:5
            theta = 2 * pi * i / 5
            orig_xy[:, i] += rc * [cos(theta), sin(theta)]
        end
    elseif np == 6 || np == 7
        for i = 2:6
            theta = 2 * pi * (i - 1) / 6
            orig_xy[:, i] += dia * [cos(theta), sin(theta)]
        end
        if np == 7
            orig_xy[:, 7] += dia * [1, 0]
        end
    elseif np > 7
        error("Too many points!")
    end
    @show orig_xy
end

const DMITRIY_XS = [-114.3, 0.0, 114.3]
const DMITRIY_YS = [0.0, 0.0, 0.0]

const PI_14_XS = [
    -98.9867, 98.9867, 98.9867, -98.9867, 98.9867, -98.9867,
    98.9867, 98.9867, -98.9867, 98.9867, -98.9867, 98.9867,
    98.9867, -98.9867
]
const PI_14_YS = [
    285.75, 400.05, 285.75, 171.45, 171.45, 57.15,
    57.15, -57.15, -57.15, -171.45, -171.45, -285.75,
    -400.05, -285.75
]

const PI_XS = [
    -98.9867, 98.9867, 0.0, 98.9867, -98.9867, 0.0, 98.9867, -98.9867, 0.0,
    98.9867, 0.0, 98.9867, 0.0, -98.9867, 98.9867, 0.0, -98.9867, 98.9867,
    0.0, 98.9867, -98.9867
]
const PI_YS = [
    285.75, 400.05, 342.9, 285.75, 171.45, 228.6, 171.45, 57.15, 114.3,
    57.15, 0.0, -57.15, -114.3, -57.15, -171.45, -228.6, -171.45, -285.75,
    -342.9, -400.05, -285.75
]
const PI_PITCH = 114.3

const FLEX_XS = [
    -130.0, 130.0, 0.0, 130.0, -130.0, 0.0, 130.0, -130.0, 0.0, 130.0, 0.0,
    130.0, 0.0, -130.0, 130.0, 0.0, -130.0, 130.0, 0.0, 130.0, -130.0
]
const FLEX_YS = [
    325.0, 455.0, 455.0, 325.0, 195.0, 325.0, 195.0, 65.0, 195.0, 65.0, 65.0,
    -65.0, -65.0, -65.0, -195.0, -195.0, -195.0, -325.0, -325.0, -455.0, -325.0
]
const FLEX_PITCH = 130

const HARBI_XS = [
    562.5, 487.5, 412.5, 337.5, 262.5, 187.5, 112.5, 37.5, -37.5, -112.5, -187.5,
    -262.5, -337.5, -412.5, -487.5, -562.5, 562.5, 487.5, 412.5, 337.5, 262.5,
    187.5, 112.5, 37.5, -37.5, -112.5, -187.5, -262.5, -337.5, -412.5, -487.5,
    -562.5, -562.5, -487.5, -412.5, -337.5, -262.5, -187.5, -112.5, -37.5, 37.5,
    112.5, 187.5, 262.5, 337.5, 412.5, 487.5, 562.5, -562.5, -487.5, -412.5,
    -337.5, -262.5, -187.5, -112.5, -37.5, 37.5, 112.5, 187.5, 262.5, 337.5,
    412.5, 487.5, 562.5
]

const HARBI_YS = [
    -125.0, -125.0, -125.0, -125.0, -125.0, -125.0, -125.0, -125.0, -125.0, -125.0,
    -125.0, -125.0, -125.0, -125.0, -125.0, -125.0, -375.0, -375.0, -375.0, -375.0,
    -375.0, -375.0, -375.0, -375.0, -375.0, -375.0, -375.0, -375.0, -375.0, -375.0,
    -375.0, -375.0, 125.0, 125.0, 125.0, 125.0, 125.0, 125.0, 125.0, 125.0, 125.0,
    125.0, 125.0, 125.0, 125.0, 125.0, 125.0, 125.0, 375.0, 375.0, 375.0, 375.0,
    375.0, 375.0, 375.0, 375.0, 375.0, 375.0, 375.0, 375.0, 375.0, 375.0, 375.0,
    375.0
]

const HARBI_PITCH = 75
