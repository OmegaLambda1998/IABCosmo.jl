# Simulator Module
module SimulatorModule

# Internal Packages 
using OrderedCollections
using YAML

# External Packages 
using JLACovarianceMatrix
using SALTJacobian

# Exports
export Simulator
export simulate

struct Simulator
    pippin_template::OrderedDict{String,Any}
    covariance_matrix::CovarianceMatrix
    jacobian::Jacobian
end

function Simulator(config::Dict{String,Any}, covariance_matrix::CovarianceMatrix, jacobian::Jacobian, global_config::Dict{String,Any})
    pippin_template_input = config["PIPPIN_TEMPLATE"]
    if !isabspath(pippin_template_input)
        pippin_template_input = joinpath(global_config["BASE_PATH"], pippin_template_input)
    end
    pippin_template = YAML.load_file(abspath(pippin_template_input); dicttype=OrderedDict{String,Any})
    @show pippin_template
    return Simulator(pippin_template, covariance_matrix, jacobian)
end

function simulate(simulator::Simulator, sim_num::Int64)
end

end
