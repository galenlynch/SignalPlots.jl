"""
    point_boxes

Plot a set of points with boxes around each point, merging if necessary.
"""
function point_boxes(
    ax::A, args...;
    listen_ax::Vector{A} = [ax], toplevel::Bool = true, kwargs...
) where A<:Axis
    rmp = MergingPoints(ax, args...; kwargs...)
    connect_callbacks(ax, rmp, listen_ax; toplevel = toplevel)
    rmp
end

function point_boxes_multi(
    ax::A,
    pts::AbstractVector{<:DynamicPointDownsampler},
    y_offsets::AbstractVector{<:Number},
    min_width::Number = 0;
    listen_ax::Vector{A} = [ax], toplevel::Bool = true, kwargs...
) where A<:Axis
    np = length(pts)
    np > 0 || throw(ArgumentError("np can not be empty"))
    np == length(y_offsets) || throw(ArgumentError("y_offsets not the same length"))
    rmp_first = MergingPoints(ax, pts[1], y_offsets[1], min_width; kwargs...)
    rmps = Vector{typeof(rmp_first)}(np)
    rmps[1] = rmp_first
    @inbounds for i in 2:np
        rmps[i] = MergingPoints(ax, pts[i], y_offsets[i], min_width; kwargs...)
    end
    ad = ArtDirector(rmps)
    connect_callbacks(ax, ad, listen_ax; toplevel = toplevel)
    ad, rmps
end

struct MergingPoints{T<:DynamicPointBoxer, P<:PlotLib} <: ResizeableArtist{T, P}
    dynamicpoints::T
    baseinfo::RABaseInfo{P}
    function MergingPoints{T,P}(
        dts::T, baseinfo::RABaseInfo{P}
    ) where {T<:DynamicPointBoxer, P<:MPL}
        new(dts, baseinfo)
    end
    function MergingPoints{T,P}(
        dynamicpoints::T, baseinfo::RABaseInfo{P}
    ) where {T<:DynamicPointBoxer, P<:PQTG}
        r = new(dynamicpoints, baseinfo)
        push!(r.baseinfo.artists, Artist{P}(DownsampCurve(r, connect = "finite")))
        r
    end
end

# Pull type parameters
function MergingPoints(
    dynamicpoints::T, ra::R
) where {T<:DynamicPointBoxer, P, R<:RABaseInfo{P}}
    MergingPoints{T, P}(dynamicpoints, ra)
end

function MergingPoints(dpb::DynamicPointBoxer, args...)
    MergingPoints(dpb, RABaseInfo(args...))
end

function MergingPoints(
    ax::Axis{P}, dts::DynamicPointBoxer, args...;
    plotargs::Vector{Any} = [], plotkwargs...
) where {P<:PQTG}
    xbounds = time_interval(dts)
    ybounds = extrema(dts)
    artists = Vector{Artist{P}}()
    return MergingPoints(dts, ax, artists, xbounds, ybounds)
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
        dts, ax, artists, time_interval(dts), extrema(dts)
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
    MergingPoints(ax, VariablePoints(xpts, heights), args...; kwargs...)
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
    xs = Vector{X}(npt)
    ys = Vector{Y}(npt)
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
    xs[6:6:end] = NaN
    ys[6:6:end] = NaN
    connect[6:6:end] = false
    xs, ys, connect
end

function make_plotdata(dp::DynamicPointBoxer, xstart, xend, pixwidth)
    xpts, marks, wd = downsamp_req(dp, xstart, xend, pixwidth)
    box_points(xpts, marks...)
end

function update_artists(ra::MergingPoints{<:Any,PQTG}, xpt, ypt, connect)
    ra.baseinfo.artists[1].artist[:setData](xpt, ypt, connect = connect)
end
