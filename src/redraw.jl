function connect_callbacks(
    ax::Axis{P},
    ra::Union{<:ResizeableArtist{<:Any,P},<:ArtDirector{P,<:Any}},
    listen_ax::AbstractVector{<:Axis{P}} = [ax];
    toplevel::Bool = true,
) where {P<:MPL}
    ax.ax.set_autoscale_on(false)
    toplevel && set_ax_home(ra)
    update_fnc = (x) -> axis_lim_changed(ra, Axis{P}(x))
    for lax in listen_ax
        conn_fnc = lax.ax.callbacks.connect
        conn_fnc("xlim_changed", update_fnc)
        conn_fnc("ylim_changed", update_fnc) # TODO: Is this necessary?
    end
    axis_lim_changed(ra, ax)
    nothing
end

function connect_callbacks(
    ax::Axis{P},
    ra::Union{<:ResizeableArtist{<:Any,P},<:ArtDirector{P,<:Any}},
    args...;
    toplevel::Bool = true,
) where {P<:PQTG}
    ax.ax.enableAutoRange(false, false)
    toplevel && set_ax_home(ra)
    # Connect ViewBox sigRangeChanged signal to Julia callback
    update_fnc = (vb, ranges, changed) -> axis_lim_changed(ra, Axis{P}(vb))
    ax.ax.sigRangeChanged.connect(pyfunc(update_fnc))
    connect_artists(ax, ra)
    axis_lim_changed(ra, ax)
    nothing
end

function connect_artists(ax::Axis{P}, ra::ResizeableArtist{<:Any,P}) where {P<:PQTG}
    for a in ra.baseinfo.artists
        ax.ax.addItem(a.artist)
    end
    nothing
end

function connect_artists(ax::Axis{P}, ad::ArtDirector{P,<:Any}) where {P<:PQTG}
    for a in ad.artists
        connect_artists(ax, a)
    end
    nothing
end
