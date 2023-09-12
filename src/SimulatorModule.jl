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

function offsets_to_trainopts(filter_offsets::Dict{String,Vector{Float64}}, zp_offsets::Dict{String,Vector{Float64}}, shift_map::Dict{String,Any})
    trainopts = Vector{Vector{String}}()
    for i in eachindex(collect(values(filter_offsets))[1])
        trainopt = Vector{String}()
        for (key, value) in filter_offsets
            filter..., band = split(key, "_")
            filter = join(filter, "_")
            if occursin("WAVESHIFT", get(shift_map, uppercase(filter), "WAVESHIFT MAGSHIFT"))
                push!(trainopt, "WAVESHIFT $filter $band $(value[i])")
            end
        end
        for (key, value) in zp_offsets
            filter..., band = split(key, "_")
            filter = join(filter, "_")
            if occursin("MAGSHIFT", get(shift_map, uppercase(filter), "WAVESHIFT MAGSHIFT"))
                push!(trainopt, "MAGSHIFT $filter $band $(value[i])")
            end
        end
        push!(trainopts, trainopt)
    end
    return trainopts
end

function get_salt_models(covariance_matrix::CovarianceMatrix, jacobian::Jacobian, num_sims::Int64, draw_config::Dict{String,Any}, global_config::Dict{String,Any})
    draw_config["NUM"] = num_sims
    offsets = draw_covariance_matrix(covariance_matrix, draw_config)
    trainopts = offsets_to_trainopts(offsets..., get(draw_config, "SHIFT_MAP", Dict{String,Any}()))
    name = get(draw_config, "NAME", "SALT2.JACOBIAN")
    options = [Dict{String,Any}("NAME" => name * "_$i", "MODE" => "combine", "TRAINOPTS" => trainopts[i]) for i in eachindex(trainopts)]
    surfaces = SALTJacobian.RunModule.surfaces_stage(options, jacobian, global_config)
    paths = [joinpath(global_config["OUTPUT_PATH"], "$(name)_$(i)", "TRAINOPT001.tar.gz") for i in eachindex(surfaces)]
    for (i, path) in enumerate(paths)
        tmp_path = SALTJacobian.RunModule.ToolModule.uncompress(path)
        uncompressed_path = joinpath(dirname(path), "TRAINOPT001/")
        mv(tmp_path, uncompressed_path, force=true)
        paths[i] = uncompressed_path
    end
    return paths
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

function fix_n(pippin_template, ::Int64)
    return pippin_template
end

function fix_saltmodel(pippin_template::OrderedDict{String,Any}, n::Int64, path::String)
    for key in keys(pippin_template)
        value = fix_saltmodel(pippin_template[key], n, path)
        if contains(key, "__saltmodel___$n")
            key = replace(key, "__saltmodel___$n" => path)
        end
        pippin_template[key] = value
    end
    return pippin_template
end

function fix_saltmodel(pippin_template::String, n::Int64, path::String)
    return replace(pippin_template, "__saltmodel___$n" => path)
end

function fix_saltmodel(pippin_template::Vector, n::Int64, path::String)
    return fix_saltmodel.(pippin_template, n, path)
end

function fix_saltmodel(pippin_template, ::Int64, ::String)
    return pippin_template
end


function prep_template(pippin_template::OrderedDict{String,Any}, paths::Vector{String}, num_sims::Int64)
    paths = sort(paths)
    # Set up num_sims simulations and propegate that number throughout
    for key in keys(pippin_template)
        if contains(key, "__n__")
            for n in 1:num_sims
                value = deepcopy(pippin_template[key])
                new_value = fix_n(value, n)
                new_value = fix_saltmodel(new_value, n, paths[n])
                new_key = replace(key, "__n__" => "_$n")
                pippin_template[new_key] = new_value
            end
            delete!(pippin_template, key)
        else
            value = pippin_template[key]
            if typeof(value) <: OrderedDict
                prep_template(value, paths, num_sims)
            end
        end
    end
    return pippin_template
end

function Simulator(config::Dict{String,Any}, covariance_matrix::CovarianceMatrix, jacobian::Jacobian, global_config::Dict{String,Any})
    pippin_template_input = config["PIPPIN_TEMPLATE"]
    if !isabspath(pippin_template_input)
        pippin_template_input = joinpath(global_config["BASE_PATH"], pippin_template_input)
    end
    num_sims = get(config, "PRESIMULATE", 0)
    draw_config = get(config, "DRAW", Dict{String,Any}())
    salt_models = get_salt_models(covariance_matrix, jacobian, num_sims, draw_config, global_config)
    pippin_template = YAML.load_file(abspath(pippin_template_input); dicttype=OrderedDict{String,Any})
    pippin_template = prep_template(pippin_template, salt_models, num_sims)
    output = joinpath(global_config["OUTPUT_PATH"], basename(pippin_template_input))
    @info "Saving pippin template to $output"
    YAML.write_file(output, pippin_template)
    return Simulator(pippin_template, covariance_matrix, jacobian)
end

function simulate(simulator::Simulator, sim_num::Int64)
    return nothing
end

end
