using Test
using DynamicTimeseries: CacheAccessor, CachingStftPsd, DynamicPointBoxer,
                         DynamicPointDownsampler, MaxMin, downsamp_req
using EventIntervals: VariablePoints
using PyQtGraph: QtApp, get_viewbox, pg
using PythonPlot: colorbar, gca, plotclose, pyplot, subplots
using SignalPlots

const app = QtApp()
const HEADLESS = get(ENV, "CI", "") != "" || get(ENV, "HEADLESS", "") != ""

const npt = 10000
const A = rand(npt)
const fs = 100
const dts = CacheAccessor(MaxMin, A, fs)
const wl = 512

const ds = CachingStftPsd(A, wl, fs)

@testset "SignalPlots" begin

    @testset "ts and spikes" begin

        fillshape = (2,)
        dynamic_tss = fill(dts, fillshape)

        qtplt = pg.plot()
        vb = get_viewbox(qtplt)
        qtax = Axis{PQTG}(vb)
        ad, qtartists, y_offsets = plot_vertical_spacing(qtax, dynamic_tss)

        ptts = fill(rand(20), 2)
        ptmarks = fill(rand(20), 2)

        _, rabs = point_boxes_multi(
            qtax,
            ptts,
            ptmarks,
            0.0015,
            y_offsets;
            director = ad,
            toplevel = false,
        )

        HEADLESS || app(qtplt)

    end

    @testset "util" begin
        C = [0, 1]
        B = fill(C, (2,))
        @test plot_spacing(C) == 0.6
        @test plot_spacing(C, 1.2) == 0.6
        @test plot_spacing(C, 0) == 0
        @test plot_spacing(B) == 1.2

        @test plot_offsets(2, 1) == collect(0:1)
        @test plot_offsets(2, 1, 1) == collect(1:2)
        @test plot_offsets(B) == collect(0:1.2:1.2)
    end

    @testset "pyqtgraph" begin

        qtplt = pg.plot()
        vb = get_viewbox(qtplt)
        qtax = Axis{PQTG}(vb)

        downsamp_patch(qtax, dts)
        HEADLESS || app(vb)
    end

    @testset "resizeableartists" begin
        xs = [1, 2]
        ys = [(1, 2), (3, 4)]
        resx = [1, 1, 2, 2]
        resy = [1, 2, 3, 4]
        @test SignalPlots.fill_points(xs, ys, true) == (resx, resy)
        @test SignalPlots.fill_points(xs, ys, false) == ([1, 2], [1, 3])
        ax = Axis{MPL}(gca())
        try
            lineartist = SignalPlots.make_dummy_line(ax)
            rabase = SignalPlots.RABaseInfo(ax, lineartist, (0.0, 1.0), (0.0, 1.0))
            rabase = SignalPlots.RABaseInfo(ax, lineartist, (0, 1), (0.0, 1.0))
            rp = SignalPlots.ResizeablePatch(dts, rabase)
            rp = SignalPlots.ResizeablePatch(ax, dts, lineartist, (0.0, 1.0), (0.0, 1.0))
            rs = SignalPlots.ResizeableSpec(ax, ds)
            rs = SignalPlots.ResizeableSpec(ax, A, fs)
            SignalPlots.axis_lim_changed(rp, ax)
        finally
            plotclose()
        end
    end


    @testset "boxplot" begin

        pttimes = rand(20)
        ptamps = rand(20)
        qtplt = pg.plot()
        vb = get_viewbox(qtplt)
        qtax = Axis{PQTG}(vb)

        pts_1 = VariablePoints(pttimes, ptamps)

        dpds = DynamicPointDownsampler(pts_1)
        dpb = DynamicPointBoxer(dpds, 0.01)

        ra = point_boxes(qtax, pttimes, ptamps, 0.01, 0.0)

        HEADLESS || app(qtplt)

        qtplt = pg.plot()
        vb = get_viewbox(qtplt)
        qtax = Axis{PQTG}(vb)

        pttimes_2 = rand(20)
        pts_2 = VariablePoints(pttimes_2, ptamps)
        ad, ram = point_boxes_multi(qtax, [pts_1, pts_2], 0.01, [0, 1])
        HEADLESS || app(qtplt)
    end

    @testset "boxplot_mpl" begin
        pttimes = rand(20)
        ptamps = rand(20)

        (fig, ax) = subplots()
        ax = Axis{MPL}(ax)
        try
            ra = point_boxes(ax, pttimes, ptamps, 0.01, 0.0)

            pts_1 = VariablePoints(pttimes, ptamps)
            pttimes_2 = rand(20)
            pts_2 = VariablePoints(pttimes_2, ptamps)
            ad, ram = point_boxes_multi(ax, [pts_1, pts_2], 0.01, [0, 1])
            HEADLESS || pyplot.show()
        finally
            plotclose()
        end
    end

    @testset "downsampplot" begin
        (xs, ys, was_downsamped) = downsamp_req(dts, 0, 1, 10)
        (fig, ax) = subplots()
        ax = Axis{MPL}(ax)
        try
            rp = downsamp_patch(ax, dts)
            HEADLESS || pyplot.show()
        finally
            plotclose()
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
            plotclose()
        end
        (fig, ax) = subplots()
        ax = Axis{MPL}(ax)
        try
            dynamic_tss = fill(dts, fillshape)

            qtplt = pg.plot()
            vb = get_viewbox(qtplt)
            qtax = Axis{PQTG}(vb)
            qtartists = plot_vertical_spacing(qtax, dynamic_tss)

            artists = plot_vertical_spacing(ax, dynamic_tss)
            HEADLESS || pyplot.show()
        finally
            plotclose()
        end
    end

    @testset "spectrogram" begin

        B = sin.(2 * pi * 10 .* (1:npt) ./ fs) .+ 0.1 .* randn(npt)

        qtplt = pg.plot()
        vb = get_viewbox(qtplt)
        qtax = Axis{PQTG}(vb)

        rs = resizeable_spectrogram(qtax, B, fs)
        HEADLESS || app(qtplt)

        (fig, ax) = subplots()
        ax = Axis{MPL}(ax)
        try
            rspec = resizeable_spectrogram(ax, B, fs)
            HEADLESS || pyplot.show()
        finally
            plotclose()
        end
        (fig, ax) = subplots()
        ax = Axis{MPL}(ax)
        try
            rspec = resizeable_spectrogram(ax, B, fs, 0, frange = [7, 13])
            colorbar(rspec.baseinfo.artists[1].artist)
            HEADLESS || pyplot.show()
        finally
            plotclose()
        end
        (fig, ax) = subplots()
        ax = Axis{MPL}(ax)
        try
            rspec = resizeable_spectrogram(ax, B, fs, 0, frange = [7, 13], clim = [-20, 0])
            colorbar(rspec.baseinfo.artists[1].artist)
            HEADLESS || pyplot.show()
        finally
            plotclose()
        end
    end
end
