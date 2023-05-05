#Import libraries
using JuMP
using Gurobi
using Printf
using CSV, DataFrames
using Random, Distributions 

#**************************************************
# Import scenarios
Random.seed!(1234) # Set seed for reproducibility
include("ass2_step_2.4_scenarios.jl")

#**************************************************
strat_gen_cap = gen_cap[1:4]
strat_gen_cost = gen_cost[1:4]
# Generator Set
G = 8
# Strategic producer:
S = 4
# Non-Strategic producer:
O = 4
# Demand set
D = 4
# Node set
N = 6
# Sucseptance
B = 50
# Seen scenarios
A = 20
# Probability of each scenario
prob = 1/A
# Big M 
M = [4000, 1970, 3500, 20000]

# Create a function that returns the connected nodes in an ingoing and outgoing direction
connections = length(transm_connections)
function connected_nodes(node)
    outgoing = []
    ingoing = []
    for i=1:connections
        if node == transm_connections[i][1]
            push!(outgoing, transm_connections[i][2])
        elseif node == transm_connections[i][2]
            push!(ingoing, transm_connections[i][1])
        end
    end
    return(outgoing, ingoing)
end

# make functions receiving a demand, strategic or non-strategic generator as input
# and returning it's node location as output.

function node_demands(demand)
    loc_demands = 0
    for i=1:length(node_dem)
        if node_dem[i] == []
            continue
        end
        if node_dem[i][1] == demand
            loc_demands = i
        end
    end
    return(loc_demands)
end

function node_strat_gen(strat)
    loc_strat = 0
    for i=1:length(strat_node_gen)
        if strat_node_gen[i] == []
            continue
        end
        if strat_node_gen[i][1] == strat
            loc_strat = i
        end
    end
    return(loc_strat)
end

function node_non_strat_gen(nonstrat)
    loc_non_strat = 0
    for i=1:length(non_strat_node_gen)
        if non_strat_node_gen[i] == []
            continue
        end
        if non_strat_node_gen[i][1] == nonstrat
            loc_non_strat = i
        end
    end 
    return(loc_non_strat)
end

#**************************************************
# MODEL
Step_2_4=Model(Gurobi.Optimizer)

#**************************************************

#Variables
@variables Step_2_4 begin
    alpha_s_offer[s=1:S] >=0
    ps[s=1:S, a=1:A] >=0
    po[o=1:O, a=1:A] >=0
    pd[d=1:D, a=1:A] >=0
    theta[n=1:N, a=1:A]
    lambda[n=1:N, a=1:A] >=0
    mu_d_cap[d=1:D, a=1:A] >=0
    mu_d_undercap[d=1:D, a=1:A] >=0
    mu_s_cap[s=1:S, a=1:A] >= 0
    mu_s_undercap[s=1:S, a=1:A] >=0
    mu_o_cap[o=1:O, a=1:A] >=0
    mu_o_undercap[o=1:O, a=1:A] >=0 
    rho_cap[n=1:N, m=1:N, a=1:A] >= 0 
    rho_undercap[n=1:N, m=1:N, a=1:A] >= 0 
    gamma[a=1:A]
    psi_d_cap[d=1:D, a=1:A], Bin 
    psi_d_undercap[d=1:D, a=1:A], Bin
    psi_s_cap[s=1:S, a=1:A], Bin
    psi_s_undercap[s=1:S, a=1:A], Bin
    psi_o_cap[o=1:O, a=1:A], Bin
    psi_o_undercap[o=1:O, a=1:A], Bin
    psi_n_m_cap[n=1:N, m=1:N, a=1:A], Bin
    psi_n_m_undercap[n=1:N, m=1:N, a=1:A], Bin
end 

#**************************************************
# Objective function

