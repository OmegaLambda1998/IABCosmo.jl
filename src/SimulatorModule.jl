# Simulator Module
module SimulatorModule

# Internal Packages 

# External Packages 
using JLACovarianceMatrix
using SALTJacobian

# Exports

struct Simulation
    covariance_matrix::CovarianceMatrix
    jacobian::Jacobian    
end



end
