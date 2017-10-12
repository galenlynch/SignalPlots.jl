"Base type for resizeable artists, must implement a setdata method and have a baseinfo field"
abstract type ResizeableArtists end

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

function get_ax_pix_size(ax::PyObject)
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

function update(ra::ResizeableArtists, notifying_ax::PyObject)
    otherlims = notifying_ax[:viewLim]
    (xstart, xend) = otherlims[:intervalx]::Vector{Float64}
    baseinfo = ra.baseinfo::RABaseInfo
    ownlims = baseinfo.ax[:viewLim]
    (ystart, yend) = ownlims[:intervaly]::Vector{Float64}
    xoverlap = check_overlap(xstart, xend, baseinfo.datalimx[1], baseinfo.datalimx[2])
    yoverlap = check_overlap(ystart, yend, baseinfo.datalimy[1], baseinfo.datalimy[2])
    if xoverlap && yoverlap
        limwidth = xend - xstart
        width_rd = ratiodiff(limwidth, baseinfo.lastlimwidth)
        limcenter = (xend + xstart) / 2
        center_rd = ratiodiff(limcenter, baseinfo.lastlimcenter)
        if max(width_rd, center_rd) > baseinfo.threshdiff
            baseinfo.lastlimwidth = limwidth
            baseinfo.lastlimcenter = limcenter
            (pixwidth, pixheight) = get_ax_pix_size(notifying_ax)

    end
end
w
