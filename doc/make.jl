using Documenter
push!(LOAD_PATH, "../src/")
using IABCosmo

DocMeta.setdocmeta!(IABCosmo, :DocTestSetup, :(using IABCosmo); recursive=true)

makedocs(
    sitename="IABCosmo Documentation",
    modules = [IABCosmo],
    pages = [
        "IABCosmo" => "index.md",
    ],
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
    )
)

deploydocs(
    repo = "github.com/OmegaLambda1998/IABCosmo.jl.git"
)
