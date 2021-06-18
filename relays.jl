"""
    add_relay(data::Dict{String,Any}, element::String, id::String, TS::Number, TDS::Number;
    phase::Vector=[1,2,3],t_breaker::Number=0, shots::Int64=1, kwargs...)

Function that adds an overcurrent relay with no CT to desired element on each desired phase.
To call: add_relay(ciruit_dictionary, "circuit_element", "name", TS(Amps),TDS;
        kwargs(format:t_c=1.0))

Inputs:
    Required(5)
        (1) data(Dictionary): A dictionary that comes from parse_file() function of .dss file.
        (2) element(String): Circuit element that relay is protecting/connected to. 
        (3) id(String): Relay id for multiple relays on same zone (primary, secondary, etc)
        (4) TS(Float): Tap setting of relay. (do not include CT)
        (5) TDS(Float): Time dial setting
    Optional
        (6) phase(Vector): Optional. Phases that relay is connected/protecting. Defaults to 3 phase:[1,2,3]
        (7) t_breaker(Number): Optional. Operation time of the breaker.
        (8) Shots(Int64): Optional. Number of operations before lockout.
        (9) kwargs: Any additional that user wants. Not used for anything else.

Outputs:
    Adds a relay to the data dictionary. Basically adds an element to the circuit that is defined in
    the .dss file.
"""
function add_relay(data::Dict{String,Any}, element::String, id::String, TS::Number, TDS::Number;
    phase::Vector=[1,2,3],t_breaker::Number=0, shots::Int64=1, kwargs...)
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
        if haskey(data["protection"]["relays"]["$element"],id)
            @printf("Relay %s-%s redefined.\n",element,id)
        end
        data["protection"]["relays"]["$element"]["$id"] = Dict{String,Any}(    
            "phase"=>Dict{String,Any}(), 
            "TS"=>TS, 
            "TDS"=>TDS, 
            "breaker_time"=>t_breaker,
            "type"=>"Overcurrent",
            "shots"=>shots 
        )
        for i = 1:length(phase)
            n_phase = phase[i]
            if n_phase in values(data["line"]["$element"]["f_connections"])
                data["protection"]["relays"]["$element"]["$id"]["phase"]["$n_phase"] = Dict{String,Any}(
                    "state"=>"closed", 
                    "op_times"=>"Does not operate"
                )
            else
                @printf("Phase %d on %s does not exist.\n",n_phase,element)
                @printf("No relay added.\n")  
            end
        end
        kwargs_dict = Dict(kwargs)
        new_dict = Helper.add_dict(kwargs_dict)
        merge!(data["protection"]["relays"]["$element"]["$id"],new_dict)
    else
        @printf("Circuit element %s does not exist.\n", element)
        @printf("No relay added.\n")
    end
