using PowerModelsProtection, Ipopt, JuMP
# include("pms-print-tools.jl")

net = PowerModelsProtection.parse_file("case3_unbalanced.dss")
net["multinetwork"] = false
solver = JuMP.with_optimizer(Ipopt.Optimizer)

net["fault"] = Dict{String, Any}()
# net["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus", "phases" => [1], "gr" => .00001)
PowerModelsProtection.add_fault!(net, "1", "lg", "loadbus", [1, 4], 0.005)
results = PowerModelsProtection.solve_mc_fault_study(net, solver)


# for (k,br) in net["branch"]
#     j = br["t_bus"]
#     b = net["bus"]["$j"]
#     kvll = b["base_kv"]
#     ibase = net["baseMVA"]*1000*sqrt(3)/kvll
#     brs = result["solution"]["branch"]["$k"]

#     br["ckt"] = strip(br["source_id"][4])
#     br["cm_fr"] = abs(brs["cr_fr"] + 1im*brs["ci_fr"])
#     br["cm_to"] = abs(brs["cr_to"] + 1im*brs["ci_to"])
# end

# buses = to_df(net, "bus", result)
# branches = to_df(net, "branch", result)

# fb = sort(buses[!,[:index,:vm]])
# fbr = sort(branches[!,[:f_bus,:t_bus,:ckt,:cm_fr]], (:f_bus,:t_bus,:ckt))

# println("Bus solution\n----------------")
# println(fb)
