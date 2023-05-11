module RunModule

# External Packages
using JLACovarianceMatrix
using SALTJacobian

# Internal Packages

# Exports
export run_IABCosmo

function run_IABCosmo(toml::Dict)
    covariance_matrix = run_JLACovarianceMatrix(toml)
    jacobian, _ = run_SALTJacobian(toml)
end

end
