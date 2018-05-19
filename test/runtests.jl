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
        try
            lineartist = GLPlotting.make_dummy_line(ax)
            rabase = GLPlotting.RABaseInfo(ax, lineartist, (0.0, 1.0), (0.0, 1.0))
            rabase = GLPlotting.RABaseInfo(ax, lineartist, (0, 1), (0.0, 1.0))
            rp = GLPlotting.ResizeablePatch(dts, rabase)
            rp = GLPlotting.ResizeablePatch(ax, dts, lineartist, (0.0, 1.0), (0.0, 1.0))
            rs = GLPlotting.ResizeableSpec(ax, ds)
            rs = GLPlotting.ResizeableSpec(ax, A, fs)
            GLPlotting.axis_lim_changed(rp, ax)
        finally
            close()
        end
    end

    @testset "downsampplot" begin
        (xs, ys, was_downsamped) = downsamp_req(dts, 0, 1, 10)
        (fig, ax) = subplots()
        try
            rp = downsamp_patch(ax, dts)
            plt[:show]()
        catch
            close()
            rethrow()
        end
    end

    @testset "verticallyspaced" begin
        fillshape = (2,)
        B = fill(A, fillshape)
        fss = fill(fs, fillshape)
        (fig, ax) = subplots()
        try
            artists = plot_vertical_spacing(ax, B, fss)
        finally
            close()
        end
        (fig, ax) = subplots()
        try
            dynamic_tss = fill(dts, fillshape)
            artists = plot_vertical_spacing(ax, dynamic_tss)
            plt[:show]()
        catch
            close()
            rethrow()
        end
    end

    @testset "spectrogram" begin
        const B = sin.(2 * pi * 10 .* (1:npt) ./ fs) .+ 0.1 .* randn(npt)
        (fig, ax) = subplots()
        try
            rspec = resizeable_spectrogram(ax, B, fs)
            plt[:show]()
        catch
            close()
            rethrow()
        end
        (fig, ax) = subplots()
        try
            rspec = resizeable_spectrogram(ax, B, fs, 0, frange = [7, 13])
            colorbar(rspec.baseinfo.artists[1])
            plt[:show]()
        catch
            close()
            rethrow()
        end
        (fig, ax) = subplots()
        try
            rspec = resizeable_spectrogram(ax, B, fs, 0, frange = [7, 13], clim = [-20, 0])
            colorbar(rspec.baseinfo.artists[1])
            plt[:show]()
        catch
            close()
            rethrow()
        end
    end
end
