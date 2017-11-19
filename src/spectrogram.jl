function clipval(a::AbstractArray, c::NTuple{2, R}) where {R<:Number}
    a[a.<c[1]] = c[1]
    a[a.>c[2]] = c[2]
end

noop(args...;kwargs...) = nothing
p2db(a::Number) = 10 * log10(a)

"""
    make_spec_cb

Create a closure of the form f(xb, xe, npt) -> (s, f, t, cl)

This callback can be called from python without using the DynamicSpectrogram
object.
"""
function make_spec_cb(
    ds::DynamicSpectrogram,
    clim::AbstractVector = [],
    frange::AbstractVector = [],
)
    nfr = length(frange)
    clipfun = isempty(clim) ? noop : (x) -> clipval(x, (clim[1], clim[2]))
    if nfr == 0
        cb = (xb, xe, npt) -> begin
            (t, (f, s)) = downsamp_req(ds, xb, xe, npt)
            times = collect(t)
            db = p2db.(s)
            clipfun(db)
            return (db, f, times, clim)
        end
    elseif nfr == 2 && frange[1] <= frange[2]
        cb = (xb, xe, npt) -> begin
            (t, (f, s)) = downsamp_req(ds, xb, xe, npt)
            fmask = frange[1] .<= f .<= frange[2]
            clip_f = f[fmask]
            clip_s = s[fmask, :]
            db = p2db.(clip_s)
            clipfun(db)
            times = collect(t)
            return (db, clip_f, times, clim)
        end
    else
        error("invalid frange")
    end
    return cb
end
function make_spec_cb(
    a::AbstractVector,
    fs::Real,
    offset::Real = 0,
    frange::AbstractVector = [],
    clim::AbstractVector = [],
    window::Vector{Float64} = hanning(512)
)
    dts = DynamicSpectrogram(a, fs, offset, window)
    return make_spec_cb(dts, clim, frange)
end

"""
    resizeable_spectrogram

plot a resizeable spectrogram of a signal in a matplotlib axis
"""
function resizeable_spectrogram end

function resizeable_spectrogram(
    ax::PyObject,
    cb::Function,
    xbounds::NTuple{2, I},
    ybounds::NTuple{2, J},
    listen_ax::Vector{PyObject} = [ax];
    cmap::AbstractString = "viridis"
) where {I <: Real, J <: Real}
    ax[:set_autoscale_on](false)
    artist = ax[:imshow](
        zeros(1,1);
        aspect = "auto",
        interpolation = "nearest",
        origin = "lower",
        cmap = cmap
    )
    rartist = prp[:ResizeableImage](ax, cb, artist, xbounds, ybounds) # graph objects must be vector
    for lax in listen_ax
        lax[:callbacks][:connect]("xlim_changed", rartist[:update])
    end
    return rartist
end
function resizeable_spectrogram(
    ax::PyObject,
    a::AbstractVector,
    fs::Real,
    offset::Real = 0,
    listen_ax::Vector{PyObject} = [ax];
    frange::AbstractVector = [],
    clim::AbstractVector = [],
    window::Array{Float64} = hanning(512),
    cmap::AbstractString = "viridis"
)
    cb = make_spec_cb(a - mean(a), fs, offset, frange, clim, window)
    xbounds = duration(a, fs, offset)
    if isempty(frange)
        freqs = rfftfreq(length(window), fs)
        ybounds = (freqs[1], freqs[end])
    else
        @assert length(frange) == 2 && frange[1] <= frange[2] "invalid frange"
        ybounds = (frange[1], frange[2])
    end
    return resizeable_spectrogram(ax, cb, xbounds, ybounds, listen_ax; cmap = cmap)
end