end
"""
    add_relay(data::Dict{String,Any}, element::String, id::String, TS::Number, TDS::Number, CT::String;
    phase::Vector=[1,2,3], t_breaker::Number=0, shots::Int64=1, kwargs...)

Function that adds an overcurrent relay with a corresponding CT to desired element on each desired phase.
To call: add_relay(ciruit_dictionary, "circuit_element", "name", TS(Amps),TDS, "CT";
        kwargs(format:t_c=1.0))

Inputs:
    Required
        (1) data(Dictionary): A dictionary that comes from parse_file() function of .dss file.
        (2) element(String): Circuit element that relay is protecting/connected to. 
        (3) id(String): Relay id for multiple relays on same zone (primary, secondary, etc)
        (4) TS(Float): Tap setting of relay. Adjust for CT
        (5) TDS(Float): Time dial setting
        (6) CT(String): id of CT you want to use
    Optional
        (7) phase(Vector): Optional. Phases that relay is connected/protecting. Defaults to 3 phase:[1,2,3]
        (8) t_breaker(Number): Optional. Operation time of the breaker.
        (9) Shots(Int64): Optional. Number of operations before lockout.
        (10) kwargs: Any additional that user wants. Not used for anything else.

Outputs:
    Adds a relay to the data dictionary. Basically adds an element to the circuit that is defined in
    the .dss file.
"""
function add_relay(data::Dict{String,Any}, element::String, id::String, TS::Number, TDS::Number, CT::String;
    phase::Vector=[1,2,3], t_breaker::Number=0, shots::Int64=1, kwargs...)
    if !haskey(data["protection"], "relays")
        data["protection"]["relays"] = Dict{String,Any}()
    end
    if haskey(data["line"], "$element") && haskey(data["protection"],"C_Transformers")
        if haskey(data["protection"]["C_Transformers"],"$CT")
            if !haskey(data["protection"]["relays"],"$element")
                data["protection"]["relays"]["$element"] = Dict{String,Any}()
            end
            if haskey(data["protection"]["relays"]["$element"],id)
                @printf("Relay %s-%s redefined.\n",element,id)
            end
            data["protection"]["relays"]["$element"]["$id"] = Dict{String,Any}(    
                "phase"=>Dict{String,Any}(), 
                "TS"=>TS, 
                "TDS"=>TDS,
                "breaker_time"=>t_breaker,
                "type"=>"Overcurrent",
                "CT"=>CT,
                "shots"=>shots
            )
            for i = 1:length(phase)
                n_phase = phase[i]
                if n_phase in values(data["line"]["$element"]["f_connections"])
                    data["protection"]["relays"]["$element"]["$id"]["phase"]["$n_phase"] = Dict{String,Any}(
                        "state"=>"closed", 
                        "op_times"=>"Does not operate"
                    )
                else
                    @printf("Phase %d on %s does not exist.\n",n_phase,element)
                    @printf("No relay added.\n")  
                end
            end
            kwargs_dict = Dict(kwargs)
            new_dict = Helper.add_dict(kwargs_dict)
            merge!(data["protection"]["relays"]["$element"]["$id"],new_dict)
        else
            @printf("CT %s does not exist.\n", CT)
            @printf("No relay added.\n") 
        end
    elseif haskey(data["protection"],"C_Transformers")
        @printf("Circuit element %s does not exist.\n", element)
        @printf("No relay added.\n")
    else
        @printf("There are no CTs in the circuit.\n")
        @printf("No relay added.\n")
    end
