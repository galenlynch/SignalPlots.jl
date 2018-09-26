function raster_plot(
    ax::PyObject,
    ticks::AbstractVector{<:AbstractVector{<:Number}},
    pre,
    post,
    patch_sets::Union{
        Nothing,
        AbstractVector{<:AbstractVector{<:AbstractVector{<:NTuple{2, <:Number}}}}
    } = nothing;
    tick_plot_args = (:color => "k",),
    patch_plot_args = [(:facecolor => "#9ecae1",), (:facecolor => "#deebf7",)],
    top_level::Bool = true
)
    ntrial = length(ticks)
        # Ticks
    raster_coords = make_lc_vertical_coords(ticks)
    lc = PyPlot.matplotlib[:collections][:LineCollection](
        raster_coords; tick_plot_args...
    )
    ax[:add_collection](lc)
    patch_collections = raster_plot_patches(
        ax, patch_sets, ntrial; patch_plot_args = patch_plot_args
    )
    # Patches
    if top_level
        ax[:set_xlim]([-pre, post])
        ax[:set_ylim]([0, ntrial + 1])
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
        ax[:add_collection](patch_collections[i])
    end
    patch_collections
end

function raster_plot_patches(ax::PyObject, patch_sets::Nothing, args...; kwargs...)
    Vector{PyObject}()
end

function waveform_overlapped_plot(ax::PyObject, args...; kwargs...)
    lc, basis = waveform_overlapped_collection(ax, args...; kwargs...)
    ax[:add_collection](lc)
    ax[:set_xlim]([basis[1], basis[end]])
    ax[:autoscale](axis = "y")
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
    lc = PyPlot.matplotlib[:collections][:LineCollection](
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
    @compat out = Array{Float32}(undef, nrep, nbasis, 2)
    out[:, :, 1] .= reshape(xs, 1, nbasis)
    for repno = 1:nrep
        out[repno, :, 2] = ys[repno]
    end
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
    ints::AbstractVector{<:AbstractVector{<:NTuple{2, <:Number}}};
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
        rects[pos:(pos + nint[i] - 1)] = make_rect_patches(int_rep, ycenters[i], height)
        pos += nint[i]
    end
    PyPlot.matplotlib[:collections][:PatchCollection](
        rects; match_original = false, kwargs...
    )
end

function make_patch_collection(
    ints::AbstractVector{<:NTuple{2, <:Number}};
    height = 1,
    ycenter = 1,
    kwargs...
)
    PyPlot.matplotlib[:collections][:PatchCollection](
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
        th[i] = ax[:text](x, ybase, labelstrs[i]; ha = ha, va = va, kwargs...)
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
        rects[i] = PyPlot.matplotlib[:patches][:Rectangle](
            (xb, y_bottom), xe - xb, height
        )
    end
    rects
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
    art = PyPlot.matplotlib[:patches][:Rectangle]((0,0), dims...; ec = color)

    # Make the bar scale with data axes
    atb = PyPlot.matplotlib[:offsetbox][:AuxTransformBox](ax[:transData])
    atb[:add_artist](art)

    # Make the text
    ta = PyPlot.matplotlib[:offsetbox][:TextArea](
        label; minimumdescent = false, textprops = textprops
    )

    # Join the bar and text together
    if horizontal
        packer = PyPlot.matplotlib[:offsetbox][:VPacker]
    else
        packer = PyPlot.matplotlib[:offsetbox][:HPacker]
    end
    childs = textfirst ? [ta, atb] : [atb, ta]
    p = packer(children = childs, align = "center", pad = 0, sep = sep)

    # Anchor them
    sb = PyPlot.matplotlib[:offsetbox][ :AnchoredOffsetbox](
        loc,
        child = p,
        bbox_to_anchor = axes_pos,
        bbox_transform = ax[trans],
        frameon = false
    )

    # Add them to the axis
    ax[:add_artist](sb)

    sb
end

function electrode_circles(;kwargs...)
    n_pi = length(PI_XS)
    circles = Vector{PyObject}(undef, n_pi)
    for i in 1:n_pi
        circles[i] = PyPlot.matplotlib[:patches][:Circle](
            (PI_XS[i], PI_YS[i]), PI_PITCH / 2
        )
    end
    PyPlot.matplotlib[:collections][:PatchCollection](
        circles; match_original = false, kwargs...
    )
end

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
