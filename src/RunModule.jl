module RunModule

# External Packages
using JLACovarianceMatrix
using SALTJacobian

# Internal Packages
include("SimulatorModule.jl")
using .SimulatorModule

# Exports
export run_IABCosmo

function run_IABCosmo(toml::Dict)
    covariance_matrix = run_JLACovarianceMatrix(toml)
    jacobian, _ = run_SALTJacobian(toml)
    simulator = Simulator(toml["SIM"], covariance_matrix, jacobian, toml["GLOBAL"])
    num_sims = get(toml["SIM"], "SIMULATE", 0)
    for sim in 1:num_sims
        simulate(simulator, sim)
    end
end

end
