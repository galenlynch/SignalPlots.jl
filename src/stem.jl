function stem!(
    ax,
    xs,
    ys,
    xbnds = collect(extrema(xs));
    color = "C0",
    linestyle = "-.",
    plotmarker = "o",
    label = "",
    kwargs...,
)
    markerline, stemlines, baseline = ax.stem(
        xs,
        ys,
        "$(color)$(linestyle)",
        "$(color)$(plotmarker)",
        label = label,
        kwargs...,
    )
    baseline.set_xdata(xbnds)
    baseline.set_color(color)

    markerline, stemlines, baseline
end

function stem_zeros!(
    ax,
    xs,
    ys,
    xbnds = collect(extrema(xs));
    color = "C0",
    linestyle = "-.",
    plotmarker = "o",
    kwargs...,
)
    nzmask = ys .!= 0
    if any(nzmask)
        stem!(
            ax,
            xs[nzmask],
            ys[nzmask],
            xbnds;
            color = color,
            linestyle = linestyle,
            plotmarker = plotmarker,
            kwargs...,
        )
    else
        ax.plot(xbnds, [0, 0]; color = color, kwargs...)
    end
end
