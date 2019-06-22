function make_rect_patches(
    ints::AbstractVector{<:NTuple{2, <:Number}},
    ycenter,
    height = 1
)
    half_height = height / 2
    y_bottom = ycenter - half_height
    n_int = length(ints)
    rects = Vector{PyObject}(undef, n_int)
    for (i, (xb, xe)) in enumerate(ints)
        rects[i] = PyPlot.matplotlib.patches.Rectangle(
            (xb, y_bottom), xe - xb, height
        )
    end
    rects
end

function make_rect_patches(ints::AbstractVector{<:Interval}, args...)
    simple_ints = bounds.(ints)
    make_rect_patches(simple_ints, args...)
end

function circle_collection(xs, ys, rad)
    nx = length(xs)
    @argcheck nx == length(ys)
    patches = Vector{PyObject}(undef, nx)
    for i in 1:nx
        patches[i] = PyPlot.matplotlib.patches.Circle((xs[i], ys[i]), rad)
    end
    patches
end

function rect_collection(xs, ys, dx, dy)
    nx = length(xs)
    @argcheck nx == length(ys)
    patches = Vector{PyObject}(undef, nx)
    x_off = dx / 2
    y_off = dy / 2
    for i in 1:nx
        patches[i] = PyPlot.matplotlib.patches.Rectangle(
            (xs[i] - x_off, ys[i] - y_off), dx, dy
        )
    end
    patches
end

rect_collection(xs, ys, dx) = rect_collection(xs, ys, dx, dx)

const DMITRIY_XS = [-114.3, 0.0, 114.3]
const DMITRIY_YS = [0.0, 0.0, 0.0]

const PI_14_XS = [
    -98.9867, 98.9867, 98.9867, -98.9867, 98.9867, -98.9867,
    98.9867, 98.9867, -98.9867, 98.9867, -98.9867, 98.9867,
    98.9867, -98.9867
]
const PI_14_YS = [
    285.75, 400.05, 285.75, 171.45, 171.45, 57.15,
    57.15, -57.15, -57.15, -171.45, -171.45, -285.75,
    -400.05, -285.75
]

const PI_XS = [
    -98.9867, 98.9867, 0.0, 98.9867, -98.9867, 0.0, 98.9867, -98.9867, 0.0,
    98.9867, 0.0, 98.9867, 0.0, -98.9867, 98.9867, 0.0, -98.9867, 98.9867,
    0.0, 98.9867, -98.9867
]
const PI_YS = [
    285.75, 400.05, 342.9, 285.75, 171.45, 228.6, 171.45, 57.15, 114.3,
    57.15, 0.0, -57.15, -114.3, -57.15, -171.45, -228.6, -171.45, -285.75,
    -342.9, -400.05, -285.75
]
const PI_PITCH = 114.3

const FLEX_XS = [
    -130.0, 130.0, 0.0, 130.0, -130.0, 0.0, 130.0, -130.0, 0.0, 130.0, 0.0,
    130.0, 0.0, -130.0, 130.0, 0.0, -130.0, 130.0, 0.0, 130.0, -130.0
]
const FLEX_YS = [
    325.0, 455.0, 455.0, 325.0, 195.0, 325.0, 195.0, 65.0, 195.0, 65.0, 65.0,
    -65.0, -65.0, -65.0, -195.0, -195.0, -195.0, -325.0, -325.0, -455.0, -325.0
]
const FLEX_PITCH = 130

const HARBI_XS = [
    562.5, 487.5, 412.5, 337.5, 262.5, 187.5, 112.5, 37.5, -37.5, -112.5, -187.5,
    -262.5, -337.5, -412.5, -487.5, -562.5, 562.5, 487.5, 412.5, 337.5, 262.5,
    187.5, 112.5, 37.5, -37.5, -112.5, -187.5, -262.5, -337.5, -412.5, -487.5,
    -562.5, -562.5, -487.5, -412.5, -337.5, -262.5, -187.5, -112.5, -37.5, 37.5,
    112.5, 187.5, 262.5, 337.5, 412.5, 487.5, 562.5, -562.5, -487.5, -412.5,
    -337.5, -262.5, -187.5, -112.5, -37.5, 37.5, 112.5, 187.5, 262.5, 337.5,
    412.5, 487.5, 562.5
]

const HARBI_YS = [
    -125.0, -125.0, -125.0, -125.0, -125.0, -125.0, -125.0, -125.0, -125.0, -125.0,
    -125.0, -125.0, -125.0, -125.0, -125.0, -125.0, -375.0, -375.0, -375.0, -375.0,
    -375.0, -375.0, -375.0, -375.0, -375.0, -375.0, -375.0, -375.0, -375.0, -375.0,
    -375.0, -375.0, 125.0, 125.0, 125.0, 125.0, 125.0, 125.0, 125.0, 125.0, 125.0,
    125.0, 125.0, 125.0, 125.0, 125.0, 125.0, 125.0, 375.0, 375.0, 375.0, 375.0,
    375.0, 375.0, 375.0, 375.0, 375.0, 375.0, 375.0, 375.0, 375.0, 375.0, 375.0,
    375.0
]

const HARBI_PITCH = 75

function electrode_grid(assembly_type::Symbol; kwargs...)
    if assembly_type == :PI
        patches = circle_collection(PI_XS, PI_YS, PI_PITCH / 2)
    elseif assembly_type == :PI_14
        patches = circle_collection(PI_14_XS, PI_14_YS, PI_PITCH / 2)
    elseif assembly_type == :GRID
        patches = rect_collection(FLEX_XS, FLEX_YS, FLEX_PITCH)
    elseif assembly_type == :HARBI
        patches = circle_collection(
            HARBI_XS, HARBI_YS, HARBI_PITCH / 2
        )
    elseif assembly_type == :DMITRIY
        patches = circle_collection(DMITRIY_XS, DMITRIY_YS, PI_PITCH / 2)
    else
        error("Unrecognized assembly_type $assembly_type")
    end

    PyPlot.matplotlib.collections.PatchCollection(
        patches; match_original = false, kwargs...
    )
end
