using Base: Int64
"""
    add_ct(data::Dict{String,Any}, n_p::Number, n_s::Number, element::String, id::String="CT1")

Function to add current transformer to circuit.
"""
function add_ct(data::Dict{String,Any}, n_p::Number, n_s::Number, element::String, id::String="CT1")
    if !haskey(data, "protection")
        data["protection"] = Dict{String,Any}()

    end
    if haskey(data["line"],"$element")
        if !haskey(data["protection"],"C_Transformers")
            data["protection"]["C_Transformers"] = Dict{String,Any}()
        end
        if !haskey(data["protection"]["C_Transformers"],"$element")
            data["protection"]["C_Transformers"]["$element"] = Dict{String,Any}()
        end
        data["protection"]["C_Transformers"]["$element"]["$id"] = [n_p,n_s]
    else
        @printf("Circuit element %s does not exist.\n", element)
        @printf("No CT added.\n")
    end
end

"""
    add_relay(data::Dict{String,Any}, element::String, id::String, TS::Number, TDS::Number;phase::Vector=[1,2,3],t_c::Number=0.0, type::String="Overcurrent", t_breaker::Number=0)

Function that adds a relay to desired element on each desired phase.
To call: add_relay(ciruit_dictionary, "circuit_element", "name", TS(Amps),TDS;
        kwargs(format:t_c=1.0))

Inputs 5 required, 4 optional: 
    (1) data(Dictionary): A dictionary that comes from parse_file() function of .dss file.
    (2) element(String): Circuit element that relay is protecting/connected to. 
    (3) id(String): Relay id for multiple relays on same zone (primary, secondary, etc)
    (4) phase(Vector): Phases that relay is connected/protecting.
    (5) TS(Float): Tap setting of relay. (do not include CT)
    (6) TDS(Float): Time dial setting
    (7) t_c(Float): Coordination time. Realy doesn't do anything at this point except delay operation.
    (8) type(String): Optional. Type of relay. Doesn't do anything. Default is overcurrent.

Outputs:
    Adds a relay to the data dictionary. Basically adds an element to the circuit that is defined in
    the .dss file.
"""
function add_relay(data::Dict{String,Any}, element::String, id::String, TS::Number, TDS::Number;phase::Vector=[1,2,3],
    t_c::Number=0.0, type::String="Overcurrent", t_breaker::Number=0)
    if !haskey(data, "protection")
        data["protection"] = Dict{String,Any}()
        data["protection"]["relays"] = Dict{String,Any}()
    end
    if haskey(data["line"], "$element")
        if !haskey(data["protection"],"relays")
            data["protection"]["relays"] = Dict{String,Any}()
        end
        if !haskey(data["protection"]["relays"],"$element")
            data["protection"]["relays"]["$element"] = Dict{String,Any}()
        end
        data["protection"]["relays"]["$element"]["$id"] = Dict{String,Any}(    
            "phase"=>Dict{String,Any}(), 
            "TS"=>TS, 
            "TDS"=>TDS, 
            "coordination"=>t_c, 
            "breaker_time"=>t_breaker,
            "type"=>type, 
        )
        for i = 1:length(phase)
            n_phase = phase[i]
            if n_phase in values(data["line"]["$element"]["f_connections"])
                data["protection"]["relays"]["$element"]["$id"]["phase"]["$n_phase"] = Dict{String,Any}(
                    "state"=>"closed", 
                    "op_time"=>"Does not operate"
                )
            else
                @printf("Relay %s-%s phase %d does not exist.\n",element,id,n_phase)
                @printf("No relay added.\n")  
            end
        end
    else
        @printf("Circuit element %s does not exist.\n", element)
        @printf("No relay added.\n")
    end
end
function add_relay(data::Dict{String,Any}, element::String, id::String, TS::Number, TDS::Number, CT::String;phase::Vector=[1,2,3],
    t_c::Number=0.0, type::String="Overcurrent", t_breaker::Number=0)
    if !haskey(data, "protection")
        data["protection"] = Dict{String,Any}()
        data["protection"]["relays"] = Dict{String,Any}()
    end
    if haskey(data["line"], "$element")
        if haskey(data["protection"]["C_Transformers"],"$element") && haskey(data["protection"]["C_Transformers"]["$element"],"$CT")
            if !haskey(data["protection"]["relays"],"$element")
                data["protection"]["relays"]["$element"] = Dict{String,Any}()
            end
            data["protection"]["relays"]["$element"]["$id"] = Dict{String,Any}(    
                "phase"=>Dict{String,Any}(), 
                "TS"=>TS, 
                "TDS"=>TDS, 
                "coordination"=>t_c, 
                "breaker_time"=>t_breaker,
                "type"=>type,
                "CT"=>CT 
            )
            for i = 1:length(phase)
                n_phase = phase[i]
                if n_phase in values(data["line"]["$element"]["f_connections"])
                    data["protection"]["relays"]["$element"]["$id"]["phase"]["$n_phase"] = Dict{String,Any}(
                        "state"=>"closed", 
                        "op_time"=>"Does not operate"
                    )
                else
                    @printf("Relay %s-%s phase %d does not exist.\n",element,id,n_phase)
                    @printf("No relay added.\n")  
                end
            end
        else
            @printf("CT %s does not exist.\n", CT)
            @printf("No relay added.\n") 
        end
    else
        @printf("Circuit element %s does not exist.\n", element)
        @printf("No relay added.\n")
    end
