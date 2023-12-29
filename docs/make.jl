using WaterGiniF
using Documenter

DocMeta.setdocmeta!(WaterGiniF, :DocTestSetup, :(using WaterGiniF); recursive=true)

makedocs(;
    modules=[WaterGiniF],
    authors="Graham Stark",
    repo="https://github.com/grahamstark/WaterGiniF.jl/blob/{commit}{path}#{line}",
    sitename="WaterGiniF.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://grahamstark.github.io/WaterGiniF.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/grahamstark/WaterGiniF.jl",
    devbranch="main",
)
