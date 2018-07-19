using PyCall

using GLPlotting, PyPlot, GLUtilities, GLTimeseries, PyQtGraph, PointProcesses

using Base.Test

const app = QtApp()

const npt = 10000
const A = rand(npt)
const fs = 100
const dts = CacheAccessor(MaxMin, A, fs)
const wl = 512

const ds = CachingStftPsd(A, wl, fs)

@testset "GLPlotting"  begin

    @testset "ts and spikes" begin
        fillshape = (2,)
        dynamic_tss = fill(dts, fillshape)

        const qtplt = pg[:plot]()
        const vb = get_viewbox(qtplt)
        const qtax = Axis{PQTG}(vb)
        ad, qtartists, y_offsets = plot_vertical_spacing(qtax, dynamic_tss)

        ptts = fill(rand(20), 2)
        ptmarks = fill(rand(20), 2)

        _, rabs = point_boxes_multi(
            qtax, ptts, ptmarks, 0.0015, y_offsets;
            director = ad, toplevel = false
        )

        app(qtplt)

    end

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

    @testset "pyqtgraph" begin

        const qtplt = pg[:plot]()
        const vb = get_viewbox(qtplt)
        const qtax = Axis{PQTG}(vb)

        downsamp_patch(qtax, dts)
        app(vb)
    end

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
        ax = Axis{MPL}(gca())
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


    @testset "boxplot" begin

        pttimes = rand(20)
        ptamps = rand(20)
        const qtplt = pg[:plot]()
        const vb = get_viewbox(qtplt)
        const qtax = Axis{PQTG}(vb)

        pts_1 = VariablePoints(pttimes, ptamps)

        dpds = DynamicPointDownsampler(pts_1)
        dpb = DynamicPointBoxer(dpds, 0.01)

        ra1 = point_boxes(qtax, dpb, 0.01)
        ra = point_boxes(qtax, pttimes, ptamps, 0.01, 0.0)

        app(qtplt)

        const qtplt = pg[:plot]()
        const vb = get_viewbox(qtplt)
        const qtax = Axis{PQTG}(vb)

        pttimes_2 = rand(20)
        pts_2 = VariablePoints(pttimes_2, ptamps)
        ad, ram = point_boxes_multi(qtax, [pts_1, pts_2], 0.01, [0, 1])
        app(qtplt)
    end

    @testset "downsampplot" begin
        (xs, ys, was_downsamped) = downsamp_req(dts, 0, 1, 10)
        (fig, ax) = subplots()
        ax = Axis{MPL}(ax)
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
        ax = Axis{MPL}(ax)

        try
            ad, artists, y_offsets = plot_vertical_spacing(ax, B, fss)
        finally
            close()
        end
        (fig, ax) = subplots()
        ax = Axis{MPL}(ax)
        try
            dynamic_tss = fill(dts, fillshape)

            const qtplt = pg[:plot]()
            const vb = get_viewbox(qtplt)
            const qtax = Axis{PQTG}(vb)
            qtartists = plot_vertical_spacing(qtax, dynamic_tss)

            artists = plot_vertical_spacing(ax, dynamic_tss)
            plt[:show]()
        catch
            rethrow()
        end
    end

    @testset "spectrogram" begin
        const B = sin.(2 * pi * 10 .* (1:npt) ./ fs) .+ 0.1 .* randn(npt)

        const qtplt = pg[:plot]()
        const vb = get_viewbox(qtplt)
        const qtax = Axis{PQTG}(vb)
        const rs = resizeable_spectrogram(qtax, B, fs)
        app(qtplt)

        (fig, ax) = subplots()
        ax = Axis{MPL}(ax)
        try
            rspec = resizeable_spectrogram(ax, B, fs)
            plt[:show]()
        catch
            close()
            rethrow()
        end
        (fig, ax) = subplots()
        ax = Axis{MPL}(ax)
        try
            rspec = resizeable_spectrogram(ax, B, fs, 0, frange = [7, 13])
            colorbar(rspec.baseinfo.artists[1].artist)
            plt[:show]()
        catch
            close()
            rethrow()
        end
        (fig, ax) = subplots()
        ax = Axis{MPL}(ax)
        try
            rspec = resizeable_spectrogram(
                ax, B, fs, 0, frange = [7, 13], clim = [-20, 0]
            )
            colorbar(rspec.baseinfo.artists[1].artist)
            plt[:show]()
        catch
            close()
            rethrow()
        end
    end
end
