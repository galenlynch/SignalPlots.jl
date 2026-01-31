"""
    resizeable_spectrogram(ax, args...; [listen_ax, toplevel], kwargs...)

plot the spectrogram of a signal in a resizeable context
"""
function resizeable_spectrogram end

function resizeable_spectrogram(
    ax::A,
    args...;
    listen_ax::Vector{A} = [ax],
    toplevel::Bool = true,
    kwargs...,
) where {A<:Axis}
    rartist = ResizeableSpec(ax, args...; kwargs...)
    connect_callbacks(ax, rartist, listen_ax; toplevel = toplevel)
    return rartist
end

struct ResizeableSpec{T<:AbstractDynamicSpectrogram,P} <: ResizeableArtist{T,P}
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
        baseinfo::B,
    ) where {T<:AbstractDynamicSpectrogram,P<:MPL,B<:RABaseInfo{P}}
        range_check(frange, clim)
        baseinfo.ax.ax.autoscale(false, axis = "both")
        return new(ds, clim, frange, cmap, baseinfo)
    end
    function ResizeableSpec{T,P}(
        ds::T,
        clim::Vector{Float64},
        frange::Vector{Float64},
        cmap::String,
        baseinfo::B,
    ) where {T<:AbstractDynamicSpectrogram,P<:PQTG,B<:RABaseInfo{P}}
        range_check(frange, clim)
        r = new(ds, clim, frange, cmap, baseinfo)
        di = pg.ImageItem()
        di.setOpts(axisOrder = "row-major")
        push!(r.baseinfo.artists, Artist{P}(di))
        return r
    end
    function range_check(frange, clim)
        if ! empty_or_ordered_bound(frange)
            error("frange must be empty or be bounds")
        end
        if ! empty_or_ordered_bound(clim)
            error("clim must be empty or be bounds")
        end
    end
end

# Pull type parameter
function ResizeableSpec(
    ds::T,
    clim::Vector{Float64},
    frange::Vector{Float64},
    cmap::String,
    baseinfo::RABaseInfo{P},
) where {T<:AbstractDynamicSpectrogram,P<:PlotLib}
    return ResizeableSpec{T,P}(ds, clim, frange, cmap, baseinfo)
end

# type conversion
function ResizeableSpec(
    ds::T,
    clim::AbstractVector{<:Real},
    frange::AbstractVector{<:Real},
    cmap::AbstractString,
    baseinfo::RABaseInfo,
) where {T<:AbstractDynamicSpectrogram} # method disambiguation
    return ResizeableSpec(
        ds,
        convert(Vector{Float64}, clim),
        convert(Vector{Float64}, frange),
        string(cmap),
        baseinfo,
    )
end

# Make base info
function ResizeableSpec(
    ds::AbstractDynamicSpectrogram,
    clim::AbstractVector{<:Real},
    frange::AbstractVector{<:Real},
    cmap::AbstractString,
    args...,
)
    return ResizeableSpec(ds, clim, frange, cmap, RABaseInfo(args...))
end

# make artist, find xlim and ylim
function ResizeableSpec(
    ax::A,
    ds::AbstractDynamicSpectrogram,
    args...;
    clim::AbstractVector{<:Real} = Vector{Float64}(),
    frange::AbstractVector{<:Real} = Vector{Float64}(),
    cmap::AbstractString = def_cmap(ax),
) where {P<:PlotLib,A<:Axis{P}}
    yb = isempty(frange) ? extrema(ds) : (frange...,)
    return ResizeableSpec(
        ds,
        clim,
        frange,
        string(cmap),
        ax,
        Vector{Artist{P}}(),
        time_interval(ds),
        yb,
        args...,
    )
end

# make dynamic spectrogram
function ResizeableSpec(
    ax::Axis{P},
    a::AbstractVector,
    fs::Real,
    offset::Real = 0,
    args...;
    clim::AbstractVector{<:Real} = Vector{Float64}(),
    frange::AbstractVector{<:Real} = Vector{Float64}(),
    cmap::AbstractString = def_cmap(ax),
    binsize::Integer = 256,
    winfun::Union{Function,Missing} = missing,
) where {P<:PlotLib}
    ds = DynCachingStftPsd(a, binsize, fs, winfun, offset, 0.8)
    return ResizeableSpec(ax, ds, args...; clim = clim, frange = frange, cmap = cmap)
