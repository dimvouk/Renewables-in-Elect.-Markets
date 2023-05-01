#Import libraries
using JuMP
using Gurobi
using Printf
using CSV, DataFrames


#**************************************************
#Get Data
include("ass2.1_data.jl")

strat_gen_cap = gen_cap[1:4]
strat_gen_cost = gen_cost[1:4]
non_strat_gen_cap = gen_cap[5:8]
non_strat_gen_cost = gen_cost[5:8]

#**************************************************

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
# Big M 
M = [800, 700, 750, 4000, 15]

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

# make function similar for demand, strategic and non strategic.

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
Step_2_2=Model(Gurobi.Optimizer)

#**************************************************

#Variables
@variables Step_2_2 begin
    alpha_s_offer[s=1:S] >=0
    ps[s=1:S] >=0
    po[o=1:O] >=0
    pd[d=1:D] >=0
    theta[n=1:N]
    lambda[n=1:N] >=0
    mu_d_cap[d=1:D] >=0
    mu_d_undercap[d=1:D] >=0
    mu_s_cap[s=1:S] >= 0
    mu_s_undercap[s=1:S] >=0
    mu_o_cap[o=1:O] >=0
    mu_o_undercap[o=1:O] >=0 
    rho_cap[n=1:N, m=1:N] >= 0 # maybe >= 0 or -F_{n,m}?
    rho_undercap[n=1:N, m=1:N] >= 0 # maybe >= 0 or -F_{n,m}?
    gamma
    delta_cap[n=1:N] >= 0 # maybe >= 0 or -pi?
    delta_undercap[n=1:N] >= 0 # maybe >= 0 or -pi?
    psi_d_cap[d=1:D], Bin 
    psi_d_undercap[d=1:D], Bin
    psi_s_cap[s=1:S], Bin
    psi_s_undercap[s=1:S], Bin
    psi_o_cap[o=1:O], Bin
    psi_o_undercap[o=1:O], Bin
    psi_n_m_cap[n=1:N, m=1:N], Bin # maybe indexed by m also?
    psi_n_m_undercap[n=1:N, m=1:N], Bin # maybe indexed by m also?
    psi_n_cap[n=1:N], Bin
    psi_n_undercap[n=1:N], Bin
end 

#**************************************************
# Objective function

@objective(Step_2_2, Max,
- sum(ps[s] * strat_gen_cost[s] for s=1:S) # Total cost of strategic generator production
+ sum(demand_bid[d] * pd[d] for d=1:D) # Total demand value
- sum(non_strat_gen_cost[o] * po[o] for o=1:O) # Total cost of non-strategic generator production
- sum(mu_d_cap[d] * demand_cons[d] for d=1:D) 
- sum(mu_o_cap[o] * non_strat_gen_cap[o] for o = 1:O)
- sum(rho_undercap[n,m] * transm_capacity[n,m] for n=1:N, m in connected_nodes(n)[2])
- sum(rho_cap[n,m] * transm_capacity[n,m] for n=1:N, m in connected_nodes(n)[2])
- sum(delta_cap[n] * pi for n=1:N)
- sum(delta_undercap[n] * pi for n=1:N)
)

#**************************************************
# Constraints 

@constraint(Step_2_2, [s=1:S], alpha_s_offer[s] >= strat_gen_cost[s])

@constraint(Step_2_2, [d=1:D], 0 == - demand_bid[d] + mu_d_cap[d] - mu_d_undercap[d] 
            + lambda[node_demands(d)])  # Dual of demand capacity constraint

@constraint(Step_2_2, [s=1:S], 0 == alpha_s_offer[s] + mu_s_cap[s] - mu_s_undercap[s] 
            - lambda[node_strat_gen(s)]) # Dual of strategic capacity constraint

@constraint(Step_2_2, [o=1:O], 0 == non_strat_gen_cost[o] + mu_o_cap[o] - mu_o_undercap[o] 
            - lambda[node_non_strat_gen(o)]) # Dual of non-strategic capacity constraint

@constraint(Step_2_2, [n=1:N], 0 ==
            sum(B * (lambda[n] - lambda[m]) for m in connected_nodes(n)[2])
            + sum(B .* (rho_cap[n,m] - rho_cap[m,n]) for m in connected_nodes(n)[2])
            + sum(B .* (rho_undercap[n,m] - rho_undercap[m,n]) for m in connected_nodes(n)[2]) 
            + gamma
            + delta_cap[n] - delta_undercap[n]
            )

@constraint(Step_2_2, theta[1] == 0)

@constraint(Step_2_2, [n=1:N], 0 ==
                sum(pd[d] for d in node_dem[n])
                + sum(B * (theta[n] - theta[m]) for m in connected_nodes(n)[2])
                - sum(B * (theta[m] - theta[n]) for m in connected_nodes(n)[1]) 
                - sum(ps[s] for s in strat_node_gen[n])
                - sum(po[o] for o in non_strat_node_gen[n])
)

