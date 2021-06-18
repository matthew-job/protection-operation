"""
    add_ct(data::Dict{String,Any}, element::String, id::String, n_p::Number, n_s::Number;kwargs...)

Function to add current transformer to circuit.
Inputs 4 if adding first CT, 5 otherwise:
    (1) data(Dictionary): Result from parse_file(). Circuit information
    (2) element(String): Element or line that CT is being added to
    (3) id(String): Optional. For multiple CT on the same line. If not used overwrites previously defined CT1
    (4) n_p(Number): Primary . Would be the number of  of the relay side of transformer
    (5) n_s(Number): Secondary . Number of  on line side
    (6) kwargs: Any other information user wants to add. Not used by anything.
"""
function add_ct(data::Dict{String,Any}, element::String, id::String, n_p::Number, n_s::Number;kwargs...)
    if !haskey(data, "protection")
        data["protection"] = Dict{String,Any}()
    end
    if haskey(data["line"],"$element")
        if !haskey(data["protection"],"C_Transformers")
            data["protection"]["C_Transformers"] = Dict{String,Any}()
        end
        if haskey(data["protection"]["C_Transformers"],"$id")
            @printf("%s has been redefined\n",id)
        end
        data["protection"]["C_Transformers"]["$id"] = Dict{String,Any}(
            "turns" => [n_p,n_s],
            "element" => element
        )
        kwargs_dict = Dict(kwargs)
        new_dict = Helper.add_dict(kwargs_dict)
        merge!(data["protection"]["C_Transformers"]["$id"],new_dict)
    else
        @printf("Circuit element %s does not exist.\n", element)
        @printf("No CT added.\n")
    end
end
"""
    non_ideal_ct(relay_data,CT_data,Iabc)

Converts primary side current to the actual current going through relay coil based on non-ideal parameters.
Unused.
"""
function non_ideal_ct(relay_data,CT_data,Iabc)
    Ze = CT_data["Ze"]
    R2 = CT_data["R2"]
    Zb = relay_data["Zb"]
    turns = CT_data["turns"]
    i_s = Iabc.*turns[2]./turns[1]
    i_r = i_s.*Ze./(Ze+Zb+R2)
    return i_r
end