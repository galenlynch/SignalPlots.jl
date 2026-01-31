function matplotlib_scalebar(
    ax::Py,
    size::Number,
    label::AbstractString;
    textfirst::Bool = true,
    loc = 4, # Refer to matplotlib loc documentation
    axes_pos::AbstractArray = [0, 0], # In axes coordinates (not data)
    horizontal::Bool = true,
    color = "k",
    textprops::Union{Nothing,Dict{String,<:Any}} = nothing,
    sep::Real = 2, # Separation between text and bar
    trans::Symbol = :transAxes,
)
    # Make the bar
    dims = horizontal ? (size, 0) : (0, size)
    art = PythonPlot.matplotlib.patches.Rectangle((0, 0), dims...; ec = color)

    # Make the bar scale with data axes
    atb = PythonPlot.matplotlib.offsetbox.AuxTransformBox(ax.transData)
    atb.add_artist(art)

    # Make the text
    ta = PythonPlot.matplotlib.offsetbox.TextArea(label; textprops = textprops)

    # Join the bar and text together
    if horizontal
        packer = PythonPlot.matplotlib.offsetbox.VPacker
    else
        packer = PythonPlot.matplotlib.offsetbox.HPacker
    end
    childs = textfirst ? [ta, atb] : [atb, ta]
    p = packer(children = childs, align = "center", pad = 0, sep = sep)

    # Anchor them
    sb = PythonPlot.matplotlib.offsetbox.AnchoredOffsetbox(
        loc,
        child = p,
        bbox_to_anchor = axes_pos,
        bbox_transform = getproperty(ax, trans),
        frameon = false,
    )

    # Add them to the axis
    ax.add_artist(sb)

    sb
end

nearest_multiple(x, b::T) where {T<:Integer} = b * round(T, x / b)
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
        range == 2 ? "M" : range == 3 ? "G" : range == 4 ? "T" : range == 5 ? "P" : "?"
end

"Adjust the fraction away from 0 and 1, if possible, otherwise return `nothing`"
function edgefix(frac, base_offset)
    adjustment_dir = ifelse(frac == 0, 1, ifelse(frac == 1, -1, 0))
    adjusted = ifelse(
        (adjustment_dir != 0) & (base_offset >= 0),
        nothing,
        base_offset * adjustment_dir + frac,
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
    target_frac_penalty = 30,
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

function make_lc_vertical_coords(
    xs::AbstractVector{<:AbstractVector{<:Number}},
    pitch,
    offset,
    height,
)
    nrep = length(xs)
    nsp = length.(xs)
    total_sp = sum(nsp)
    outs = Array{Float32,3}(undef, total_sp, 2, 2)
    pos = 1
    for repno = 1:nrep
        this_nsp = nsp[repno]
        this_ycenter = offset + (repno - 1) * pitch
        outs[pos:(pos+this_nsp-1), :, :] =
            vertical_line_coords(xs[repno], this_ycenter, height)
        pos += this_nsp
    end
    outs
end

function make_lc_coords(
    xs::Union{AbstractVector,AbstractRange},
    ys::AbstractVector{<:AbstractVector{<:Number}},
)
    nrep = length(ys)
    nbasis = length(xs)
    out = Array{Float32,3}(undef, nrep, nbasis, 2)
    out[:, :, 1] .= reshape(xs, 1, nbasis)
    for repno = 1:nrep
        out[repno, :, 2] = ys[repno]
    end
    out
end

function make_lc_coords(xs::Union{AbstractVector,AbstractRange}, ys::AbstractMatrix)
    nrep = size(ys, 2)
    nbasis = length(xs)
    out = Array{Float32,3}(undef, nrep, nbasis, 2)
    out[:, :, 1] .= reshape(xs, 1, nbasis)
    pys = permutedims(ys)
    out[:, :, 2] .= ifelse.(ismissing.(pys), NaN, pys)
    out
end

function vertical_line_coords(xs::AbstractVector{<:Number}, ycenter, height = 1)
    nx = length(xs)
    outs = Array{Float64,3}(undef, nx, 2, 2)
    half_height = height / 2
    y_high = ycenter + half_height
    y_low = ycenter - half_height
    @inbounds @simd for i = 1:nx
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
    kwargs...,
)
    nrep = length(ints)
    nint = length.(ints)
    nint_total = sum(nint)
    rects = Vector{Py}(undef, nint_total)
    pos = 1
    for (i, int_rep) in enumerate(ints)
        rects[pos:(pos+nint[i]-1)] = make_rect_patches(int_rep, ycenters[i], height)
        pos += nint[i]
    end
    PythonPlot.matplotlib.collections.PatchCollection(rects; match_original = false, kwargs...)
end

function make_patch_collection(
    ints::AbstractVector{<:Union{Interval,NTuple{2,<:Number}}};
    height = 1,
    ycenter = 1,
    kwargs...,
)
    PythonPlot.matplotlib.collections.PatchCollection(
        make_rect_patches(ints, ycenter, height);
        match_original = false,
        kwargs...,
    )
end

function add_labels(
    ax::Py,
    xcenters::AbstractVector{<:Number},
    labelstrs::AbstractVector{<:AbstractString},
    ybase::Real,
    ha = "center",
    va = "bottom";
    kwargs...,
)
    nx = length(xcenters)
    th = Vector{Py}(undef, nx)
    for (i, x) in enumerate(xcenters)
        th[i] = ax.text(x, ybase, labelstrs[i]; ha = ha, va = va, kwargs...)
    end
    th
end