end

def_cmap(::Type{<:PlotLib}) = ""
def_cmap(::Type{MPL}) = "grayalpha"
def_cmap(::Type{A}) where {P,A<:Axis{P}} = def_cmap(P)
def_cmap(::A) where {A<:Axis} = def_cmap(A)

downsampler(r::ResizeableSpec) = r.ds

xbounds(a::ResizeableSpec) = time_interval(a.ds)
ybounds(a::ResizeableSpec) = isempty(a.frange) ? extrema(a.ds) : a.frange

update_args(ra::ResizeableSpec) = (ra.frange, ra.clim)

function make_plotdata(
    ds::AbstractDynamicSpectrogram,
    xstart,
    xend,
    pixwidth,
    res,
    frange,
    clim,
)
    (t, (f, s, t_w, f_w), was_downsamped) = downsamp_req(ds, xstart, xend, pixwidth)
    (db, f_start, f_end) = process_spec_data(s, f, frange, clim)
    return (t[1], t[end], f_start, f_end, t_w, f_w, db)
end

function process_spec_data(s, f, frange, clim)
    if isempty(frange)
        f_start = f[1]
        f_end = f[end]
        sel_s = s
    else
        f_l = length(f)
        f_start_i = searchsortedfirst(f, frange[1])
        f_start_i > f_l && error("specified frange not in frequency range")
        f_end_i = searchsortedlast(f, frange[2])
        f_end_i == 0 && error("specified frange not in frequency range")
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
    ra::ResizeableSpec{<:Any,P},
    t_start,
    t_end,
    f_start,
    f_end,
    t_w,
    f_w,
    db,
) where {P<:MPL}
    if ! isempty(ra.baseinfo.artists)
        ra.baseinfo.artists[1].artist.remove()
        pop!(ra.baseinfo.artists)
    end

    extent = bounding_rect(t_start, t_end, t_w, f_start, f_end, f_w)
    imartist = Artist{P}(
        ra.baseinfo.ax.ax.imshow(
            db;
            origin = "lower",
            cmap = ra.cmap,
            extent = extent,
            interpolation = "nearest",
            aspect = "auto",
        ),
    )
    push!(ra.baseinfo.artists, imartist)
end

function bounding_rect(t_start, t_end, t_w, f_start, f_end, f_w)
    extent = [t_start - t_w/2, t_end + t_w/2, f_start - f_w/2, f_end + f_w/2]
    return extent
end

function update_artists(
    ra::ResizeableSpec{<:Any,P},
    t_start,
    t_end,
    f_start,
    f_end,
    t_w,
    f_w,
    db,
) where {P<:PQTG}
    ra.baseinfo.artists[1].artist.setImage(tonumpy(db))
    (x_s, x_e, y_s, y_e) = bounding_rect(t_start, t_end, t_w, f_start, f_end, f_w)
    qtrect = qtc.QRectF(x_s, y_s, x_e - x_s, y_e - y_s)
    ra.baseinfo.artists[1].artist.setRect(qtrect)
    nothing
end

function clipval!(a::AbstractArray, c::NTuple{2,R}) where {R<:Number}
    a[a .< c[1]] .= c[1]
    a[a .> c[2]] .= c[2]
end

noop(args...; kwargs...) = nothing
p2db(a::Number) = 10 * log10(a)

function empty_or_ordered_bound(a::AbstractArray)
    na = length(a)
    return na == 0 || (na == 2 && a[1] <= a[2])
end

