module Helper
"""
    add_dict(d::Dict)

Function to help add keyword arguments to the circuit information dictionary.
"""
function add_dict(d::Dict)
    k = collect(keys(d))
    v = collect(values(d))
    new_dict = Dict{String,Any}()
    for i = 1:length(k)
        key = k[i]
        new_dict["$key"] = v[i]
    end
    return new_dict
end
"""
    get_current(data::Dict{String,Any},results::Dict{String,Any},element,id)

Function to get current that is flowing through the relay we are looking at. Gets the type of relay from dictionary then calls 
corresponding function for that type.
Inputs:
    (1) data(Dictionary):   Circuit informtion dictionay.
    (2) results(Dictionary):   Fault study information that comes from PowerModelsProtection.solve_mc_fault_study()
    (3) element(String):    Circuit element relay is protecting
    (4) id(String):    Relay name.

Outputs:
    Vector of currents that are relevant to relay "id". For directional differential returns vector of angles.
"""
function get_current(data::Dict{String,Any},results::Dict{String,Any},element,id)
    type = data["protection"]["relays"]["$element"]["$id"]["type"]
    return getfield(Helper,Symbol("_$(type)_current"))(data, results, element, id)
end
"""
    _Differential_current(data::Dict{String,Any},results::Dict{String,Any},element,id)

Function that gets the differential current. If on bus it sums all current in and out. Sign convention is current leaving is negative.
if on line it gives the difference between from current and to current.
"""
function _Differential_current(data::Dict{String,Any},results::Dict{String,Any},element,id)
    ct_vec = data["protection"]["relays"]["$element"]["$id"]["CTs"]
    ct_data = data["protection"]["C_Transformers"]
    if haskey(data["bus"],element)    
        num_ct = length(ct_vec)
        I_s = zeros(3,num_ct)
        I_sr = zeros(3,num_ct)
        for k = 1:num_ct
            ct_id = ct_vec[k]
            turns = ct_data["$ct_id"]["turns"]
            line = ct_data["$ct_id"]["element"]
            if data["line"]["$line"]["f_bus"] == "$element"
                I_pr = results["solution"]["line"]["$line"]["cr_fr"]
                I_pi = results["solution"]["line"]["$line"]["ci_fr"]
               # I_p = I_pr.^2+I_pi.^2
                I_p = broadcast(abs,(I_pr+im.*I_pi))
                I_r = I_p
                I_p = I_p.*(-1)
            else
                I_pr = results["solution"]["line"]["$line"]["cr_to"]
                I_pi = results["solution"]["line"]["$line"]["ci_to"]
                #I_p = I_pr.^2+I_pi.^2
                I_p = broadcast(abs,(I_pr+im.*I_pi))
                I_r = I_p
            end
            I_s[:,k] = I_p.*turns[2]./turns[1]
            I_sr[:,k] = I_r.*turns[2]./turns[1]
        end
        I_op = sum(I_s,dims=2)
        I_opr = 2 ./sum(I_sr,dims=2)
        I_op = I_op .* I_opr
        return vec(I_op)
    elseif !haskey(data["protection"]["relays"]["$element"]["$id"],"element2")
        I_pr = results["solution"]["line"]["$element"]["cr_fr"]
        I_pi = results["solution"]["line"]["$element"]["ci_fr"]
        I_p1 = broadcast(abs,(I_pr+im.*I_pi))
        I_pr = results["solution"]["line"]["$element"]["cr_to"]
        I_pi = results["solution"]["line"]["$element"]["ci_to"]
        I_p2 = broadcast(abs,(I_pr+im.*I_pi))
        turns = ct_data["$(ct_vec[1])"]["turns"]
        I_op = (I_p1-I_p2) .*turns[2] ./turns[1]
        I_opr = 2 ./ ((I_p1+I_p2) .*turns[2] ./turns[1])
        return I_op
    else
        #get second element. get from current. get to current. compare.
        element2 = data["protection"]["relays"]["$element"]["$id"]["element2"]
        Ipr_fr = results["solution"]["line"]["$element"]["cr_fr"]
        Ipi_fr = results["solution"]["line"]["$element"]["ci_fr"]
        Ip_fr = broadcast(abs,(Ipr_fr+im.*Ipi_fr))
        Ipr_to = results["solution"]["line"]["$element2"]["cr_to"]
        Ipi_to = results["solution"]["line"]["$element2"]["ci_to"]
        Ip_to = broadcast(abs,(Ipr_to+im.*Ipi_to))
        turns = zeros(2,2)
        turns[:,1] = ct_data["$(ct_vec[1])"]["turns"]
        turns[:,2] = ct_data["$(ct_vec[2])"]["turns"]
        I_op = Ip_fr.*turns[1,2]./turns[1,1] - Ip_to.*turns[2,2]./turns[2,1]
        I_opr = 2 ./ (Ip_fr.*turns[1,2]./turns[1,1] + Ip_to.*turns[2,2]./turns[2,1])
        return I_op.*I_opr
    end
