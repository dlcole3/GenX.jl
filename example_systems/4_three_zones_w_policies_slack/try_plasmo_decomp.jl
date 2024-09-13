using Pkg

case = dirname(@__FILE__)

Pkg.activate(dirname(dirname(case)))

using GenX,Revise

genx_settings = GenX.get_settings_path(case, "genx_settings.yml") # Settings YAML file path
writeoutput_settings = GenX.get_settings_path(case, "output_settings.yml") # Write-output settings YAML file path
setup = GenX.configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters

setup["Benders"] = 1;
benders_settings_path = GenX.get_settings_path(case, "benders_settings.yml")
setup_benders = GenX.configure_benders(benders_settings_path)
setup = merge(setup,setup_benders);

setup["settings_path"] = GenX.get_settings_path(case);

inputs = GenX.load_inputs(setup, case);
PLANNING_OPTIMIZER = GenX.configure_benders_planning_solver(setup["settings_path"]);
SUBPROB_OPTIMIZER =  GenX.configure_benders_subprob_solver(setup["settings_path"]);

graph,linking_variables_maps = GenX.generate_graph_model(setup,inputs,PLANNING_OPTIMIZER,SUBPROB_OPTIMIZER)
#graph2,linking_variables_maps2 = GenX.generate_graph_model(setup,inputs,PLANNING_OPTIMIZER,SUBPROB_OPTIMIZER)

using PlasmoBenders, JuMP, Plasmo, Gurobi, Suppressor

solver = optimizer_with_attributes(Gurobi.Optimizer, "OutputFlag" => false, "Method" => 2, "Crossover"=> 0)
#solver = optimizer_with_attributes(Gurobi.Optimizer, "OutputFlag" => false)#, "Method" => 2, "Crossover"=> 0, "BarConvTol" => 1e-3)
#@suppress_err begin
BendersOpt = BendersOptimizer(graph, get_nodes(graph)[1],
    regularize = true,
    multicut = true,
    parallelize_benders = true,
    tol = 1e-4,
    solver=solver,
    max_iters = 350,
    warm_start = false,
)
t1 = @elapsed optimize!(BendersOpt)


using DataFrames, CSV

df = DataFrame()
df[!, "UB"] = BendersOpt.upper_bounds
df[!, "LB"] = BendersOpt.lower_bounds
df[!, "Time"] = BendersOpt.time_iterations


CSV.write((@__DIR__)*"/benders_reg.csv", df)
