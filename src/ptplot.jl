"""
    point_boxes

Plot a set of points with boxes around each point, merging if necessary.
"""
function point_boxes(
    ax::Axis{P}, xpoints, heights, min_t, y_center = 0;
    listen_ax::AbstractVector{Axis{P}} = [ax],
    toplevel::Bool = true,
    pen = def_line_colors[1],
    kwargs...
) where P<:PlotLib
    rmp = MergingPoints(
        ax, xpoints, heights, min_t, y_center; pen = pen, kwargs...
    )
    connect_callbacks(ax, rmp, listen_ax; toplevel = toplevel)
    rmp
end

function point_boxes_multi(
    ax::A,
    pts::AbstractVector{<:DynamicPointBoxer},
    min_width::Number = 0;
    director::Union{Missing, ArtDirector} = missing,
    listen_ax::Vector{A} = [ax],
    toplevel::Bool = true,
    cluster_ids::AbstractVector{<:Integer} = Int[],
    kwargs...
) where A<:Axis
    np = length(pts)
    np > 0 || throw(ArgumentError("np can not be empty"))
    isempty(cluster_ids) || length(cluster_ids) == np || throw(ArgumentError(
        "Cluster ids not the right size"
    ))
    usename = ! isempty(cluster_ids)
    name_karg = usename ? ((:name, string(cluster_ids[1])),) : ()
    rmp_first = MergingPoints(
        ax, pts[1], min_width;
        pen = def_line_colors[1],
        name_karg..., kwargs...
    )
    @compat rmps = Vector{typeof(rmp_first)}(undef, np)
    rmps[1] = rmp_first
    nc = length(def_line_colors)
    @inbounds for i in 2:np
        loop_name_karg = usename ? ((:name, string(cluster_ids[i])),) : ()
        rmps[i] = MergingPoints(
            ax, pts[i], min_width;
            pen = def_line_colors[ndx_wrap(i, nc)],
            loop_name_karg..., kwargs...
        )
    end
    if ismissing(director)
        ad = ArtDirector(rmps)
        connect_callbacks(ax, ad, listen_ax; toplevel = false)
    else
        ad = director
        append_artists!(ad, rmps)
        foreach(
            ra -> connect_callbacks(ax, ra, listen_ax; toplevel = false),
            rmps
        )
    end
    toplevel && set_ax_home(ad)
    ad, rmps
end

function point_boxes_multi(
    ax::Axis,
    pts::AbstractVector{<:DynamicPointDownsampler},
    min_width::Number,
    y_offsets::AbstractVector{<:Number},
    args...; kwargs...
)
    boxers = DynamicPointBoxer.(pts, min_width, y_offsets)
    point_boxes_multi(ax, boxers, args...; kwargs...)
end

function point_boxes_multi(
    ax::Axis, pts::AbstractVector{<:Points}, args...; kwargs...
)
    point_boxes_multi(ax, DynamicPointDownsampler.(pts), args...; kwargs...)
end

function point_boxes_multi(
    ax::Axis,
    pttimes::AbstractVector{<:AbstractVector{<:Number}},
    ptmarks::AbstractVector{<:AbstractVector{<:Number}},
    args...; kwargs...
)
    point_boxes_multi(ax, VariablePoints.(pttimes, ptmarks), args...; kwargs...)
end

struct MergingPoints{T<:DynamicPointBoxer, P<:PlotLib} <: ResizeableArtist{T, P}
    dynamicpoints::T
    baseinfo::RABaseInfo{P}
    function MergingPoints{T,P}(
        dts::T, baseinfo::RABaseInfo{P}; plotkwargs...
    ) where {T<:DynamicPointBoxer, P<:MPL}
        new(dts, baseinfo)
    end
    function MergingPoints{T,P}(
        dynamicpoints::T, baseinfo::RABaseInfo{P}; plotkwargs...
    ) where {T<:DynamicPointBoxer, P<:PQTG}
        r = new(dynamicpoints, baseinfo)
        push!(r.baseinfo.artists, Artist{P}(DownsampCurve(
            r, connect = "finite"; plotkwargs...
        )))
        r.baseinfo.artists[1].artist.setZValue(-1.0)
        r
    end
