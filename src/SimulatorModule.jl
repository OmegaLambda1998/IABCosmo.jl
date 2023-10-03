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
    pippin_output::AbstractString
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


function get_offsets(covariance_matrix::CovarianceMatrix, jacobian::Jacobian, num_sims::Int64, draw_config::Dict{String,Any}, global_config::Dict{String,Any})
    draw_config["NUM"] = num_sims

    des_order = get(draw_config, "DES_ORDER", ["g", "r", "i", "z"])
    if des_order isa String
        des_order = split(des_order, "")
    end
    function compare_filter(s1::String, s2::String)
        index_1 = findfirst(x -> x == split(s1, " ")[3], des_order)
        index_2 = findfirst(x -> x == split(s2, " ")[3], des_order)
        return index_1 < index_2
    end

    offsets = draw_covariance_matrix(covariance_matrix, draw_config)
    all_trainopts = offsets_to_trainopts(offsets..., get(draw_config, "SHIFT_MAP", Dict{String,Any}()))
    name = get(draw_config, "NAME", "SALT2.JACOBIAN")
    paths = Vector{String}()
    zp_offsets = Vector{String}()
    mag_offsets = Vector{String}()
    paths = Vector{Vector{Float64}}()
    options = Vector{Dict{String, Any}}()
    for (i, trainopts) in enumerate(all_trainopts)
        jacobian_trainopts = [trainopt for trainopt in trainopts if join(split(trainopt, " ")[1:end-1], "-") in jacobian.trainopt_names]
        push!(options, Dict{String,Any}("NAME" => "SALT_MODELS/$(name)_$i", "MODE" => "combine", "TRAINOPTS" => jacobian_trainopts))
        des_zp_trainopts = [trainopt for trainopt in trainopts if occursin("DES", trainopt) && occursin("WAVESHIFT", trainopt)]
        sort!(des_zp_trainopts; lt=compare_filter)
        push!(zp_offsets, join([parse(Float64, split(trainopt, " ")[end]) for trainopt in des_zp_trainopts], " "))
        des_mag_trainopts = [trainopt for trainopt in trainopts if occursin("DES", trainopt) && occursin("MAGSHIFT", trainopt)]
        sort!(des_mag_trainopts; lt=compare_filter)
        push!(mag_offsets, join([parse(Float64, split(trainopt, " ")[end]) for trainopt in des_mag_trainopts], " "))
        missing_trainopts = [trainopt for trainopt in trainopts if !(trainopt in jacobian_trainopts) && !(trainopt in des_zp_trainopts) && !(trainopt in des_mag_trainopts)]
        @warn "The following trainopts are not being included as they are either not in the Jacobian, or not DES trainopts:\n$missing_trainopts"
    end
    surfaces = SALTJacobian.RunModule.surfaces_stage(options, jacobian, global_config)
    paths = [joinpath(global_config["OUTPUT_PATH"], "SALT_MODELS", "$(name)_$(i)", "TRAINOPT001.tar.gz") for i in eachindex(surfaces)]
    for (i, path) in enumerate(paths)
        tmp_path = SALTJacobian.RunModule.ToolModule.uncompress(path)
        uncompressed_path = dirname(path)
        mv(tmp_path, uncompressed_path, force=true)
        paths[i] = uncompressed_path
    end
    return paths, zp_offsets, mag_offsets
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

function fix_zp_offset(pippin_template::OrderedDict{String,Any}, n::Int64, zp_offsets::String)
    for key in keys(pippin_template)
        value = fix_zp_offset(pippin_template[key], n, zp_offsets)
        if contains(key, "__zp_offset___$n")
            key = replace(key, "__zp_offset___$n" => zp_offsets)
        end
        pippin_template[key] = value
    end
    return pippin_template
end

function fix_zp_offset(pippin_template::String, n::Int64, zp_offsets::String)
    return replace(pippin_template, "__zp_offset___$n" => zp_offsets)
end

function fix_zp_offset(pippin_template::Vector, n::Int64, zp_offsets::String)
    return [fix_zp_offset(template, n, zp_offsets) for template in pippin_template]
end

function fix_zp_offset(pippin_template, ::Int64, ::String)
    return pippin_template
end

