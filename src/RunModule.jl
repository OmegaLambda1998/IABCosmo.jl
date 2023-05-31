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
    @debug "Testing if Covariance Matrix $input exists"
    if isfile(input)
        @info "Loading Covariance Matrix from $input"
        covariance_matrix = loadCovarianceMatrix(input)
    else
        covariance_matrix = run_JLACovarianceMatrix(toml)
    end
    return covariance_matrix
end

function get_jacobian(toml::Dict{String, Any})
    config = get(toml, "JACOBIAN", Dict{String, Any}())
    name = get(config, "NAME", "jacobian")
    if !occursin("jacobian", name)
        name *= "_jacobian"
    end
    input = joinpath(toml["GLOBAL"]["OUTPUT_PATH"], "$(name).jld2") 
    @debug "Testing if Jacobian $input exists"
    if isfile(input)
        @info "Loading Jacobian from $input"
        toml["JACOBIAN"]["JACOBIAN_PATH"] = input
    end
    jacobian, _ = run_SALTJacobian(toml)
    return jacobian
end

function run_IABCosmo(toml::Dict{String, Any})
    covariance_matrix = get_covariance_matrix(toml)
    jacobian = get_jacobian(toml)
    simulator = Simulator(toml["SIM"], covariance_matrix, jacobian, toml["GLOBAL"])
    num_sims = get(toml["SIM"], "SIMULATE", 0)
    for sim in 1:num_sims
        simulate(simulator, sim)
    end
end

end
