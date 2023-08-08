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

function get_salt_models(covariance_matrix::CovarianceMatrix, jacobian::Jacobian, num_sims::Int64)
    offsets = draw_covariance_matrix(covariance_matrix, num_sims)
end

function fix_n(pippin_template::OrderedDict{String,Any}, n::Int64)
    for key in keys(pippin_template)
        value = fix_n(pippin_template[key], n)
        if contains(key, "__n__")
            key = replace(key, "__n__" => "_$n")
        end
        pippin_template[key] = value
    end
    return pippin_template
end

function fix_n(pippin_template::String, n::Int64)
    return replace(pippin_template, "__n__" => "_$n")
end

function fix_n(pippin_template::Vector, n::Int64)
    return fix_n.(pippin_template, n)
end

function fix_n(pippin_template, n::Int64)
    return pippin_template
end

function prep_template(pippin_template::OrderedDict{String,Any}, num_sims::Int64)
    # Set up num_sims simulations and propegate that number throughout
    for key in keys(pippin_template)
        if contains(key, "__n__")
            for n in 1:num_sims
                value = deepcopy(pippin_template[key])
                new_value = fix_n(value, n)
                new_key = replace(key, "__n__" => "_$n")
                pippin_template[new_key] = new_value
            end
            delete!(pippin_template, key)
        else
            value = pippin_template[key]
            if typeof(value) <: OrderedDict
                prep_template(value, num_sims)
            end
        end
    end
    # Replace __saltmodel__n with a filepath to a saltmodel
    return pippin_template
end

function Simulator(config::Dict{String,Any}, covariance_matrix::CovarianceMatrix, jacobian::Jacobian, global_config::Dict{String,Any})
    pippin_template_input = config["PIPPIN_TEMPLATE"]
    if !isabspath(pippin_template_input)
        pippin_template_input = joinpath(global_config["BASE_PATH"], pippin_template_input)
    end
    num_sims = get(config, "SIMULATE", 0)
    salt_models = get_salt_models(covariance_matrix, jacobian, num_sims)
    pippin_template = YAML.load_file(abspath(pippin_template_input); dicttype=OrderedDict{String,Any})
    pippin_template = prep_template(pippin_template, num_sims)
    output = joinpath(global_config["OUTPUT_PATH"], basename(pippin_template_input))
    @info "Saving pippin template to $output"
    YAML.write_file(output, pippin_template)
    return Simulator(pippin_template, covariance_matrix, jacobian)
end

function simulate(simulator::Simulator, sim_num::Int64)
    return nothing
end

end
