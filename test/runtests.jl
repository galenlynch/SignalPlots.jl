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

        @test plot_offsets(2, 1) == 0:1
        @test plot_offsets(2, 1, 1) == 1:2
        @test plot_offsets(B) == 0:1.2:1.2
    end

    const npt = 10000
    const A = rand(npt)
    const fs = 100

    @testset "downsampplot" begin
        dts = CachingDynamicTs(A, fs)
        (xs, ys) = downsamp_req(dts, 0, 1, 10)
        GLPlotting.to_patch_plot_coords(xs, ys)
        cb = GLPlotting.make_cb(dts)
        cb = GLPlotting.make_cb(A, fs)
        cb(0, 1, 10)
        (fig, ax) = subplots()
        downsamp_patch(ax, A, fs)
        ax[:set_xlim]([0, n_points_duration(npt, fs)])
        ax[:set_ylim]([extrema(A)...])
        plt[:show]()
    end

    @testset "verticallyspaced" begin
        fillshape = (2,)
        B = fill(A, fillshape)
        fss = fill(fs, fillshape)
        (fig, ax) = subplots()
        (artists, xlimits, ylimits) = plot_vertical_spacing(ax, B, fss)
        ax[:set_xlim](xlimits)
        ax[:set_ylim](ylimits)
        plt[:show]()
    end

    @testset "spectrogram" begin
        ds = DynamicSpectrogram(A, fs)
        downsamp_req(ds, 0, 1, 10)
        cb = GLPlotting.make_spec_cb(ds, [0, 10])
        cb(0.0, 99.99, 503.0)
        cb2 = GLPlotting.make_spec_cb(A, fs)
        cb2(0, 1, 10)
        (fig, ax) = subplots()
        const B = sin.(2 * pi * 10 .* (1:npt) ./ fs) .+ 0.1 .* randn(npt)
        resizeable_spectrogram(ax, B, fs)
        ax[:set_xlim]([0, 100])
        plt[:show]()
    end
end