end
"""
    _Differential_Dir_current(data::Dict{String,Any},results::Dict{String,Any},element,id)

Function to get the "direction" of power flow. Gets the voltage and current on/through the from bus and to bus. Converts them to sequence
components. Gets direction by taking difference of current angle and corresponding voltage angle. That angle is the direction and if you
take the difference of the two direction angle you can determine if they match. Returns a vector of sequence angles that are that difference.
"""
function _Differential_Dir_current(data::Dict{String,Any},results::Dict{String,Any},element,id)
    element1 = element
    element2 = data["protection"]["relays"]["$element"]["$id"]["element2"]
    bus1 = data["line"]["$element1"]["f_bus"]
    bus2 = data["line"]["$element2"]["t_bus"]
    Vp1 = results["solution"]["bus"]["$bus1"]["vr"]+ im*results["solution"]["bus"]["$bus1"]["vi"]
    Vp2 = results["solution"]["bus"]["$bus2"]["vr"]+ im*results["solution"]["bus"]["$bus2"]["vi"]
    Ip1 = results["solution"]["line"]["$element1"]["csr_fr"] + im*results["solution"]["line"]["$element1"]["csi_fr"]
    Ip2 = results["solution"]["line"]["$element2"]["csr_fr"] + im*results["solution"]["line"]["$element2"]["csi_fr"] 
    Vs1 = broadcast(angle,p_to_s(Vp1)) .*180 ./pi  
    Vs2 = broadcast(angle,p_to_s(Vp2)) .*180 ./pi 
    Is1 = broadcast(angle,p_to_s(Ip1)) .*180 ./pi 
    Is2 = broadcast(angle,p_to_s(Ip2)) .*180 ./pi  
    I_diff = (Is1-Vs1) - (Is2-Vs2)
    return broadcast(abs,I_diff) 
end
"""
    _Overcurrent_current(data::Dict{String,Any},results::Dict{String,Any},element,id)

Function that gets current on the line and steps down if CT is used.
"""
function _Overcurrent_current(data::Dict{String,Any},results::Dict{String,Any},element,id)
    relay_data = data["protection"]["relays"]["$element"]["$id"]
    if haskey(relay_data,"CT")
        ct = relay_data["CT"]
        turns = data["protection"]["C_Transformers"]["$ct"]["turns"]
        I_p = results["solution"]["line"]["$element"]["fault_current"]
        I_s = I_p.*turns[2]./turns[1]
        return I_s
    else
        return results["solution"]["line"]["$element"]["fault_current"]
    end
end
"""
    short_time(relay_data::Dict{String,Any},I::Number)

Function that calculates the short-inverse time of a relay for fast trips.
"""
function short_time(relay_data::Dict{String,Any},I::Number)
    A = 0.14
    B = 0.02
    t::Float64 = relay_data["TDS"]*A/((I/relay_data["TS"])^B-1)
    op_times = t + relay_data["breaker_time"]
    return op_times