end
"""
    get_current(relay_data::Dict{String,Any},results::Dict{String,Any})

Function to get current that is flowing through the relay we are looking at.

Takes information from relay dictionary (mainly connection and phase) and passes them in
the dictionary that comes from PowerModelsProtection.solve_mc_fault_study(). Returns a 
vector of the fault current for that circuit element
"""
function get_current(relay_data::Dict{String,Any},results::Dict{String,Any},element)
    return results["solution"]["line"]["$element"]["fault_current"]
end
"""
    relay_operation(relay_data::Dict{String,Any},results::Dict{String,Any})

Function to check the operation of a relay.Takes relay dictionary and dictionary from PowerModelsProtection.solve_mc_fault_study(). 
Then gets the relavent current. Then if that current is larger than the 
tap setting, it calculates relay operating time using constants and equation from optimal 
protection coordination.

Inputs{2}:
    (1) relay_data(Dictionary): Dictionary containing information about the relay that we are interested in.
    (2) results(Dictionary): Solution data that has the fault currents.

Outputs:
    Assigns the calculated operating time to the "op_time" key in the relay dictionary. If the relay
    trips, it changes "state" key to "open".
"""    
function relay_operation(relay_data::Dict{String,Any},Iabc::Vector,turns::Vector=[1,1])
    #Relay constants
    A = 0.14
    B = 0.02
    for phase = 1:length(relay_data["phase"])
        if Iabc[phase] > relay_data["TS"]
            t::Float64 = relay_data["TDS"]*A/(((Iabc[phase]*turns[2]/turns[1])/relay_data["TS"])^B-1)
            op_time = t + relay_data["coordination"] + relay_data["breaker_time"]
            relay_data["phase"]["$phase"]["state"] = "open"
            relay_data["phase"]["$phase"]["op_time"] = op_time
        else
            relay_data["phase"]["$phase"]["state"] = "closed"
        end
    end
end
"""
    relay_operation_all(data::Dict{String,Any},results::{String,Any})

Function to check all relays in circuit. Uses dictionary from parse_file(dssFile.dss) and 
dictionary from PowerModelsProtection.solve_mc_fault_study() to checks operation of all 
relays in circuit.

Inputs{2}: 
    (1) data(Dictionary): From PowerModelsProtection.parse_file(file.dss)
    (2) results(Dictionary): From PowerModelsPRotection.solve_mc_fault_study(data, solver)
"""
function relay_operation_all(data::Dict{String,Any},results::Dict{String,Any})
    if haskey(data["protection"], "relays") #check that there are relays to "check"
        element_vec = collect(keys(data["protection"]["relays"]))
        for i = 1:length(element_vec)
            element = element_vec[i]
            id_vec = collect(keys(data["protection"]["relays"]["$element"]))
            for j = 1:length(id_vec)
                id = id_vec[j]
                if haskey(data["protection"]["relays"]["$element"]["$id"],"CT")
                    CT = data["protection"]["relays"]["$element"]["$id"]["CT"]
                    turns = data["protection"]["C_Transformers"]["$element"]["$CT"]
                else
                    turns = [1,1]
                end
                relay_data = data["protection"]["relays"]["$element"]["$id"]
                Iabc = get_current(data["protection"]["relays"]["$element"],results,element)
                relay_operation(relay_data,Iabc,turns)
            end
        end
    else
        @printf("Circuit has no relays.\n")
    end
end
"""
    relay_report(data::Dict{String,Any})

Prints out which relays tripped and their operating times

Inputs{1}:
    (1) data(Dictionary): Dictionary of circuit information. 
                        Ex) data = PowerModelsProtection.parse_file(filename.dss)
"""
function relay_report(data::Dict{String,Any})
    relay_vec = collect(keys(data["protection"]["relays"]))
    for i = 1:length(relay_vec)
        element = relay_vec[i]
        id_vec = collect(keys(data["protection"]["relays"]["$element"]))
        for j = 1:length(id_vec)
            id = id_vec[j]
            phase_vec = collect(keys(data["protection"]["relays"]["$element"]["$id"]["phase"]))
            for k = 1:length(phase_vec)
                phase = phase_vec[k]
                if data["protection"]["relays"]["$element"]["$id"]["phase"]["$phase"]["state"] == "open"
                    time = data["protection"]["relays"]["$element"]["$id"]["phase"]["$phase"]["op_time"]
                    @printf("Relay %s-%s phase %s tripped after %0.2f seconds.\n",element,id,phase,time)
                end
            end
        end
    end
end