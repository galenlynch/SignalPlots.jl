function scatter_packed(ax, x::AbstractVector, y::AbstractVector; s = 5, kwargs...)
    points = ax.scatter(x, y; s = s, kwargs...)
    scatter_packed(ax, points, s; kwargs...)
end

function scatter_packed(ax, points, s)
    orig_xy = permutedims(ax.transData.transform(points.get_offsets()))
    dia = ax_dia(ax; s = s)
    new_xy = swarm_points!(orig_xy, dia)
end

function ax_dia(ax; s = 5, kwargs...)
    default_lw = pyconvert(Float64, PythonPlot.matplotlib.rcParams["patch.linewidth"])
    lw = get(kwargs, :linewidth, get(kwargs, :lw, default_lw))
    dpi = pyconvert(Float64, ax.figure.dpi)
    (sqrt(s) + lw) * (dpi / 72)
end

function swarm_points!(orig_xy::AbstractMatrix, dia::Number)
    sort!(orig_xy; dims = 2)
    off = 1
    np = size(orig_xy, 2)
    while off <= np
        pos = off + 1
        while pos <= np && orig_xy[:, off] == orig_xy[:, pos]
            pos += 1
        end
        pack_points!(view(orig_xy, :, off:(pos-1)), dia)
        off = pos
    end
    orig_xy
end

function swarm_points(orig_xy::AbstractMatrix, ax::Py; kwargs...)
    orig_xy_pts = permutedims(ax.transData.transform(permutedims(orig_xy)))
    dia = 7 * ax_dia(ax; kwargs...)
    swarmed = swarm_points!(orig_xy_pts, dia)
    permutedims(ax.transData.inverted().transform(permutedims(swarmed)))
end

function pack_points!(orig_xy, dia)
    np = size(orig_xy, 2)
    # Do nothing if np == 1
    rad = dia / 2
    if np == 2
        orig_xy[1, 1] -= rad
        orig_xy[1, 2] += rad
    elseif np == 3
        off = sqrt(3)
        orig_xy[:, 1] += [0, rad * 2 * off / 3]
        orig_xy[:, 2] += [-rad, -off * rad / 3]
        orig_xy[:, 3] += [rad, -off * rad / 3]
    elseif np == 4
        orig_xy[:, 1] += [-rad, rad]
        orig_xy[:, 2] += [rad, rad]
        orig_xy[:, 3] += [rad, -rad]
        orig_xy[:, 4] += [-rad, -rad]
    elseif np == 5
        rc = dia * sqrt(50 + 10 * sqrt(5)) / 10
        for i = 1:5
            theta = 2 * pi * i / 5
            orig_xy[:, i] += rc * [cos(theta), sin(theta)]
        end
    elseif np == 6 || np == 7
        for i = 2:6
            theta = 2 * pi * (i - 1) / 6
            orig_xy[:, i] += dia * [cos(theta), sin(theta)]
        end
        if np == 7
            orig_xy[:, 7] += dia * [1, 0]
        end
    elseif np > 7
        error("Too many points!")
    end
end