end
"""
    long_time(relay_data::Dict{String,Any},I::Number)

Function that calculated the long-inverse time of a relay for delayed trips.
"""
function long_time(relay_data::Dict{String,Any},I::Number)
    A = 120
    B = 2
    t::Float64 = relay_data["TDS"]*A/((I/relay_data["TS"])^B-1)
    op_times = t + relay_data["breaker_time"]
    return op_times
end
"""
    differential_time(relay_data::Dict{String,Any},I::Number)

Function that calculates short-invers operation time of relay. Uses restraint instead of tap setting.
"""
function differential_time(relay_data::Dict{String,Any},I::Number)
    A = 0.14
    B = 0.02
    t::Float64 = relay_data["TDS"]*A/((I/relay_data["restraint"])^B-1)
    op_times = t + relay_data["breaker_time"]
    return op_times
end
"""
    check_keys(data::Dict{String,Any},id::Vector{String})

Function to apply haskey function to all elements in a vector. Used for checking if all cts are in the 
circuit when adding a differential relay. Only works for CTs but will be made more dynamic if there is need.
"""
function check_keys(data::Dict{String,Any},id::Vector{String})
    function _haskey_ct(id::String)
        return haskey(data["protection"]["C_Transformers"],"$id")
    end
    bool_vec = zeros(Bool,length(id),1)
    broadcast!(_haskey_ct,bool_vec,id)
    return sum(bool_vec) == length(id)
end
"""
    p_to_s(p_vec::Vector)

Function to convert phase values to sequence values. Takes vector of 3 phases, returns vector of 3 sequences.
"""
function p_to_s(p_vec::Vector)
    a = -0.5 + im*sqrt(3)/2
    A = [1 1 1;1 a^2 a; 1 a a^2]
    s_vec = A*p_vec
    return s_vec
end
"""
Just a function used for prototyping.
"""
function _get_current(results,element)
    Ifrr = results["solution"]["line"]["$element"]["cr_fr"]
    Ifri = results["solution"]["line"]["$element"]["ci_fr"]
    Itor = results["solution"]["line"]["$element"]["cr_to"]
    Itoi = results["solution"]["line"]["$element"]["ci_to"]
    Isr = results["solution"]["line"]["$element"]["csr_fr"]
    Isi = results["solution"]["line"]["$element"]["csi_fr"]

    Isp = Isr+im.*Isi
    Itop = Itor+im.*Itoi
    Ifrp = Ifrr+im.*Ifri

    Iss = p_to_s(Isp)
    Itos = p_to_s(Itop)
    Ifrs = p_to_s(Ifrp)

    aIss = broadcast(angle,Iss).*180 ./pi
    aItos = broadcast(angle,Itos).*180 ./pi
    aIfrs = broadcast(angle,Ifrs).*180 ./pi
    amat = zeros(3,3)
    amat[:,1] = aIss
    amat[:,2] = aIfrs
    amat[:,3] = aItos

    Iss = broadcast(abs, Iss)
    Itos = broadcast(abs, Itos)
    Ifrs = broadcast(abs, Ifrs)

    mat = zeros(3,3)
    mat[:,1] = Iss
    mat[:,2] = Ifrs
    mat[:,3] = Itos
    return amat
end
"""
    restraint(data::Dict{String,Any}, CTs::Vector, TS::Number)::Number
    
Function that calculated the slope setting of differential relay based on tap setting.
"""
function restraint(data::Dict{String,Any}, CTs::Vector, TS::Number)::Number
    N = length(CTs)
    Is_rated = zeros(N,1)
    for i = 1:N
        Is_rated[i] = data["protection"]["C_Transformers"]["$(CTs[i])"]["turns"][2]
    end
    I_rated = sum(Is_rated,dims=1)
    return Ir = TS*2/(I_rated[1])
end
end