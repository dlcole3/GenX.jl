using Revise
using GenX, MadIPM

run_genx_case!(dirname(@__FILE__), MadIPM.Optimizer)