@constraint(Step_2_2, [d=1:D], demand_cons[d] - pd[d] >= 0) # Demand capacity constraint

@constraint(Step_2_2, [d=1:D], demand_cons[d] - pd[d] <= psi_d_cap[d] * M[1]) 

@constraint(Step_2_2, [d=1:D], mu_d_cap[d] <= (1-psi_d_cap[d]) * M[1]) 

@constraint(Step_2_2, [d=1:D], pd[d] <= psi_d_undercap[d] * M[1])

@constraint(Step_2_2, [d=1:D], mu_d_undercap[d] <= (1-psi_d_undercap[d]) * M[1]) 

@constraint(Step_2_2, [s=1:S], strat_gen_cap[s] - ps[s] >= 0) # Stratgic producer capacity constraint

@constraint(Step_2_2, [s=1:S], strat_gen_cap[s] - ps[s] <= psi_s_cap[s] * M[2]) 

@constraint(Step_2_2, [s=1:S], mu_s_cap[s] <= (1-psi_s_cap[s]) * M[2]) 

@constraint(Step_2_2, [s=1:S], ps[s] <= psi_s_undercap[s] * M[2])

@constraint(Step_2_2, [s=1:S], mu_s_undercap[s] <= (1-psi_s_undercap[s]) * M[2]) 

@constraint(Step_2_2, [o=1:O], non_strat_gen_cap[o] - po[o] >= 0) # Non-stratgic producer capacity constraint

@constraint(Step_2_2, [o=1:O], non_strat_gen_cap[o] - ps[o] <= psi_o_cap[o] * M[3]) 

@constraint(Step_2_2, [o=1:O], mu_o_cap[o] <= (1-psi_o_cap[o]) * M[3]) 

@constraint(Step_2_2, [o=1:O], ps[o] <= psi_o_undercap[o] * M[3])

@constraint(Step_2_2, [o=1:O], mu_o_undercap[o] <= (1-psi_o_undercap[o]) * M[3]) 

for n=1:N
    for m=1:N   
        if transm_capacity[n,m] != 0
            @constraint(Step_2_2,
            transm_capacity[n,m] - (B * (theta[n] - theta[m])) >= 0) # transmission capacity constraint
        end
    end
end

for n=1:N
    for m=1:N   
        if transm_capacity[n,m] != 0
            @constraint(Step_2_2,
            transm_capacity[n,m] - (B * (theta[n] - theta[m])) <= psi_n_m_cap[n] .* M[4])
        end
    end
end

for n=1:N
    for m=1:N   
        if transm_capacity[n,m] != 0
            @constraint(Step_2_2,
            rho_cap[n,m] <= (1 .- psi_n_m_cap[n,m]) .* M[4])
        end
    end
end

for n=1:N
    for m=1:N   
        if transm_capacity[n,m] != 0
            @constraint(Step_2_2,
            transm_capacity[n,m] + (B * (theta[n] - theta[m])) >= 0)
        end
    end
end

for n=1:N
    for m=1:N   
        if transm_capacity[n,m] != 0
            @constraint(Step_2_2,
            transm_capacity[n,m] + (B * (theta[n] - theta[m])) <= psi_n_m_undercap[n,m] .* M[4])
        end
    end
end

for n=1:N
    for m=1:N   
        if transm_capacity[n,m] != 0
            @constraint(Step_2_2,
            rho_undercap[n,m] <= (1 .- psi_n_m_undercap[n,m]) .* M[4])
        end
    end
end

@constraint(Step_2_2, [n=1:N], pi - theta[n] >= 0) # voltage phase angle constraint

@constraint(Step_2_2, [n=1:N], pi - theta[n] <= psi_n_cap[n] * M[5])

@constraint(Step_2_2, [n=1:N], delta_cap[n] <= (1 - psi_n_cap[n]) * M[5])

@constraint(Step_2_2, [n=1:N], pi + theta[n] >= 0)

@constraint(Step_2_2, [n=1:N], pi + theta[n] <= psi_n_undercap[n] * M[5])

@constraint(Step_2_2, [n=1:N], delta_undercap[n] <= (1-psi_n_undercap[n]) * M[5])

#************************************************************************
# Solve
solution = optimize!(Step_2_2)
#**************************************************

str_offer_price = zeros(S)

# Print results
if termination_status(Step_2_2) == MOI.OPTIMAL
    println("Optimal solution found")

    println("Objective value = social welfare: ", objective_value(Step_2_2))

    # strategic offer price
    str_offer_price = value.(alpha_s_offer[:])
    for s = 1:S
        println("Strategic offer price for generator S$s: ", str_offer_price[s])
    end 
else 
    println("No optimal solution found")
end