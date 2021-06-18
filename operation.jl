"""
    relay_operation(relay_data::Dict{String,Any},Iabc::Vector)

Function to check the operation of a relay. Takes dictionary corresponding to the relay being evaluated
as well as the vector of currents or angles through the protected element. If that current is larger than the 
tap setting, restraint for differential relays, or trip angle for directional differential relays, it calculates 
relay operating time using constants and equation from optimal protection coordination. Calculates a vector of 
times if relay has multiple shots. Assumes relay closes 0.5, 2, and 10 seconds after opening. Sets limit of "shots" to 4.
Inputs:
    (1) relay_data(Dictionary): Dictionary containing information about the relay that we are interested in.
    (2) Iabc(Vector): Currents through each phase of the protected element

Outputs:
    Assigns the calculated operating time(s) to the "op_times" key in the relay dictionary. If the relay
    trips, it changes "state" key to "open".
"""    
function relay_operation(relay_data::Dict{String,Any},Iabc::Vector)
    if relay_data["type"] == "Differential_Dir"
        I_neg = Iabc[3]
        trip = relay_data["trip"]
        if I_neg > trip
            relay_data["state"] = "open"
        end
    elseif relay_data["type"] == "Differential"
        Ir = relay_data["restraint"]
        for phase = 1:length(relay_data["phase"])
            if Iabc[phase] > Ir
                I = Iabc[phase]
                op_times = Helper.differential_time(relay_data,I)
                relay_data["phase"]["$phase"]["state"] = "open"
                relay_data["phase"]["$phase"]["op_times"] = op_times
            else
                relay_data["phase"]["$phase"]["state"] = "closed"
            end
        end
    else
        if (relay_data["shots"] == 1)
            for phase = 1:length(relay_data["phase"])
                if Iabc[phase] > relay_data["TS"]
                    I = Iabc[phase]
                    op_times = Helper.short_time(relay_data,I)
                    relay_data["phase"]["$phase"]["state"] = "open"
                    relay_data["phase"]["$phase"]["op_times"] = op_times
                else
                    relay_data["phase"]["$phase"]["state"] = "closed"
                end
            end
        elseif relay_data["shots"] == 2
            op_times = zeros(length(relay_data["phase"]),2)
            for phase = 1:length(relay_data["phase"])
                if Iabc[phase] > relay_data["TS"]
                    I = Iabc[phase]
                    op_times[phase,1] = Helper.short_time(relay_data,I)
                    op_times[phase,2] = Helper.long_time(relay_data,I) + op_times[phase,1] + 0.5
                    relay_data["phase"]["$phase"]["op_times"] = op_times[phase,:]
                    relay_data["phase"]["$phase"]["state"] = "open"
                else
                    relay_data["phase"]["$phase"]["state"] = "closed"
                end
            end
        elseif relay_data["shots"] == 3
            op_times = zeros(length(relay_data["phase"]),3)
            for phase = 1:length(relay_data["phase"])
                if Iabc[phase] > relay_data["TS"]
                    I = Iabc[phase]
                    op_times[phase,1] = Helper.short_time(relay_data,I)
                    op_times[phase,2] = Helper.short_time(relay_data,I) + op_times[phase,1] + 0.5
                    op_times[phase,3] = Helper.long_time(relay_data,I) + op_times[phase,2] + 2.5
                    relay_data["phase"]["$phase"]["op_times"] = op_times[phase,:]
                    relay_data["phase"]["$phase"]["state"] = "open"
                else
                    relay_data["phase"]["$phase"]["state"] = "closed"
                end
            end
        elseif relay_data["shots"] >= 4
            op_times = zeros(length(relay_data["phase"]),4)
            for phase = 1:length(relay_data["phase"])
                if Iabc[phase] > relay_data["TS"]
                    I = Iabc[phase]
                    op_times[phase,1] = Helper.short_time(relay_data,I)
                    op_times[phase,2] = Helper.short_time(relay_data,I) + op_times[phase,1] + 0.5
                    op_times[phase,3] = Helper.long_time(relay_data,I) + op_times[phase,2] + 2.5
                    op_times[phase,4] = Helper.long_time(relay_data,I) + op_times[phase,3] + 12.5
                    relay_data["phase"]["$phase"]["op_times"] = op_times[phase,:]
                    relay_data["phase"]["$phase"]["state"] = "open"
                else
                    relay_data["phase"]["$phase"]["state"] = "closed"
                end
            end    
        end
    end
end
"""
    relay_operation_all(data::Dict{String,Any},results::{String,Any})

Function to check all relays in circuit. Uses dictionary from parse_file(dssFile.dss) and 
dictionary from PowerModelsProtection.solve_mc_fault_study() to check operation of all 
relays in circuit. 
Inputs: 
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
                relay_data = data["protection"]["relays"]["$element"]["$id"]
                Iabc = Helper.get_current(data,results,element,id)
                relay_operation(relay_data,Iabc)
            end
        end
    else
        @printf("Circuit has no relays.\n")
    end
end
"""
    relay_report(data::Dict{String,Any})

Prints out which relays tripped and their operating times
Inputs:
    (1) data(Dictionary): Dictionary of circuit information. 
                        Ex) data = PowerModelsProtection.parse_file(filename.dss)
"""
function relay_report(data::Dict{String,Any})
    element_vec = collect(keys(data["protection"]["relays"]))
    for i = 1:length(element_vec)
        element = element_vec[i]
        id_vec = collect(keys(data["protection"]["relays"]["$element"]))
        for j = 1:length(id_vec)
            id = id_vec[j]
            if data["protection"]["relays"]["$element"]["$id"]["type"] == "Differential_Dir"
                if data["protection"]["relays"]["$element"]["$id"]["state"] == "open"
                    @printf("Directional Differential relay %s-%s tripped.\n",element,id)
                end
            else
                phase_vec = collect(keys(data["protection"]["relays"]["$element"]["$id"]["phase"]))
                for k = 1:length(phase_vec)
                    phase = phase_vec[k]
                    if data["protection"]["relays"]["$element"]["$id"]["phase"]["$phase"]["state"] == "open"
                        if !(data["protection"]["relays"]["$element"]["$id"]["shots"] == 1)
                            time = data["protection"]["relays"]["$element"]["$id"]["phase"]["$phase"]["op_times"]
                            @printf("Relay %s-%s phase %s tripped ",element,id,phase)
                            if data["protection"]["relays"]["$element"]["$id"]["shots"] >=4
                                N = 4
                            else
                                N = data["protection"]["relays"]["$element"]["$id"]["shots"]
                            end
                            for i = 1:N
                                if i < N
                                    @printf("%0.2f, ",time[i])
                                else
                                    @printf("and %0.2f seconds after fault occured.\n",time[i])
                                end
                            end
                        else
                        time = data["protection"]["relays"]["$element"]["$id"]["phase"]["$phase"]["op_times"]
                        @printf("Relay %s-%s phase %s tripped %0.2f seconds after fault occured.\n",element,id,phase,time)
                        end
                    end
                end
            end
        end
    end
end