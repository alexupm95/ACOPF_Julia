cd(dirname(@__FILE__));

#=
CODE FOR SOLVING THE AC POWER FLOW WITHOUT RELAXATIONS

Author:      Alex Junior da Cunha Coelho
Supervisors: Luis Badesa Bernardo and Araceli Hernandez Bayo
Affiliation: Technical University of Madrid
August 2025

===================================================================
                        IMPORTANT NOTES 
===================================================================
Taps of transformers are considered tap:1 (i.e., from tap -> to 1)
Phase shift of transformers must be in degrees in the input file
=#

#---------------------------
# INCLUDE THE PACKAGES USED
#---------------------------
# Packages related to linear algebra
using LinearAlgebra, SparseArrays

# Packages related to treatement of data
using Dates, NumericIO, DataFrames, Printf, CSV, DataStructures

# Packages related to the optimization
using JuMP, Ipopt, AmplNLWriter, Couenne_jll

# Packages for plotting
using Plots, LaTeXStrings, Measures

#---------------------------------
# INCLUDE AUXILIAR FUNCTION FILES
#--------------------------------
include("AF_CLEAN_TERMINAL.jl")         # Auxiliar function to clean the terminal
include("AF_READ_DATA.jl")              # Auxiliar functions used to read input data
include("AF_YBUS.jl")                   # Auxiliar function to create Ybus
include("BUILD_ACOPF_MODEL_REDUCED.jl") # Auxiliar function to create the AC OPF model for optimization (this creates a reduced version neglecting OFF components)
include("AF_SAVE_OUTPUT.jl")            # Auxiliar function to save the output results
include("AF_MANAGEMENT.jl")             # Auxiliar function that calculates AC power flow and manage some data

Clean_Terminal() # Clean the terminal

#-----------------------------------------
# Generate a folder to export the results
#-----------------------------------------
current_path_folder = pwd()                                            # Directory of the current folder
name_path_results   = "Results"                                        # Name of the folder to save the results (it must be created in advance)
path_folder_results = joinpath(current_path_folder, name_path_results) # Results directory
cd(current_path_folder)                                                # Load the current folder

#=
----------------------------------------------
 Relevant input variables to solve the AC-OPF
----------------------------------------------
** Select a system from the options below: **
3bus
9bus
9bus_Conejo_Paper
24bus
30bus
39bus
39bus_Conejo_Paper
39bus_UC3M
118bus
300bus
300busMATPOWER
1888bus
2848bus
3012bus
3970bus
=#

solver = "Ipopt" # or Couenne
case     = "9bus" # Case under study (folder name)
base_MVA = 100.0  # Base Power [MVA]

#------------------------------------------
# Call the function to read the input data
#------------------------------------------
input_data_path_folder = joinpath(current_path_folder, "Input_Data", case) # Folder name where the input data is located
# Get the structs with data related to buses, generators and circuits
DBUS, DGEN, DCIR, bus_mapping, reverse_bus_mapping = Read_Input_Data(input_data_path_folder) 

# Variable to multiply the power demanded by the loads
load_factor = 1.0
DBUS.p_d = load_factor .* (DBUS.p_d)
DBUS.q_d = load_factor .* (DBUS.q_d)
# ---------------------------------------------------

nBUS = length(DBUS.bus)      # Number of buses in the system
nGEN = length(DGEN.id)       # Number of generators in the system
nCIR = length(DCIR.from_bus) # Number of circuits in the system
cd(current_path_folder)      # Load the current folder

#-------------------------------------------------------------------------------------------------
# Associates the buses with the generators and circuits connected to it, as well as adjacent buses
#-------------------------------------------------------------------------------------------------
bus_gen_circ_dict, bus_gen_circ_dict_ON = Manage_Bus_Gen_Circ(DBUS, DGEN, DCIR) 

#-----------------------------------
# Calculate the admittance matrices
#-----------------------------------

# Calculate the admittance matrix for the pre-fault period
Ybus_pref = Calculate_Ybus(DBUS, DCIR, nBUS, nCIR, base_MVA) # Admittance matrix for the pre-fault stage

cd(joinpath(path_folder_results,"Admittance_Matrices"))
df_Ybus_pref = DataFrame(Matrix(Ybus_pref), :auto)        # Convert the admittance matrix of the pre-fault into a DataFrame to save it
CSV.write("df_Ybus.csv", df_Ybus_pref; delim=';')    # Save the admittance matrix of the pre-fault in a CSV file

println("--------------------------------------------------------------------------------------------------------------------------------------")
println("Admittance matrix successfully saved in: ", joinpath(path_folder_results,"Admittance_Matrices"))
println("--------------------------------------------------------------------------------------------------------------------------------------")
cd(current_path_folder)

# ########################################################################################
#                                 STARTS OPTIMIZATION PROCESS 
#-----------------------------------
# Optimization model -> Setup
#-----------------------------------
if solver == "Ipopt"
    optimizer = Ipopt.Optimizer # Interior Point Solver
elseif solver == "Couenne"
    optimizer = JuMP.optimizer_with_attributes(() -> AmplNLWriter.Optimizer(Couenne_jll.amplexe)) # Convex Over and Under ENvelopes for NEonlinear Estimation solver
else 
    throw(ArgumentError("Define a suitable NLP solver."))
end

