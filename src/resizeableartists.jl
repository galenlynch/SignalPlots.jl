"Base type for resizeable artists, must implement a setdata method and have a baseinfo field"
abstract type ResizeableArtist end

mutable struct RABaseInfo
    ax::PyObject
    artists::Vector{PyObject}
    datalimx::NTuple{2, Float64}
    datalimy::NTuple{2, Float64}
    threshdiff::Float64
    lastlimwidth::Float64
    lastlimcenter::Float64
end
function RABaseInfo(
    ax,
    artsts,
    datalimx,
    datalimy,
    threshdiff = 0,
    lastlimwidth = 0,
    lastlimcenter = 0
)
    return RABaseInfo(
        ax, artists, datalimx, datalimy, threshdiff, lastlimwidth, lastlimcenter
    )
end

ratiodiff(a, b) = abs(a - b) / (b + eps)

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
    xoverlap = check_overlap(xstart, xend, baseinfo.datalimx[1], baseinfo.datalimx[2])
    yoverlap = check_overlap(ystart, yend, baseinfo.datalimy[1], baseinfo.datalimy[2])
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

struct ResizeablePatch <: ResizeableArtist
    baseinfo::RABaseInfo
    patch::PyObject
    dts::CachingDynamicTs
end

function poly_points(xs, ys, stepwidth)
    nx = length(xs)
    npt = 4 * nx
    pts = Array{Float64, 2}(npt, 2)
    for i in eachindex(xs)
        # make a horizontal line for each point
    end
end

function update_plotdata(ra::ResizeablePatch, xstart, xend, pixwidth)
    (xs, ys) = downsamp_req(ra.dts, xstart, xend, pixwidth)
    stepwidth = (xend - xstart) / pixwidth
    (xpt, ypt) = poly_points(xs, ys, stepwidth)

end
