using NeuroPlots
using Documenter

DocMeta.setdocmeta!(NeuroPlots, :DocTestSetup, :(using NeuroPlots); recursive=true)

makedocs(;
    modules=[NeuroPlots],
    authors="Galen Lynch <galen@galenlynch.com>",
    sitename="NeuroPlots.jl",
    format=Documenter.HTML(;
        canonical="https://galenlynch.github.io/NeuroPlots.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/galenlynch/NeuroPlots.jl",
    devbranch="main",
)
