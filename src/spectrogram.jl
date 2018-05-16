"""
    resizeable_spectrogram

plot a resizeable spectrogram of a signal in a matplotlib axis
"""
function resizeable_spectrogram end

function resizeable_spectrogram(
    ax::PyObject,
    args...;
    listen_ax::Vector{PyObject} = [ax],
    toplevel::Bool = true,
    kwargs...
)
    rartist = ResizeableSpec(ax, args...; kwargs...)
    connect_callbacks(ax, rartist, listen_ax; toplevel = toplevel)
    return rartist
end

struct ResizeableSpec{T<:DynamicSpectrogram} <: ResizeableArtist
    ds::T
    clim::Vector{Float64}
    frange::Vector{Float64}
    cmap::String
    baseinfo::RABaseInfo
    function ResizeableSpec{T}(
        ds::T,
        clim::Vector{Float64},
        frange::Vector{Float64},
        cmap::String,
        baseinfo::RABaseInfo
    ) where {T<:DynamicSpectrogram}
        nfr = length(frange)
        if ! empty_or_ordered_bound(frange)
            error("frange must be empty or be bounds")
        end
        if ! empty_or_ordered_bound(clim)
            error("clim must be empty or be bounds")
        end
        return new(ds, clim, frange, cmap, baseinfo)
    end
end

# Pull type parameter
function ResizeableSpec(
    ds::T,
    clim::Vector{Float64},
    frange::Vector{Float64},
    cmap::String,
    baseinfo::RABaseInfo
) where {T<:DynamicSpectrogram}
    return ResizeableSpec{T}(ds, clim, frange, cmap, baseinfo)
end

# type conversion
function ResizeableSpec(
    ds::DynamicSpectrogram,
    clim::Vector{<:Real},
    frange::Vector{<:Real},
    cmap::AbstractString,
    baseinfo::RABaseInfo
)
    return ResizeableSpec(
        ds,
        convert(Vector{Float64}, clim),
        convert(Vector{Float64}, frange),
        string(cmap),
        baseinfo
    )
end

# Make base info
function ResizeableSpec(
    ds::DynamicSpectrogram,
    clim::Vector{<:Real},
    frange::Vector{<:Real},
    cmap::AbstractString,
    args...
) 
    return ResizeableSpec(ds, clim, frange, cmap, RABaseInfo(args...))
end

# make artist, find xlim and ylim
function ResizeableSpec(
    ax::PyObject,
    ds::DynamicSpectrogram,
    clim::AbstractVector{<:Real} = Vector{Float64}(),
    frange::AbstractVector{<:Real} = Vector{Float64}(),
    cmap::AbstractString = "viridis",
    args...
)
    return ResizeableSpec(
        ds,
        clim,
        frange,
        string(cmap),
        ax,
        Vector{PyObject}(),
        duration(ds),
        extrema(ds),
        args...
    )
end

# make dynamic spectrogram
function ResizeableSpec(
    ax::PyObject,
    a::AbstractVector,
    fs::Real,
    offset::Real = 0,
    args...;
    clim::AbstractVector{<:Real} = Vector{Float64}(),
    frange::AbstractVector{<:Real} = Vector{Float64}(),
    window::Array{Float64} = Vector{Float64}(),
    cmap::AbstractString = "viridis"
)
    extra_args = isempty(window) ? () : (window,)
    ds = DynamicSpectrogram(a, fs, offset, extra_args...)
    return ResizeableSpec(ax, ds, clim, frange, cmap, args...)
end

xbounds(a::ResizeableSpec) = duration(a.ds)
ybounds(a::ResizeableSpec) = isempty(a.frange) ? extrema(a.ds) : a.frange

function update_plotdata(ra::ResizeableSpec, xstart, xend, pixwidth)
    (t, (f, s), was_downsamped) = downsamp_req(ra.ds, xstart, xend, pixwidth)
    (db, f_start, f_end) = process_spec_data(ra, f, s)

    if ! isempty(ra.baseinfo.artists)
        ra.baseinfo.artists[1][:remove]()
        pop!(ra.baseinfo.artists)
    end

    imartist = ra.baseinfo.ax[:imshow](
        db;
        cmap = ra.cmap,
        extent = [t[1], t[end], f_start, f_end],
        interpolation = "nearest",
        origin = "lower",
        aspect = "auto"
    )
    push!(ra.baseinfo.artists, imartist)
end

function process_spec_data(ra::ResizeableSpec, f, s)
    if isempty(ra.frange)
        f_start = f[1]
        f_end = f[end]
        sel_s = s
    else
        f_start_i = searchsortedfirst(f, ra.frange[1])
        f_end_i = searchsortedlast(f, ra.frange[2])
        f_start = f[f_start_i]
        f_end = f[f_end_i]
        sel_s = view(s, f_start_i:f_end_i, 1:size(s, 2))
    end
    db = p2db.(sel_s)
    if !isempty(ra.clim)
        clipval!(db, (ra.clim[1], ra.clim[2]))
    end
return (db, f_start, f_end)
end

function clipval!(a::AbstractArray, c::NTuple{2, R}) where {R<:Number}
    a[a.<c[1]] = c[1]
    a[a.>c[2]] = c[2]
end

noop(args...;kwargs...) = nothing
p2db(a::Number) = 10 * log10(a)

function empty_or_ordered_bound(a::AbstractArray)
    na = length(a)
    return na == 0 || (na == 2 && a[1] <= a[2])
end
