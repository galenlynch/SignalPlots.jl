abstract type PlotLib end

struct MPL <: PlotLib end
struct PQTG <: PlotLib end

struct Axis{P<:PlotLib}
    ax::PyObject
end

struct Artist{P<:PlotLib}
    artist::PyObject
end

struct GView{P<:PlotLib}
    gview::PyObject
end

