using GLPlotting, WAV, PyPlot, PyCall

using GLPlotting: ResizeableArtist

datapath = "/home/glynch/Documents/Data/Screening/song_imitation"
fnames = ["tutor.wav", "subsong.wav", "plastic_song.wav", "imitation.wav"]
figdpi = 120
figsize = (8.5, 5)
showfigures = true
clim = [-85, -40]
offsets = [0, 0, 0, 0.35]

pygui(showfigures)
nf = length(fnames)

f, axs = subplots(nf, 1, sharex = true, figsize = figsize, dpi = figdpi)
gl_axs = Axis{MPL}.(axs)

rspecs = Vector{ResizeableArtist}(undef, nf)
sb_f = Vector{Union{Nothing, PyObject}}(undef, nf)
sb_t = similar(sb_f)
sig_l = Vector{Float64}(undef, nf)

for (i, fname) in enumerate(fnames)
    pname = joinpath(datapath, fname)
    s, fs, nbits, opt = wavread(pname)
    sarr = dropdims(s, dims = 2)
    sig_l[i] = (length(sarr) - 1) / fs
    rspecs[i], sb_f[i], sb_t[i] = plot_example_spectrogram(
        gl_axs[i],
        sarr,
        offsets[i];
        fs = fs,
        clim = clim,
        listen_ax = gl_axs,
        f_scalebar = i == 1,
        t_scalebar = i == nf,
        time_scalebar_pos = [0.95, 0.2],
        title = false,
        cmap = "gray_r",
        binsize = 1024,
    )
end
axs[1].set_xlim(0, maximum(sig_l .- offsets))
