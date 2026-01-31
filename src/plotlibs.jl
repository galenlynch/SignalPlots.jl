abstract type PlotLib end

struct MPL <: PlotLib end
struct PQTG <: PlotLib end

struct Axis{P<:PlotLib}
    ax::Py
end

struct Artist{P<:PlotLib}
    artist::Py
end

struct GView{P<:PlotLib}
    gview::Py
end