model = JuMP.Model(optimizer)
if optimizer == Ipopt.Optimizer
    # Options (matching Ipopt's keywords)
    JuMP.set_optimizer_attribute(model, "tol", 1e-8)                # Desired convergence tolerance (relative)
    JuMP.set_optimizer_attribute(model, "print_level", 5)           # Verbosity level -> 0 = print nothing / 5 = print details
    JuMP.set_optimizer_attribute(model, "output_file", "")          # Solution report
    JuMP.set_optimizer_attribute(model, "max_iter", 5000)           # Maximum number of iterations
    JuMP.set_optimizer_attribute(model, "dual_inf_tol", 1e-6)       # Desired threshold for the dual infeasibility
    JuMP.set_optimizer_attribute(model, "constr_viol_tol", 1e-8)    # Desired threshold for the constraint violation
    JuMP.set_optimizer_attribute(model, "compl_inf_tol", 1e-8)      # Acceptance threshold for the complementarity conditions
    JuMP.set_silent(model)

else
    # Options (matching COUENNE's keywords)
    JuMP.set_optimizer_attribute(model, "print_level", 5)           # Verbosity level -> 0 = print nothing / 5 = print details
    JuMP.set_optimizer_attribute(model, "max_cpu_time", 360)        # CPU time limit
    JuMP.set_optimizer_attribute(model, "bonmin.time_limit", 360)   # Set the global maximum computation time (in secs) for the algorithm
    JuMP.set_optimizer_attribute(model, "bonmin.solution_limit", 1) # Abort after that much integer feasible solution have been found by algorithm
    JuMP.set_optimizer_attribute(model, "max_iter", 5000)           # Maximum number of iterations
    JuMP.set_optimizer_attribute(model, "dual_inf_tol", 1e-6)       # Desired threshold for the dual infeasibility
    JuMP.set_optimizer_attribute(model, "constr_viol_tol", 1e-8)    # Desired threshold for the constraint violation
    JuMP.set_optimizer_attribute(model, "compl_inf_tol", 1e-8)      # Acceptance threshold for the complementarity conditions
    # JuMP.set_silent(model)
end

#------------------------------
# Build the Optimization Model
#------------------------------
time_to_build_model = time() # Start the timer to build the Optimization Model

model, V, θ, P_g, Q_g, P_ik, Q_ik, P_ki, Q_ki, eq_const_angle_sw, eq_const_p_balance, eq_const_q_balance, 
eq_const_p_ik, eq_const_q_ik, eq_const_p_ki, eq_const_q_ki, ineq_const_s_ik, ineq_const_s_ki, 
ineq_const_diff_ang = Make_ACOPF_Model!(model, DBUS, DGEN, DCIR, bus_gen_circ_dict_ON, base_MVA, nBUS, nGEN, nCIR)

time_to_build_model = time() - time_to_build_model # End the timer to build the Optimization Model
println("\nTime to build the model: $time_to_build_model sec\n")

# =====================================================================================

#-------------------------------------------------------------------------------------
#                         SAVE MODEL SUMMARY AND DETAILS
#-------------------------------------------------------------------------------------
println("--------------------------------------------------------------------------------------------------------------------------------------")
Export_ACOPF_Model(model, V, θ, P_g, Q_g, P_ik, Q_ik, P_ki, Q_ki, eq_const_angle_sw, eq_const_p_balance, eq_const_q_balance, 
eq_const_p_ik, eq_const_q_ik, eq_const_p_ki, eq_const_q_ki, ineq_const_s_ik, ineq_const_s_ki, 
ineq_const_diff_ang, current_path_folder, path_folder_results)

println("--------------------------------------------------------------------------------------------------------------------------------------")

# ---------------------------------
#  Solve the optmization problem
# ---------------------------------
time_to_solve_model = time()                       # Start the timer to solve the Optimization Model
JuMP.optimize!(model)                              # Optimize model
time_to_solve_model = time() - time_to_solve_model # End the timer to build the Optimization Model
println("\nTime to solve the model: $time_to_solve_model sec")
status_model = JuMP.termination_status(model)
println("Termination Status: $status_model \n")
println("--------------------------------------------------------------------------------------------------------------------------------------")


#                               ENDS OPTIMIZATION PROCESS 
# ########################################################################################

RBUS::Union{Nothing, DataFrame} = nothing
RGEN::Union{Nothing, DataFrame} = nothing
RCIR::Union{Nothing, DataFrame} = nothing

if status_model == OPTIMAL || status_model == LOCALLY_SOLVED || status_model == ITERATION_LIMIT
    #-------------------------------------------------------------------------------------
    #                             SAVE RESULTS 
    #-------------------------------------------------------------------------------------
    RBUS, RGEN, RCIR = Save_Solution_Model(model, V, θ, P_g, Q_g, P_ik, Q_ik, P_ki, Q_ki, 
    bus_gen_circ_dict_ON, DBUS, DGEN, DCIR, base_MVA, nBUS, nGEN, nCIR, bus_mapping,
    reverse_bus_mapping, current_path_folder, path_folder_results)

    #-------------------------------------------------------------------------------------
    #                             SAVE DUALS 
    #-------------------------------------------------------------------------------------
    Save_Duals_ACOPF_Model(model, V, θ, P_g, Q_g, P_ik, Q_ik, P_ki, Q_ki, eq_const_angle_sw, eq_const_p_balance, eq_const_q_balance, 
    eq_const_p_ik, eq_const_q_ik, eq_const_p_ki, eq_const_q_ki, ineq_const_s_ik, ineq_const_s_ki, 
    ineq_const_diff_ang, base_MVA, current_path_folder, path_folder_results)

else
    JuMP.@warn "Optmization process failed. No feasible solution found."
end
println("--------------------------------------------------------------------------------------------------------------------------------------")
