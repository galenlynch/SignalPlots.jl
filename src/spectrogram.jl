"""
    resizeable_spectrogram

plot a resizeable spectrogram of a signal in a matplotlib axis
"""
function resizeable_spectrogram end

function resizeable_spectrogram(
    ax::A,
    args...;
    listen_ax::Vector{A} = [ax],
    toplevel::Bool = true,
    kwargs...
) where {P<:PlotLib, A<:Axis{P}}
    rartist = ResizeableSpec(ax, args...; kwargs...)
    connect_callbacks(ax, rartist, listen_ax; toplevel = toplevel)
    return rartist
end

struct ResizeableSpec{T<:DynamicSpectrogram, P} <: ResizeableArtist{T,P}
    ds::T
    clim::Vector{Float64}
    frange::Vector{Float64}
    cmap::String
    baseinfo::RABaseInfo{P}
    function ResizeableSpec{T,P}(
        ds::T,
        clim::Vector{Float64},
        frange::Vector{Float64},
        cmap::String,
        baseinfo::B
    ) where {T<:DynamicSpectrogram, P, B<:RABaseInfo{P}}
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
    baseinfo::RABaseInfo{P}
) where {T<:DynamicSpectrogram, P}
    return ResizeableSpec{T,P}(ds, clim, frange, cmap, baseinfo)
end

# type conversion
function ResizeableSpec(
    ds::T,
    clim::AbstractVector{<:Real},
    frange::AbstractVector{<:Real},
    cmap::AbstractString,
    baseinfo::R
) where {T<:DynamicSpectrogram, R<:RABaseInfo}
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
    clim::AbstractVector{<:Real},
    frange::AbstractVector{<:Real},
    cmap::AbstractString,
    args...
)
    return ResizeableSpec(ds, clim, frange, cmap, RABaseInfo(args...))
end

# make artist, find xlim and ylim
function ResizeableSpec(
    ax::A,
    ds::DynamicSpectrogram,
    args... ;
    clim::AbstractVector{<:Real} = Vector{Float64}(),
    frange::AbstractVector{<:Real} = Vector{Float64}(),
    cmap::AbstractString = "viridis",
) where {P<:PlotLib, A<:Axis{P}}
    yb = isempty(frange) ? extrema(ds) : (frange...)
    return ResizeableSpec(
        ds,
        clim,
        frange,
        string(cmap),
        ax,
        Vector{Artist{P}}(),
        duration(ds),
        yb,
        args...
    )
end

# make dynamic spectrogram
function ResizeableSpec(
    ax::Axis,
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
    return ResizeableSpec(ax, ds, args...; clim=clim, frange=frange, cmap=cmap)
end

downsampler(r::ResizeableSpec) = r.ds
baseinfo(r::ResizeableSpec) = r.baseinfo

xbounds(a::ResizeableSpec) = duration(a.ds)
ybounds(a::ResizeableSpec) = isempty(a.frange) ? extrema(a.ds) : a.frange

update_args(ra::ResizeableSpec) = (ra.frange, ra.clim)

function make_plotdata(ds::DynamicSpectrogram, xstart, xend, pixwidth, frange, clim)
    (t, (f, s), was_downsamped) = downsamp_req(ds, xstart, xend, pixwidth)
    (db, f_start, f_end) = process_spec_data(s, f, frange, clim)
    return (t[1], t[end], f_start, f_end, db)
end

function process_spec_data(s, f, frange, clim)
    if isempty(frange)
        f_start = f[1]
        f_end = f[end]
        sel_s = s
    else
        f_start_i = searchsortedfirst(f, frange[1])
        f_end_i = searchsortedlast(f, frange[2])
        f_start = f[f_start_i]
        f_end = f[f_end_i]
        sel_s = view(s, f_start_i:f_end_i, 1:size(s, 2))
    end
    db = p2db.(sel_s)
    if !isempty(clim)
        clipval!(db, (clim[1], clim[2]))
    end
    return (db, f_start, f_end)
end

function update_artists(
    ra::ResizeableSpec{<:Any, P}, t_start, t_end, f_start, f_end, db
) where {P<:MPL}
    if ! isempty(ra.baseinfo.artists)
        ra.baseinfo.artists[1].artist[:remove]()
        pop!(ra.baseinfo.artists)
    end

    imartist = Artist{P}(
        ra.baseinfo.ax.ax[:imshow](
            db;
            cmap = ra.cmap,
            extent = [t_start, t_end, f_start, f_end],
            interpolation = "nearest",
            origin = "lower",
            aspect = "auto"
        )
    )
    push!(ra.baseinfo.artists, imartist)
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