function plot_example_spectrogram(
    sp_ax::Axis,
    song_clip::AbstractVector{<:Number},
    pre::Number;
    fs = 30000,
    clim = [-95, -40],
    frange = [1000, 8000],
    listen_ax = Axis{MPL}[],
    decorate::Bool = true,
    f_scalebar::Bool = true,
    t_scalebar::Bool = true,
    title::Bool = true,
    adjust_lims::Bool = true,
    limscale::Real = 1.35,
    freq_scalebar_frac = 0.2,
    time_scalebar_frac = 0.05,
    freq_scalebar_pos = [0, 0.1],
    time_scalebar_pos = [0.95, 0.6],
    freq_units = "Hz",
    time_units = "s",
    binsize = 512,
    kwargs...,
)
    rspec = resizeable_spectrogram(
        sp_ax,
        song_clip .- mean(song_clip),
        fs,
        -pre;
        clim = clim,
        frange = frange,
        listen_ax = listen_ax,
        binsize = binsize,
        kwargs...,
    );

    if title
        sp_ax.ax.set_title("Example recording")
    end
    sp_ax.ax.axis("off")

    if f_scalebar
        ax_yb, ax_ye = axis_ylim(sp_ax)
        f_scalebar_ax_size, f_scalebar_units, f_scalebar_prefix =
            best_scalebar_size(ax_yb, ax_ye, freq_scalebar_frac)
        freq_scalebar_label = "$(f_scalebar_units) $(f_scalebar_prefix)$freq_units"
        sb_f = matplotlib_scalebar(
            sp_ax.ax,
            f_scalebar_ax_size,
            freq_scalebar_label,
            horizontal = false,
            loc = "lower right",
            axes_pos = freq_scalebar_pos,
            sep = 2,
            textprops = Dict("fontsize" => 6),
        )
    else
        sb_f = nothing
    end
    if t_scalebar
        ax_xb, ax_xe = axis_xlim(sp_ax)
        t_scalebar_ax_size, t_scalebar_units, t_scalebar_prefix =
            best_scalebar_size(ax_xb, ax_xe, time_scalebar_frac)
        time_scalebar_label = "$(t_scalebar_units) $(t_scalebar_prefix)$time_units"
        sb_ms = matplotlib_scalebar(
            sp_ax.ax,
            t_scalebar_ax_size,
            time_scalebar_label,
            textfirst = false,
            loc = "upper right",
            axes_pos = time_scalebar_pos,
            textprops = Dict("fontsize" => 6),
        )
    else
        sb_ms = nothing
    end

    if adjust_lims
        sp_ax.ax.set_ylim([0, frange[2] * limscale])
    end

    rspec, sb_f, sb_ms
end

function plot_annotated_spectrogram(
    sp_ax::Axis,
    song_clip::AbstractVector{<:Number},
    pre::Number,
    aligned_motif_syl_ints::AbstractVector{<:Interval},
    clipped_other_syl_ints::AbstractVector{<:Interval},
    motif,
    other_syll_labels;
    frange = [0, 12000],
    motif_patch_height = 0.083,
    motif_patch_sep = 0.083,
    motif_patch_color = "#9ecae1",
    other_syl_patch_color = "#deebf7",
    other_label_text_color = "0.4",
    syll_label_kwargs::Dict = Dict(),
    use_syll_labels::Bool = true,
    kwargs...,
)
    rspec, sb_f, sb_ms =
        plot_example_spectrogram(sp_ax, song_clip, pre; frange = frange, kwargs...)

    if !(isempty(aligned_motif_syl_ints) && isempty(clipped_other_syl_ints))
        # Syllable labels
        f_height = frange[2] * motif_patch_height
        f_sep = frange[2] * motif_patch_sep
        f_center = frange[2] + f_sep + f_height / 2
        pcm = make_patch_collection(
            aligned_motif_syl_ints;
            height = f_height,
            ycenter = f_center,
            facecolor = motif_patch_color,
            clip_on = false,
        )

        sp_ax.ax.add_collection(pcm)

        label_f = f_center + f_height
        if use_syll_labels
            mth = add_labels(
                sp_ax.ax,
                midpoint.(aligned_motif_syl_ints),
                motif,
                label_f;
                syll_label_kwargs...,
            )
        else
            mth = nothing
        end

        if !isempty(clipped_other_syl_ints)
            if use_syll_labels
                oth = add_labels(
                    sp_ax.ax,
                    midpoint.(clipped_other_syl_ints),
                    other_syll_labels,
                    label_f;
                    color = other_label_text_color,
                    syll_label_kwargs...,
                )
            else
                oth = nothing
            end
            pco = make_patch_collection(
                clipped_other_syl_ints;
                height = f_height,
                ycenter = f_center,
                facecolor = other_syl_patch_color,
                clip_on = false,
            )

            sp_ax.ax.add_collection(pco)
        else
            pco = nothing
            oth = nothing
        end
    else
        pcm = nothing
        mth = nothing
        pco = nothing
        oth = nothing
    end

    rspec, sb_f, sb_ms, pcm, pco, mth, oth
end
