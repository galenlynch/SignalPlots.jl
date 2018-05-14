using GLPlotting, PyPlot, GLUtilities, GLTimeseries
using Base.Test

@testset "GLPlotting"  begin
    @testset "util" begin
        const C = [0, 1]
        const B = fill(C, (2,))
        @test plot_spacing(C) == 0.6
        @test plot_spacing(C, 1.2) == 0.6
        @test plot_spacing(C, 0) == 0
        @test plot_spacing(B) == 1.2

        @test plot_offsets(2, 1) == collect(0:1)
        @test plot_offsets(2, 1, 1) == collect(1:2)
        @test plot_offsets(B) == collect(0:1.2:1.2)
    end

    const npt = 10000
    const A = rand(npt)
    const fs = 100
    const dts = CachingDynamicTs(A, fs)
    const ds = DynamicSpectrogram(A, fs)

    @testset "resizeableartists" begin
        const xs = [1, 2]
        const ys = [(1, 2), (3, 4)]
        const resx = [1, 1, 2, 2]
        const resy = [1, 2, 3, 4]
        @test GLPlotting.fill_points(xs, ys, true) == (resx, resy)
        @test GLPlotting.fill_points(xs, ys, false) == (
            [1, 2],
            [1, 3]
        )
        ax = gca()
        lineartist = GLPlotting.make_dummy_line(ax)
        rabase = GLPlotting.RABaseInfo(ax, lineartist, (0.0, 1.0), (0.0, 1.0))
        rp = GLPlotting.ResizeablePatch(dts, rabase)
        rp = GLPlotting.ResizeablePatch(dts, ax, lineartist, (0.0, 1.0), (0.0, 1.0))
        GLPlotting.axis_lim_changed(rp, ax)
    end

    @testset "downsampplot" begin
        (xs, ys, was_downsamped) = downsamp_req(dts, 0, 1, 10)
        (fig, ax) = subplots()
        downsamp_patch(ax, A, fs)
        plt[:show]()
    end

    @testset "verticallyspaced" begin
        fillshape = (2,)
        B = fill(A, fillshape)
        fss = fill(fs, fillshape)
        (fig, ax) = subplots()
        (artists, xlimits, ylimits) = plot_vertical_spacing(ax, B, fss)
        plt[:show]()
    end

    @testset "spectrogram" begin
        (fig, ax) = subplots()
        const B = sin.(2 * pi * 10 .* (1:npt) ./ fs) .+ 0.1 .* randn(npt)
        rspec = resizeable_spectrogram(ax, B, fs)
        plt[:show]()
        cla()
        rspec = resizeable_spectrogram(ax, B, fs, 0, frange = [7, 13])
        colorbar(rspec.baseinfo.artists[1])
        plt[:show]()
        close(fig)
        (fig, ax) = subplots()
        rspec = resizeable_spectrogram(ax, B, fs, 0, frange = [7, 13], clim = [-20, 0])
        colorbar(rspec.baseinfo.artists[1])
        plt[:show]()
    end
end