function fix_mag_offset(pippin_template::OrderedDict{String,Any}, n::Int64, mag_offsets::String)
    for key in keys(pippin_template)
        value = fix_mag_offset(pippin_template[key], n, mag_offsets)
        if contains(key, "__mag_offset___$n")
            key = replace(key, "__mag_offset___$n" => mag_offsets)
        end
        pippin_template[key] = value
    end
    return pippin_template
end

function fix_mag_offset(pippin_template::String, n::Int64, mag_offsets::String)
    return replace(pippin_template, "__mag_offset___$n" => mag_offsets)
end

function fix_mag_offset(pippin_template::Vector, n::Int64, mag_offsets::String)
    return [fix_mag_offset(template, n, mag_offsets) for template in pippin_template]
end

function fix_mag_offset(pippin_template, ::Int64, ::String)
    return pippin_template
end


function prep_template(pippin_template::OrderedDict{String,Any}, paths::Vector{String}, zp_offsets::Vector{String}, mag_offsets::Vector{String}, num_sims::Int64)
    paths = sort(paths)
    # Set up num_sims simulations and propegate that number throughout
    for key in keys(pippin_template)
        if contains(key, "__n__")
            for n in 1:num_sims
                value = deepcopy(pippin_template[key])
                new_value = fix_n(value, n)
                new_value = fix_saltmodel(new_value, n, paths[n])
                new_value = fix_zp_offset(new_value, n, zp_offsets[n])
                new_value = fix_mag_offset(new_value, n, mag_offsets[n])
                new_key = replace(key, "__n__" => "_$n")
                pippin_template[new_key] = new_value
            end
            delete!(pippin_template, key)
        else
            value = pippin_template[key]
            if typeof(value) <: OrderedDict
                prep_template(value, paths, zp_offsets, mag_offsets, num_sims)
            end
        end
    end
    return pippin_template
end

function save_pippin_template(pippin_template::OrderedDict{String,Any}, output::AbstractString)
    @info "Saving pippin template to $output"
    YAML.write_file(output, pippin_template)
end

function Simulator(config::Dict{String,Any}, covariance_matrix::CovarianceMatrix, jacobian::Jacobian, global_config::Dict{String,Any})
    pippin_template_input = config["PIPPIN_TEMPLATE"]
    if !isabspath(pippin_template_input)
        pippin_template_input = joinpath(global_config["BASE_PATH"], pippin_template_input)
    end
    num_sims = get(config, "NUM_SIMS", 0)
    draw_config = get(config, "DRAW", Dict{String,Any}())
    salt_models, zp_offsets, mag_offsets = get_offsets(covariance_matrix, jacobian, num_sims, draw_config, global_config)
    pippin_template = YAML.load_file(abspath(pippin_template_input); dicttype=OrderedDict{String,Any})
    pippin_template = prep_template(pippin_template, salt_models, zp_offsets, mag_offsets, num_sims)
    output = joinpath(global_config["OUTPUT_PATH"], basename(pippin_template_input))
    simulator = Simulator(pippin_template, output, covariance_matrix, jacobian)
    save_pippin_template(simulator.pippin_template, output)
    return simulator
end

function update_cosmology(pippin_template::OrderedDict{String,Any}, w::Float64=-1.0, om::Float64=0.3, ol::Float64=1 - om)
    for (key, value) in pippin_template
        pippin_template[key] = update_cosmology(value, w, om, ol)
    end
    return pippin_template
end

function update_cosmology(value::String, w::Float64, om::Float64, ol::Float64)
    if contains(value, "__w__")
        return w
    elseif contains(value, "__om__")
        return om
    elseif contains(value, "__ol__")
        return ol
    else
        return value
    end
end

function update_cosmology(value::Vector, w::Float64, om::Float64, ol::Float64)
    return update_cosmology.(value, w, om, ol)
end

function update_cosmology(value, ::Float64, ::Float64, ::Float64)
    return value
end

function simulate(simulator::Simulator, w::Float64=-1.0, om::Float64=0.3, ol::Float64=1 - om)
    pippin_template = update_cosmology(deepcopy(simulator.pippin_template), w, om, ol)
    save_pippin_template(pippin_template, simulator.pippin_output)
    command = Cmd(`pippin.sh -v $(simulator.pippin_output)`)
    run(command; wait=true)
end

end