@objective(Step_2_4, Max,
sum(prob * (
- sum(ps[s, a] * strat_gen_cost[s] for s=1:S) # Total cost of strategic generator production
+ sum(seen_scenarios[d, 2, a] * pd[d, a] for d=1:D) # Total demand value
- sum(seen_scenarios[o, 1, a] * po[o, a] for o=1:O) # Total cost of non-strategic generator production
- sum(mu_d_cap[d, a] * seen_scenarios[d, 3, a] for d=1:D) 
- sum(mu_o_cap[o, a] * seen_scenarios[o, 4, a] for o = 1:O)
- sum(rho_undercap[n, m, a] * transm_capacity[n, m] for n=1:N, m in connected_nodes(n)[2])
- sum(rho_cap[n, m, a] * transm_capacity[n, m] for n=1:N, m in connected_nodes(n)[2])
) for a=1:A))

#**************************************************
# Constraints 

@constraint(Step_2_4, [d=1:D, a=1:A], - seen_scenarios[d, 2, a] + mu_d_cap[d, a] - mu_d_undercap[d, a] 
            + lambda[node_demands(d), a] == 0)  # Dual of demand capacity constraint

@constraint(Step_2_4, [s=1:S, a=1:A], alpha_s_offer[s] + mu_s_cap[s, a] - mu_s_undercap[s, a] 
            - lambda[node_strat_gen(s), a] == 0) # Dual of strategic capacity constraint

@constraint(Step_2_4, [o=1:O, a=1:A], seen_scenarios[o, 1, a] + mu_o_cap[o, a] - mu_o_undercap[o, a] 
            - lambda[node_non_strat_gen(o), a] == 0) # Dual of non-strategic capacity constraint

@constraint(Step_2_4, [n=1:N, a=1:A],
            sum(B .* (lambda[n, a] - lambda[m, a]) for m in connected_nodes(n)[2])
            + sum(B .* (rho_cap[n, m, a] - rho_cap[m, n, a]) for m in connected_nodes(n)[2])
            + sum(B .* (rho_undercap[n, m, a] - rho_undercap[m, n, a]) for m in connected_nodes(n)[2]) 
            + gamma[a] == 0
            )

@constraint(Step_2_4, [a=1:A], theta[1, a] == 0)

@constraint(Step_2_4, [n=1:N, a=1:A],
                sum(pd[d, a] for d in node_dem[n])
                + sum(B .* (theta[n, a] - theta[m, a]) for m in connected_nodes(n)[2])
                - sum(B .* (theta[m, a] - theta[n, a]) for m in connected_nodes(n)[1]) 
                - sum(ps[s, a] for s in strat_node_gen[n])
                - sum(po[o, a] for o in non_strat_node_gen[n]) == 0
)

@constraint(Step_2_4, [d=1:D, a=1:A], 0 <= seen_scenarios[d, 3, a] - pd[d, a]) # Demand capacity constraint

@constraint(Step_2_4, [d=1:D, a=1:A], seen_scenarios[d, 3, a] - pd[d, a] <= psi_d_cap[d, a] .* M[1]) 

@constraint(Step_2_4, [d=1:D, a=1:A], mu_d_cap[d, a] <= (1 .- psi_d_cap[d, a]) .* M[1]) 

@constraint(Step_2_4, [d=1:D, a=1:A], pd[d, a] <= psi_d_undercap[d, a] .* M[1])

@constraint(Step_2_4, [d=1:D, a=1:A], mu_d_undercap[d, a] <= (1 .- psi_d_undercap[d, a]) .* M[1]) 

@constraint(Step_2_4, [s=1:S, a=1:A], 0 <= strat_gen_cap[s] .- ps[s, a]) # Strategic producer capacity constraint

@constraint(Step_2_4, [s=1:S, a=1:A], strat_gen_cap[s] - ps[s, a] <= psi_s_cap[s, a] .* M[2]) 

@constraint(Step_2_4, [s=1:S, a=1:A], mu_s_cap[s, a] <= (1 .- psi_s_cap[s, a]) .* M[2]) 

