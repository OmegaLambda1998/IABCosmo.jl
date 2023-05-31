module RunModule

# External Packages
using JLACovarianceMatrix
using SALTJacobian

# Internal Packages
include("SimulatorModule.jl")
using .SimulatorModule

# Exports
export run_IABCosmo

function get_covariance_matrix(toml::Dict{String, Any})
    config = get(toml, "COVARIANCEMATRIX", Dict{String, Any}())
    name = get(config, "NAME", "DES")
    input = joinpath(toml["GLOBAL"]["OUTPUT_PATH"], "$(name).jld2")
    if isfile(input)
        covariance_matrix = loadCovarianceMatrix(input)
    else
        covariance_matrix = run_JLACovarianceMatrix(toml)
    end
    return covariance_matrix
end

function run_IABCosmo(toml::Dict{String, Any})
    covariance_matrix = get_covariance_matrix(toml)
    jacobian, _ = run_SALTJacobian(toml)
    simulator = Simulator(toml["SIM"], covariance_matrix, jacobian, toml["GLOBAL"])
    num_sims = get(toml["SIM"], "SIMULATE", 0)
    for sim in 1:num_sims
        simulate(simulator, sim)
    end
end

end
