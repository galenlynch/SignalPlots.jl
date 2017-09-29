"Used for make a callback to view data that does not require the data"
function make_spec_cb(
    ds::DynamicSpectrogram,
    frange::AbstractVector = [],
)
    nfr = length(frange)
    if nfr == 0
        cb = (xb, xe, npt) -> begin
            (s, f, t) = downsamp_req(ds, xb, xe, npt)
            db = 10 .* log10.(s)
            return (db, f, t)
        end
    elseif nfr == 2 && frange[1] <= frange[2]
        cb = (xb, xe, npt) -> begin
            (s, f, t) = downsamp_req(ds, xb, xe, npt)
            fmask = frange[1] .<= f .<= frange[2]
            clip_s = s[fmask, :]
            clip_f = f[fmask]
            db = 10 .* log10.(s)
            return (db, clip_f, t)
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
    window::Vector{Float64} = hanning(512)
)
    dts = DynamicSpectrogram(a, fs, offset, window)
    return make_spec_cb(dts, frange)
end

function resizeable_spectrogram(
    ax::PyObject,
    cb::Function,
    xbounds::NTuple{2, I},
    ybounds::NTuple{2, I},
) where I <: Real
    ax[:set_autoscale_on](false)
    artist = ax[:imshow](zeros(1,1))
    rartist = prp[:ResizeableImage](cb, artist, xbounds, ybounds) # graph objects must be vector
    ax[:callbacks][:connect]("xlim_changed", rartist[:update])
    ax[:set_xlim](xbounds)
    ax[:set_ylim](ybounds)
    return rartist
end
function resizeable_spectrogram(
    ax::PyObject,
    a::AbstractVector,
    fs::Real,
    offset::Real = 0,
    frange::AbstractVector = [],
    window::Array{Float64} = hanning(512)
)
    cb = make_spec_cb(a, fs, offset, frange, window)
    xbounds = duration(a, fs, offset)
    if isempty(frange)
        freqs = rfftfreq(length(window), fs)
        ybounds = (freqs[1], freqs[end])
    else
        @assert length(frange) == 2 && frange[1] <= frange[2] "invalid frange"
        ybounds = (frange[1], frange[2])
    end
    return resizeable_spectrogram(ax, cb, xbounds, ybounds)
end
