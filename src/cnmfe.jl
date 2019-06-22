function plot_cnmfe_results!(
    ax,
    xs::AbstractVector{<:Number},
    raw::AbstractVector{<:Number},
    denoised::AbstractVector{<:Number},
    deconved::AbstractVector{<:Number};
    spkscale = 1/90,
    addxlabel = true,
    addylabel = true,
    addlegend = true,
)
    hr = ax.plot(xs, raw, label = "raw")
    hn = ax.plot(xs, denoised, label = "de-noised")
    res = glstem_zeros!(
        ax, xs, spkscale * deconved, color = "C2", label = "de-convolved"
    )

    addxlabel && ax.set_xlabel("Time (s)")
    addylabel && ax.set_ylabel("Fluorescence")
    addlegend && ax.legend()

    hr, hn, res
end

function plot_cnmfe_results!(
    ax,
    raw::AbstractVector{<:AbstractMatrix},
    denoised::AbstractVector{<:AbstractMatrix},
    deconved::AbstractVector{<:AbstractMatrix},
    fno::Integer,
    cellno::Integer,
    frames::AbstractVector{<:Integer},
    fps;
    addtitle = false,
    kwargs...
)
    xs = (0:length(frames) - 1) / fps
    res = plot_cnmfe_results!(
        ax,
        xs,
        view(raw[fno], cellno, frames),
        view(denoised[fno], cellno, frames),
        view(deconved[fno], cellno, frames);
        kwargs...
    )
    if addtitle
        ax.set_title("Cell $cellno File $fno Frames $(frames[1])-$(frames[end])")
    end
    res
end
