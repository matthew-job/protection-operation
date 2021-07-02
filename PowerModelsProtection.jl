
module PowerModelsProtection
    using Base: Int64
import JuMP
    import MathOptInterface

    import InfrastructureModels
    import PowerModels
    import PowerModelsDistribution

    const _IM = InfrastructureModels
    const _PM = PowerModels
    const _PMD = PowerModelsDistribution

    import InfrastructureModels: ismultinetwork, nw_id_default
    import PowerModelsDistribution: ENABLED, DISABLED
    
    using Printf
    #using Debugger
    include("core/variable.jl")
    include("core/constraint_template.jl")
    include("core/constraint.jl")
    include("core/constraint_inverter.jl")
    include("core/data.jl")
    include("core/expression.jl")
    include("core/ref.jl")
    include("core/objective.jl")
    include("core/solution.jl")

    include("data_model/units.jl")
    include("data_model/components.jl")
    include("data_model/eng2math.jl")
    include("data_model/math2eng.jl")

    include("io/common.jl")
    include("io/dss/dss2eng.jl")
    include("io/matpower.jl")
    include("io/opendss.jl")

    include("prob/fs.jl")
    include("prob/fs_mc.jl")
    include("prob/pf_mc.jl")

    include("core/operation.jl")
    include("core/helper_functions.jl")
    include("core/dssparse.jl")
    include("core/relays.jl")
    include("core/cts.jl")

    include("core/export.jl")  # must be last include to properly export functions
end
