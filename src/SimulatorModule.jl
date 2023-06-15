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


function prep_template(template::OrderedDict{String, Any}, num_sims::Int64, parent::Union{Nothing, OrderedDict{String, Any}}=nothing, n::Int64=0)
    for (k, v) in template
        if occursin("__n__", k)
            @show k, v, n
            delete!(template, k)
            if num_sims == 0
                new_k = replace(k, "__n__" => "") 
                template[new_k] = v
            else
                for i in 1:num_sims
                    new_k = replace(k, "__n__" => "_$i")
                    if typeof(v) <: OrderedDict
                        prep_template(v, num_sims, template, i)
                    elseif typeof(v) <: AbstractArray
                        v = [replace(str, "__n__" => "_$i") for str in v]
                    elseis typeof(v) <: AbstractString
                        v = replace(v, "__n__" => "_$i")
                    end
                    template[new_k] = v
                end
            end
        end
        if typeof(v) <: OrderedDict
            prep_template(v, num_sims, template, n)
        elseif typeof(v) <: AbstractArray
            if n == 0
                v = [replace(str, "__n__" => "") for str in v]
            else
                v = [replace(str, "__n__" => "_$n") for str in v]
            end
        elseif typeof(v) <: AbstractString
            if n == 0
                v = replace(v, "__n__" => "")
            else
                v = replace(v, "__n__" => "_$n")
            end 
        end
        template[k] = v
    end
    return template
end

function Simulator(config::Dict{String,Any}, covariance_matrix::CovarianceMatrix, jacobian::Jacobian, global_config::Dict{String,Any})
    pippin_template_input = config["PIPPIN_TEMPLATE"]
    if !isabspath(pippin_template_input)
        pippin_template_input = joinpath(global_config["BASE_PATH"], pippin_template_input)
    end
    num_sims = get(config, "SIMULATE", 0)
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