@constraint(Step_2_4, [s=1:S, a=1:A], ps[s, a] <= psi_s_undercap[s, a] .* M[2])

@constraint(Step_2_4, [s=1:S, a=1:A], mu_s_undercap[s, a] <= (1 .- psi_s_undercap[s, a]) .* M[2]) 

@constraint(Step_2_4, [o=1:O, a=1:A], 0 <= seen_scenarios[o, 4, a] - po[o, a]) # Non-stratgic producer capacity constraint

@constraint(Step_2_4, [o=1:O, a=1:A], seen_scenarios[o, 4, a] - po[o,a] <= psi_o_cap[o, a] .* M[3]) 

@constraint(Step_2_4, [o=1:O, a=1:A], mu_o_cap[o, a] <= (1 .- psi_o_cap[o, a]) .* M[3]) 

@constraint(Step_2_4, [o=1:O, a=1:A], po[o, a] <= psi_o_undercap[o, a] .* M[3])

@constraint(Step_2_4, [o=1:O, a=1:A], mu_o_undercap[o, a] <= (1 .- psi_o_undercap[o, a]) .* M[3]) 

for n=1:N
    for m=1:N   
        if transm_capacity[n,m] != 0
            for a=1:A
                @constraint(Step_2_4,
                0 <= transm_capacity[n,m] - B * (theta[n, a] - theta[m, a])) # transmission capacity constraint
                @constraint(Step_2_4,
                transm_capacity[n,m] - B * (theta[n, a] - theta[m, a]) <= psi_n_m_cap[n,m,a] .* M[4])
                @constraint(Step_2_4,
                rho_cap[n,m,a] <= (1 .- psi_n_m_cap[n,m,a]) .* M[4])
            end
        end
    end
end

for n=1:N
    for m=1:N   
        if transm_capacity[n,m] != 0
            for a=1:A
                @constraint(Step_2_4,
                0 <= transm_capacity[n,m] + B * (theta[n, a] - theta[m, a]))
                @constraint(Step_2_4,
                transm_capacity[n,m] + B * (theta[n, a] - theta[m, a]) <= psi_n_m_undercap[n,m,a] .* M[4])
                @constraint(Step_2_4,
                rho_undercap[n,m,a] <= (1 .- psi_n_m_undercap[n,m,a]) .* M[4])
            end 
        end
    end
end

#************************************************************************
# Solve
solution = optimize!(Step_2_4)
#**************************************************

# Print results
if termination_status(Step_2_4) == MOI.OPTIMAL
    println("Optimal solution found")

    println("Objective value = expected profit: ", objective_value(Step_2_4))

    # strategic offer price
    str_offer_price = value.(alpha_s_offer[:])
    for s=1:S 
        println("Offer price of strategic producer S$s: ", str_offer_price[s])
    end 

    # Offer schedules
    str_offer_schedule = zeros(S, A)
    str_offer_schedule = value.(ps[:,:])
    non_str_offer_schedule = zeros(O, A)
    non_str_offer_schedule = value.(po[:,:])

    # Market clearing price
    mc_price = zeros(N, A)
    mc_price = value.(lambda[:,:])

    # Expected profit of strategic producers
    str_profit = zeros(S)
    for s = 1:S
        str_profit[s] = sum(prob .*
        (str_offer_schedule[s, a] * (mc_price[node_strat_gen(s), a] - strat_gen_cost[s])
        for a=1:A))
        println("Expected profit of strategic producer S$s: ", str_profit[s])
    end 

    # Expected Social welfare
    social_welfare = sum(prob .*
    (sum(seen_scenarios[d, 2, a] * value.(pd[d, a]) for d in 1:D)
    - sum(strat_gen_cost[s] * str_offer_schedule[s, a] for s in 1:S)
    - sum(seen_scenarios[o, 1, a] * non_str_offer_schedule[o, a] for o in 1:O))
    for a in 1:A)
    println("Social welfare: ", social_welfare)

else 
    println("No optimal solution found")
end