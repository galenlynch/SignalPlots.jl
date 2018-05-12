"""
Base type for resizeable artists, must implement a setdata method and have a
baseinfo field"
"""
abstract type ResizeableArtist end

mutable struct RABaseInfo
    ax::PyObject
    artists::Vector{PyObject}
    datalimx::NTuple{2, Float64}
    datalimy::NTuple{2, Float64}
    threshdiff::Float64
    lastlimwidth::Float64
    lastlimcenter::Float64

    function RABaseInfo(
    ax::PyObject,
    artists::Vector{PyObject},
    datalimx::NTuple{2, Float64},
    datalimy::NTuple{2, Float64},
    threshdiff::Float64 = 0.0,
    lastlimwidth::Float64 = 0.0,
    lastlimcenter::Float64 = 0.0
)
        return new(
            ax,
            artists,
            datalimx,
            datalimy,
            threshdiff,
            lastlimwidth,
            lastlimcenter
        )
    end
end
function RABaseInfo(ax::PyObject, artist::PyObject, args...)
    return RABaseInfo(ax, [artist], args...)
end

ratiodiff(a, b) = abs(a - b) / (b + eps(b))

function ax_pix_size(ax::PyObject)
    fig = ax[:figure]
    scale = fig[:dpi_scale_trans][:inverted]()
    bbox = ax[:get_window_extent]()[:transformed](scale)

    width = bbox[:width]::Float64
    height = bbox[:height]::Float64
    dpi = fig[:dpi]::Float64

    pixwidth = width * dpi
    pixheight = height * dpi
    return (pixwidth, pixheight)
end

function axis_limits(notifying_ax::PyObject, artist_ax::PyObject)
    lims_notifying = notifying_ax[:viewLim]
    (xstart, xend) = lims_notifying[:intervalx]::Vector{Float64}
    lims_artist = artist_ax[:viewLim]
    (ystart, yend) = lims_artist[:intervaly]::Vector{Float64}
    return (xstart, xend, ystart, yend)
end
axis_limits(ax::PyObject) = axis_limits(ax, ax)

function artist_is_visible(ra::ResizeableArtist, xstart, xend, ystart, yend)
    xoverlap = check_overlap(
        xstart, xend, ra.baseinfo.datalimx[1], ra.baseinfo.datalimx[2]
    )
    yoverlap = check_overlap(
        ystart, yend, ra.baseinfo.datalimy[1], ra.baseinfo.datalimy[2]
    )
    return xoverlap && yoverlap
end

function artist_should_redraw(ra::ResizeableArtist, limwidth, limcenter)
    width_rd = ratiodiff(limwidth, ra.baseinfo.lastlimwidth)
    center_rd = ratiodiff(limcenter, ra.baseinfo.lastlimcenter)
    return max(width_rd, center_rd) > ra.baseinfo.threshdiff
end

function axis_xlim_changed(ra::ResizeableArtist, notifying_ax::PyObject)
    (xstart, xend, ystart, yend) = axis_limits(notifying_ax, ra.baseinfo.ax)
    if artist_is_visible(ra, xstart, xend, ystart, yend)
        limwidth = xend - xstart
        limcenter = (xend + xstart) / 2
        if artist_should_redraw(ra, limwidth, limcenter)
            ra.baseinfo.lastlimwidth = limwidth
            ra.baseinfo.lastlimcenter = limcenter
            (pixwidth, pixheight) = ax_pix_size(notifying_ax)
            update_plotdata(ra, xstart, xend, pixwidth)
            ra.baseinfo.ax[:figure][:canvas][:draw_idle]()
        end
    end
end

struct ResizeablePatch{T<:DynamicDownsampler} <: ResizeableArtist
    baseinfo::RABaseInfo
    dts::T
end
function ResizeablePatch(dts::DynamicDownsampler, args...; kwargs...)
    return ResizeablePatch(RABaseInfo(args...; kwargs...), dts)
end

function fill_points(xs, ys, was_downsampled)
    if was_downsampled
        npt = 2 * length(xs)
        xpts = Vector{Float64}(npt)
        ypts = Vector{Float64}(npt)
        for (x_i, x) in enumerate(xs) # Enumerate over input
            # Calculate the corresponding position in the output
            i = (x_i - 1) * 2 + 1
            # First two points have the same x (vertical line)
            xpts[i] = x
            xpts[i + 1] = x
            # These two points are the min and max y values
            ypts[i] = ys[x_i][1]
            ypts[i + 1] = ys[x_i][2]
        end
    else
        xpts = Vector{Float64}(xs)
        ypts = Float64[y[1] for y in ys]
    end
    return (xpts, ypts)
end

function update_plotdata(ra::ResizeablePatch, xstart, xend, pixwidth)
    (xpt, ypt) = fill_points(downsamp_req(ra.dts, xstart, xend, pixwidth)...)
    ra.baseinfo.artists[1][:set_data](xpt, ypt)
end
