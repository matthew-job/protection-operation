using PowerModelsProtection: PowerModelsDistribution
using PowerModelsProtection, Ipopt, JuMP, Printf
include("protection_equip.jl")

#net = PowerModelsProtection.parse_file("case3_balanced_pv_2_grid_forming.dss")
net = PowerModelsProtection.parse_file("case3_unbalanced.dss")
net["multinetwork"] = false
solver = JuMP.with_optimizer(Ipopt.Optimizer)

# Simulate the fault
net["fault"] = Dict{String, Any}()
#PowerModelsProtection.add_fault!(net, "1", "3p", "primary", [1,2,3], 0.005)
PowerModelsProtection.add_fault!(net, "1", "lg", "primary", [1,4], 0.005)
results = PowerModelsProtection.solve_mc_fault_study(net, solver)

# Print out the fault currents
Iabc = results["solution"]["line"]["ohline"]["fault_current"]
@printf("Fault current: %0.3f A\n", Iabc[1])

#add relays and cts
#going to test 4 relays. 2 on ohline, 2 on quad, with on with a ct on each to compare
#also test wrong elements, ids, etc
@printf("Attempt to add CTs and relays\n")
add_ct(net,500,5,"ohline","CT1")
add_ct(net,500,5,"quad","CT1")
add_relay(net,"ohline2","R1",500,2)
add_relay(net,"ohline","R1",500,2)
add_relay(net,"ohline","R2",5,2,"CT2")
add_relay(net,"ohline","R2",5,2,"CT1")
add_relay(net,"quad","R1",500,0.5)
add_relay(net,"quad","R2",5,2,"CT1")

#check fault current and relays to determine if they trip
relay_operation_all(net,results)
#get report of which relay tripped
@printf("Fault is SLG on primary bus, so relays on ohline should trip, but not on quad\n")
relay_report(net)

#manually check with the currents to make sure it worked properly
@printf("Double check manually if relays worked properly\n")
If = results["solution"]["line"]["quad"]["fault_current"]
@printf("Fault current through quad was:\n")
@printf("a = %0.3f  ",If[1])
@printf("b = %0.3f  ",If[2])
@printf("c = %0.3f\n",If[3])
If = results["solution"]["line"]["ohline"]["fault_current"]
@printf("Fault current through ohline was:\n")
@printf("a = %0.3f  ",If[1])
@printf("b = %0.3f  ",If[2])
@printf("c = %0.3f\n",If[3])

#show relay information
@printf("Relay information:\n")
@printf("Ohline relay R1 phases:\n")
display(net["protection"]["relays"]["ohline"]["R1"]["phase"])
@printf("Ohline relay R2 phases:\n")
display(net["protection"]["relays"]["ohline"]["R2"]["phase"])
@printf("quad relay R1 phases:\n")
display(net["protection"]["relays"]["quad"]["R1"]["phase"])
@printf("quad relay R2 phases:\n")
display(net["protection"]["relays"]["quad"]["R2"]["phase"])