end
"""
    add_relay(data::Dict{String,Any}, element::String, id::String, TS::Number, TDS::Number, CTs::Vector{String};
    phase::Vector=[1,2,3], t_breaker::Number=0, kwargs...)

Function that adds a differential relay to a bus or line. Assumes that the secondary turns of the CTs is the rated current for the corresponding
branch in the relay. Uses tap setting and the total rated currents to calculate the slope of the restraint curve. "restraint" key is the slope.
Note: relays on the lines will never trip because no faults can be on a line.
Inputs:
    Required
        (1) data(Dictionary): A dictionary that comes from parse_file() function of .dss file.
        (2) element(String): Circuit element that relay is protecting/connected to. 
        (3) id(String): Relay id for multiple relays on same zone (primary, secondary, etc)
        (4) TS(Float): Tap setting of relay. Is the minimum difference current for trip.
        (5) TDS(Float): Time dial setting
        (6) CT1(Vector): Vector of CTs that are used. For lines there should only be one, but for busses you need one for each line
                            in and out of the bus. Function will make sure you have enough.
    Optional
        (7) phase(Vector): Optional. Phases that relay is connected/protecting. Defaults to 3 phase:[1,2,3]
        (8) t_breaker(Number): Optional. Operation time of the breaker.
        (9) kwargs: Any additional that user wants. Not used for anything else.

Outputs:
    Adds a differential relay to the data dictionary. Basically adds an element to the circuit that is defined in
    the .dss file.
"""
function add_relay(data::Dict{String,Any}, element::String, id::String, TS::Number, TDS::Number, CTs::Vector{String};
    phase::Vector=[1,2,3], t_breaker::Number=0, kwargs...)
    if !haskey(data,"protection")
        data["protection"] = Dict{String,Any}()
    end
    if !haskey(data["protection"], "relays")
        data["protection"]["relays"] = Dict{String,Any}()
    end
    if haskey(data["bus"], "$element")
        if Helper.check_keys(data, CTs)
            if !haskey(data["protection"]["relays"],"$element")
                data["protection"]["relays"]["$element"] = Dict{String,Any}()
            end
            if haskey(data["protection"]["relays"]["$element"],id)
                @printf("Relay %s-%s redefined.\n",element, id)
            end
            Ir = Helper.restraint(data,CTs,TS)
            data["protection"]["relays"]["$element"]["$id"] = Dict{String,Any}(    
                "phase"=>Dict{String,Any}(), 
                "TS"=>TS, 
                "TDS"=>TDS, 
                "breaker_time"=>t_breaker,
                "type"=>"Differential",
                "CTs"=>CTs,
                "restraint"=>Ir,
                "shots"=>1
                
            )
            for i = 1:length(phase)
                n_phase = phase[i]
                if n_phase in values(data["bus"]["$element"]["terminals"])
                    data["protection"]["relays"]["$element"]["$id"]["phase"]["$n_phase"] = Dict{String,Any}(
                        "state"=>"closed", 
                        "op_times"=>"Does not operate"
                    )
                else
                    @printf("Phase %d on %s does not exist.\n",n_phase,element)
                    @printf("No relay added.\n")  
                end
            end
            kwargs_dict = Dict(kwargs)
            new_dict = Helper.add_dict(kwargs_dict)
            merge!(data["protection"]["relays"]["$element"]["$id"],new_dict)
        else
            @printf("Not all CTs provided exist.\n")
            @printf("No relay added.\n") 
        end
    elseif haskey(data["line"],element)
        if Helper.check_keys(data, CTs)
            if !haskey(data["protection"]["relays"],"$element")
                data["protection"]["relays"]["$element"] = Dict{String,Any}()
            end
            if haskey(data["protection"]["relays"]["$element"],id)
                @printf("Relay %s-%s redefined.\n",element, id)
            end
            Ir = Helper.restraint(data,CTs,TS)
            data["protection"]["relays"]["$element"]["$id"] = Dict{String,Any}(    
                "phase"=>Dict{String,Any}(), 
                "TS"=>TS, 
                "TDS"=>TDS,
                "breaker_time"=>t_breaker,
                "type"=>"Differential",
                "CTs"=>CTs,
                "restraint"=>Ir,
                "shots"=>1
            )
            for i = 1:length(phase)
                n_phase = phase[i]
                if n_phase in values(data["line"]["$element"]["f_connections"])
                    data["protection"]["relays"]["$element"]["$id"]["phase"]["$n_phase"] = Dict{String,Any}(
                        "state"=>"closed", 
                        "op_times"=>"Does not operate"
                    )
                else
                    @printf("Phase %d on %s does not exist.\n",n_phase,element)
                    @printf("No relay added.\n")  
                end
            end
            kwargs_dict = Dict(kwargs)
            new_dict = Helper.add_dict(kwargs_dict)
            merge!(data["protection"]["relays"]["$element"]["$id"],new_dict)
        else
            @printf("Not all CTs provided exist.\n")
            @printf("No relay added.\n") 
        end
    else
        @printf("Circuit element %s does not exist.\n", element)
        @printf("No relay added.\n")
    end
