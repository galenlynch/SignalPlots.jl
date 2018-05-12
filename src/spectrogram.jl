"""
    resizeable_spectrogram

plot a resizeable spectrogram of a signal in a matplotlib axis
"""
function resizeable_spectrogram end

function resizeable_spectrogram(
    ax::PyObject,
    ds::DynamicSpectrogram,
    xbounds::NTuple{2, I},
    ybounds::NTuple{2, J},
    listen_ax::Vector{PyObject} = [ax];
    clim::AbstractVector = [],
    frange::AbstractVector = [],
    cmap::AbstractString = "viridis",
    toplevel::Bool = true
) where {I <: Real, J <: Real}
    rartist = ResizeableSpec(
        ds, ax, Vector{PyObject}(), xbounds, ybounds;
        clim = clim, frange = frange
    )
    ax[:set_autoscale_on](false)
    toplevel && set_ax_home(rartist)
    update_fnc = (a) -> axis_lim_changed(rartist, a)
    for lax in listen_ax
        lax[:callbacks][:connect]("xlim_changed", update_fnc)
    end
    update_fnc(ax)
    return rartist
end
function resizeable_spectrogram(
    ax::PyObject,
    a::AbstractVector,
    fs::Real,
    offset::Real = 0,
    args...;
    frange::AbstractVector = [],
    window::Array{Float64} = hanning(512),
    kwargs...
)
    ds = DynamicSpectrogram(a, fs, offset, window)
    xbounds = duration(a, fs, offset)
    if isempty(frange)
        freqs = rfftfreq(length(window), fs)
        ybounds = (freqs[1], freqs[end])
    else
        @assert length(frange) == 2 && frange[1] <= frange[2] "invalid frange"
        ybounds = (frange[1], frange[2])
    end
    return resizeable_spectrogram(
        ax, ds, xbounds, ybounds, args...;
        frange = frange, kwargs...
    )
end

struct ResizeableSpec{T<:DynamicSpectrogram} <: ResizeableArtist
    ds::T
    clim::Vector{Float64}
    frange::Vector{Float64}
    baseinfo::RABaseInfo
    function ResizeableSpec{T}(
        ds::T,
        clim::Vector{Float64},
        frange::Vector{Float64},
        baseinfo::RABaseInfo
    ) where {T<:DynamicSpectrogram}
        nfr = length(frange)
        if ! empty_or_ordered_bound(frange)
            error("frange must be empty or be bounds")
        end
        if ! empty_or_ordered_bound(clim)
            error("clim must be empty or be bounds")
        end
        return new(ds, clim, frange, baseinfo)
    end
end
function ResizeableSpec(
    ds::T,
    clim::Vector{Float64},
    frange::Vector{Float64},
    args...;
) where {T<:DynamicSpectrogram}
    return ResizeableSpec{T}(ds, clim, frange, RABaseInfo(args...))
end
function ResizeableSpec(
    ds::DynamicSpectrogram, args...;
    clim::AbstractVector = [],
    frange::AbstractVector = []
)
    return ResizeableSpec(
        ds,
        convert(Vector{Float64}, clim),
        convert(Vector{Float64}, frange),
        args...
    )
end

function update_plotdata(ra::ResizeableSpec, xstart, xend, pixwidth)
    (t, (f, s), was_downsamped) = downsamp_req(ra.ds, xstart, xend, pixwidth)
    (db, f_start, f_end) = process_spec_data(ra, f, s)

    if ! isempty(ra.baseinfo.artists)
        ra.baseinfo.artists[1][:remove]()
        pop!(ra.baseinfo.artists)
    end

    imartist = ra.baseinfo.ax[:imshow](
        db;
        cmap = "viridis",
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
        sel_s = view(s, f_start_i:f_end_i, 1:length(s))
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
