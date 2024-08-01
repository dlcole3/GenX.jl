using Pkg
using Revise

case = dirname(@__FILE__)

Pkg.activate(dirname(dirname(case)))

using GenX, HiGHS, Plasmo, JuMP

genx_settings = GenX.get_settings_path(case, "genx_settings.yml") # Settings YAML file path
writeoutput_settings = GenX.get_settings_path(case, "output_settings.yml") # Write-output settings YAML file path
mysetup = GenX.configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters

settings_path = GenX.get_settings_path(case)

 ### Cluster time series inputs if necessary and if specified by the user
 if mysetup["TimeDomainReduction"] == 1
    TDRpath = joinpath(case, mysetup["TimeDomainReductionFolder"])
    system_path = joinpath(case, mysetup["SystemFolder"])
    GenX.prevent_doubled_timedomainreduction(system_path)
    if !GenX.time_domain_reduced_files_exist(TDRpath)
        println("Clustering Time Series Data (Grouped)...")
        GenX.cluster_inputs(case, settings_path, mysetup)
    else
        println("Time Series Data Already Clustered.")
    end
end

myinputs = GenX.load_inputs(mysetup, case);

myinputs_decomp = GenX.separate_inputs_subperiods(myinputs);

OPTIMIZER = configure_solver(settings_path, HiGHS.Optimizer)

decomp_models = Dict();

num_subperiods = length(myinputs_decomp)

g = OptiGraph()

@optinode(g, master_node)
@optinode(g, nodes[1:num_subperiods])

for i in 1:num_subperiods
    myinputs_decomp[i]["Node"] = nodes[i]
end

myinputs["Node"] = master_node
master_model = GenX.generate_investment_model(mysetup,myinputs,OPTIMIZER);

for w in keys(myinputs_decomp)
    decomp_models[w] = generate_model(mysetup, myinputs_decomp[w], OPTIMIZER);
end

link_vars = all_variables(master_node)
var_strings = name.(link_vars)
cleaned_strings = [replace(str, r"master_node\[:(.*)\]" => s"\1") for str in var_strings]
var_symbols = Symbol.(cleaned_strings)

for w in keys(myinputs_decomp)
    @linkconstraint(g, master_node[:vZERO] == decomp_models[w][:vZERO])
    for i in 1:10
        @linkconstraint(g, master_node[:vCAP][i] == decomp_models[w][:vCAP][i])
    end
    for i in 1:2
        @linkconstraint(g, master_node[:vNEW_TRANS_CAP][i] == decomp_models[w][:vNEW_TRANS_CAP][i])
    end
    for i in 8:10
        @linkconstraint(g, master_node[:vCAPENERGY][i] == decomp_models[w][:vCAPENERGY][i])
    end
end
set_optimizer(g, OPTIMIZER)

optimize!(g)
