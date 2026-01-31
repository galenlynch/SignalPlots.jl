using SignalPlots
using Documenter

DocMeta.setdocmeta!(SignalPlots, :DocTestSetup, :(using SignalPlots); recursive=true)

makedocs(;
    modules=[SignalPlots],
    authors="Galen Lynch <galen@galenlynch.com>",
    sitename="SignalPlots.jl",
    format=Documenter.HTML(;
        canonical="https://galenlynch.github.io/SignalPlots.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/galenlynch/SignalPlots.jl",
    devbranch="main",
)
