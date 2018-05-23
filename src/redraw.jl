function connect_callbacks(
    ax::Axis{P},
    ra::Union{<:ResizeableArtist{<:Any,P}, <:ArtDirector{<:Any,P,<:Any,<:Any}},
    listen_ax::AbstractVector{<:Axis{P}} = [ax];
    toplevel::Bool = true
) where {P<:MPL}
    ax.ax[:set_autoscale_on](false)
    toplevel && set_ax_home(ra)
    update_fnc = (x) -> axis_lim_changed(ra, Axis{P}(x))
    for lax in listen_ax
        conn_fnc = lax.ax[:callbacks][:connect]::PyCall.PyObject
        conn_fnc("xlim_changed", update_fnc)
        conn_fnc("ylim_changed", update_fnc) # TODO: Is this necessary?
    end
    axis_lim_changed(ra, ax)
end

function connect_callbacks(
    ax::Axis{P},
    ra::Union{<:ResizeableArtist{<:Any,P}, <:ArtDirector{<:Any,P,<:Any,<:Any}},
    args...;
    toplevel::Bool = true
) where {P<:PQTG}
    ax.ax[:enableAutoRange](false, false)
    toplevel && set_ax_home(ra)
    connect_artists(ax, ra)
end

function connect_artists(ax::Axis{P}, ra::ResizeableArtist{<:Any,P}) where
    {P<:PQTG}
    foreach((x)-> ax.ax[:addItem](x.artist), ra.baseinfo.artists)
end

function connect_artists(
    ax::Axis{P}, ra::ArtDirector{<:Any,P,<:Any,<:Any}
) where {P<:PQTG}
    foreach((x) -> connect_artists(ax, x), ra.artists)
end