end
"""
    add_relay(data::Dict{String,Any}, element1::String, element2::String, id::String, trip_angle::Number;
    kwargs...)

Function that adds a directional differential relay to circuit. In order to use properly circuit file must be edited so that the line
we are concerned with is divided in two with a bus in between. Fault can then be added to that bus. Will use phase angles of current and 
voltage at either side to determine if direction of power is same on both ends. Element1 is from, element2 is to.
Inputs:
    Required
        (1) data(Dictionary): A dictionary that comes from parse_file() function of .dss file.
        (2) element1(String): First circuit element relay is protecting.
        (3) element2(String): Second circuit element relay is protecting. For relay to work properly elements should each be a protection
                                of the same line with bus in between them where the fault will be simulated.   
        (4) id(String): Relay id.
        (5) trip_angle: Angle at which relay will trip if the difference in phase angles is greater.
        
    Optional
        (6) kwargs: Any additional that user wants. Not used for anything else.

Outputs:
    Adds a differential relay to the data dictionary. Basically adds an element to the circuit that is defined in
    the .dss file.
"""
function add_relay(data::Dict{String,Any}, element1::String, element2::String, id::String, trip_angle::Number;
    kwargs...)
    if !haskey(data,"protection")
        data["protection"] = Dict{String,Any}()
    end
    if !haskey(data["protection"], "relays")
        data["protection"]["relays"] = Dict{String,Any}()
    end
    if haskey(data["line"], "$element1") && haskey(data["line"], "$element2")
        if !haskey(data["protection"]["relays"],"$element1")
            data["protection"]["relays"]["$element1"] = Dict{String,Any}()
        end
        if haskey(data["protection"]["relays"]["$element1"],id)
            @printf("Relay %s-%s redefined.\n",element1,id)
        end
        data["protection"]["relays"]["$element1"]["$id"] = Dict{String,Any}(    
            "element2"=>element2, 
            "type"=>"Differential_Dir",
            "trip"=>trip_angle,
            "state"=>"closed",
            "shots"=>1
        )
        kwargs_dict = Dict(kwargs)
        new_dict = Helper.add_dict(kwargs_dict)
        merge!(data["protection"]["relays"]["$element1"]["$id"],new_dict)
    else
        @printf("Circuit element %s or %s does not exist.\n", element1,element2)
        @printf("No relay added.\n")
    end
end
function add_relay(data::Dict{String,Any}, element1::String, element2::String, id::String, TS::Number, TDS::Number, CTs::Vector;
    phase::Vector=[1,2,3], t_breaker::Number=0, kwargs...)
    if !haskey(data,"protection")
        data["protection"] = Dict{String,Any}()
    end
    if !haskey(data["protection"], "relays")
        data["protection"]["relays"] = Dict{String,Any}()
    end
    if haskey(data["line"],element1) && haskey(data["line"],element2)
        if Helper.check_keys(data, CTs)
            if !haskey(data["protection"]["relays"],"$element1")
                data["protection"]["relays"]["$element1"] = Dict{String,Any}()
            end
            if haskey(data["protection"]["relays"]["$element1"],id)
                @printf("Relay %s-%s redefined.\n",element, id)
            end
            Ir = Helper.restraint(data,CTs,TS)
            data["protection"]["relays"]["$element1"]["$id"] = Dict{String,Any}(  
                "element2"=>element2,  
                "phase"=>Dict{String,Any}(), 
                "TS"=>TS, 
                "TDS"=>TDS,
                "breaker_time"=>t_breaker,
                "type"=>"Differential",
                "CTs"=>CTs,
                "restraint"=>Ir,
                "shots"=>1
            )
            for i = 1:length(phase)
                n_phase = phase[i]
                if n_phase in values(data["line"]["$element1"]["f_connections"])
                    data["protection"]["relays"]["$element1"]["$id"]["phase"]["$n_phase"] = Dict{String,Any}(
                        "state"=>"closed", 
                        "op_times"=>"Does not operate"
                    )
                else
                    @printf("Phase %d on %s does not exist.\n",n_phase,element1)
                    @printf("No relay added.\n")  
                end
            end
            kwargs_dict = Dict(kwargs)
            new_dict = Helper.add_dict(kwargs_dict)
            merge!(data["protection"]["relays"]["$element1"]["$id"],new_dict)
        else
            @printf("Not all CTs provided exist.\n")
            @printf("No relay added.\n") 
        end
    else
        @printf("Circuit element(s) %s or %s does not exist.\n", element1,element2)
        @printf("No relay added.\n")
    end
end