end

# Pull type parameters
function MergingPoints(
    dynamicpoints::T, ra::R; plotkwargs...
) where {T<:DynamicPointBoxer, P, R<:RABaseInfo{P}}
    MergingPoints{T, P}(dynamicpoints, ra; plotkwargs...)
end

function MergingPoints(dpb::DynamicPointBoxer, args...; plotkwargs...)
    MergingPoints(dpb, RABaseInfo(args...); plotkwargs...)
end

function MergingPoints(
    ax::Axis{P}, dts::DynamicPointBoxer, args...;
    plotargs::Vector{Any} = [], plotkwargs...
) where {P<:PQTG}
    xbounds = bounds(time_interval(dts))
    ybounds = extrema(dts)
    artists = Vector{Artist{P}}()
    return MergingPoints(dts, ax, artists, xbounds, ybounds; plotkwargs...)
end

function MergingPoints(
    ax::Axis{P},
    dts::DynamicPointBoxer,
    args...;
    plotargs::Vector{Any} = [],
    plotkwargs...
) where {P<:MPL}
    plotline = make_dummy_line(ax, plotargs...; plotkwargs...)
    artists = [plotline]
    MergingPoints(
        dts, ax, artists, bounds(time_interval(dts)), extrema(dts)
    )
end

function MergingPoints(
    ax::Axis,
    pts::Points,
    min_width,
    y_center = 0,
    args...;
    plotargs::Vector{Any} = [],
    plotkwargs...
)
    dts = DynamicPointBoxer(pts, min_width, y_center)
    MergingPoints(
        ax, dts, args...; plotargs = plotargs, plotkwargs...
    )
end

function MergingPoints(
    ax::Axis,
    xpts::AbstractVector{<:Number},
    heights::AbstractVector{<:Number},
    args...;
    kwargs...
)
    MergingPoints(
        ax, VariablePoints(xpts, heights), args...; kwargs...
    )
end

downsampler(r::MergingPoints) = r.dynamicpoints

# Does not check that xlefts, ybottoms, or heights are the same size
function box_points(
    xlefts::AbstractVector{X},
    ybottoms::AbstractVector{Y},
    widths::AbstractVector,
    heights::AbstractVector
) where {X<:AbstractFloat, Y<:AbstractFloat}
    nin = length(xlefts)
    npt = 6 * nin
    @compat xs = Vector{X}(undef, npt)
    @compat ys = Vector{Y}(undef, npt)
    connect = fill(true, npt)
    @inbounds @simd for i_in in 1:nin
        left = xlefts[i_in]
        right = left + widths[i_in]

        bottom = ybottoms[i_in]
        top = bottom + heights[i_in]

        i_out = (i_in - 1) * 6 + 1

        # Bottom left (twice, second time to close)
        xs[i_out] = xs[i_out + 4] = left
        ys[i_out] = ys[i_out + 4] = bottom
        # Top left
        xs[i_out + 1] = left
        ys[i_out + 1] = top
        # Top right
        xs[i_out + 2] = right
        ys[i_out + 2] = top
        # Bottom right
        xs[i_out + 3] = right
        ys[i_out + 3] = bottom
    end
    # Blanking
    xs[6:6:end] .= NaN
    ys[6:6:end] .= NaN
    connect[6:6:end] .= false
    xs, ys, connect
end

function make_plotdata(dp::DynamicPointBoxer, xstart, xend, pixwidth, res)
    xpts, marks, wd = downsamp_req(dp, xstart, xend, res)
    box_points(xpts, marks...)
end

function update_artists(ra::MergingPoints{<:Any,PQTG}, xpt, ypt, connect)
    ra.baseinfo.artists[1].artist.setData(xpt, ypt, connect = connect)
end

function update_artists(ra::MergingPoints{<:Any,MPL}, xpt, ypt, args...)
    ra.baseinfo.artists[1].artist.set_data(xpt, ypt)
end
