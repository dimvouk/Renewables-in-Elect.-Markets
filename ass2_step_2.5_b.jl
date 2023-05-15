#Import libraries
using JuMP
using Gurobi
using Printf
using CSV, DataFrames
@time begin
#**************************************************
#Get Data
include("ass2_step_2_data.jl")
# model including 24 hours and ramping limits, following Step 2.2
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
# hours
T = 24
# Big M 
M = [500, 10, 250, 10, 400, 100, 5000, 10000]

#**************************************************
# MODEL
Step_2_5_b=Model(Gurobi.Optimizer)

#**************************************************

#Variables
@variables Step_2_5_b begin
    alpha_s_offer[t=1:T, s=1:S] >=0
    ps[t=1:T, s=1:S] >=0
    po[t=1:T, o=1:O] >=0
    pd[t=1:T, d=1:D] >=0
    theta[t=1:T, n=1:N]
    lambda[t=1:T, n=1:N] >=0
    mu_d_cap[t=1:T, d=1:D] >=0
    mu_d_undercap[t=1:T, d=1:D] >=0
    mu_s_cap[t=1:T, s=1:S] >= 0
    mu_s_undercap[t=1:T, s=1:S] >=0
    mu_o_cap[t=1:T, o=1:O] >=0
    mu_o_undercap[t=1:T, o=1:O] >=0 
    rho_cap[t=1:T, n=1:N, m=1:N] >= 0 
    rho_undercap[t=1:T, n=1:N, m=1:N] >= 0 
    gamma[t=1:T]
    psi_d_cap[t=1:T, d=1:D], Bin 
    psi_d_undercap[t=1:T, d=1:D], Bin
    psi_s_cap[t=1:T, s=1:S], Bin
    psi_s_undercap[t=1:T, s=1:S], Bin
    psi_o_cap[t=1:T, o=1:O], Bin
    psi_o_undercap[t=1:T, o=1:O], Bin
    psi_n_m_cap[t=1:T, n=1:N, m=1:N], Bin
    psi_n_m_undercap[t=1:T, n=1:N, m=1:N], Bin
end 

#**************************************************
# Objective function

@objective(Step_2_5_b, Max,
- sum(ps[t, s] * strat_gen_cost[s] for t=1:T, s=1:S) # Total cost of strategic generator production
+ sum(demand_bid_24[t,d] * pd[t,d] for t=1:T, d=1:D) # Total demand value
- sum(non_strat_gen_cost[o] * po[t,o] for t=1:T, o=1:O) # Total cost of non-strategic generator production
- sum(mu_d_cap[t,d] * demand_cons_24[t,d] for t=1:T, d=1:D) 
- sum(mu_o_cap[t,o] * non_strat_gen_cap_24[t,o] for t=1:T, o = 1:O)
- sum(rho_undercap[t,n,m] * transm_capacity[n,m] for t=1:T, n=1:N, m in connected_nodes(n)[2])
- sum(rho_cap[t,n,m] * transm_capacity[n,m] for t=1:T, n=1:N, m in connected_nodes(n)[2])
)

#**************************************************
# Constraints 

@constraint(Step_2_5_b, [t=1:T, d=1:D], - demand_bid_24[t,d] + mu_d_cap[t,d] - mu_d_undercap[t,d] 
            + lambda[t,node_demands(d)] == 0)  # Dual of demand capacity constraint

@constraint(Step_2_5_b, [t=1:T, s=1:S], alpha_s_offer[t,s] + mu_s_cap[t,s] - mu_s_undercap[t,s] 
            - lambda[t,node_strat_gen(s)] == 0) # Dual of strategic capacity constraint

@constraint(Step_2_5_b, [t=1:T, o=1:O], non_strat_gen_cost[o] + mu_o_cap[t,o] - mu_o_undercap[t,o] 
            - lambda[t,node_non_strat_gen(o)] == 0) # Dual of non-strategic capacity constraint

@constraint(Step_2_5_b, [t=1:T, n=1:N],
            sum(B * (lambda[t,n] - lambda[t,m]) for m in connected_nodes(n)[2])
            + sum(B .* (rho_cap[t,n,m] - rho_cap[t,m,n]) for m in connected_nodes(n)[2])
            + sum(B .* (rho_undercap[t,n,m] - rho_undercap[t,m,n]) for m in connected_nodes(n)[2]) 
            + gamma[t] == 0
            )

@constraint(Step_2_5_b, [t=1:T], theta[t,1] == 0)

@constraint(Step_2_5_b, [t=1:T, n=1:N],
                sum(pd[t,d] for d in node_dem[n])
                + sum(B * (theta[t,n] - theta[t,m]) for m in connected_nodes(n)[2])
                - sum(B * (theta[t,m] - theta[t,n]) for m in connected_nodes(n)[1]) 
                - sum(ps[t,s] for s in strat_node_gen[n])
                - sum(po[t,o] for o in non_strat_node_gen[n]) == 0
)

@constraint(Step_2_5_b, [t=1:T, d=1:D], 0 <= demand_cons_24[t,d] - pd[t,d]) # Demand capacity constraint

@constraint(Step_2_5_b, [t=1:T, d=1:D], demand_cons_24[t,d] - pd[t,d] <= psi_d_cap[t,d] * M[1]) 

@constraint(Step_2_5_b, [t=1:T, d=1:D], mu_d_cap[t,d] <= (1-psi_d_cap[t,d]) * M[2]) 

@constraint(Step_2_5_b, [t=1:T, d=1:D], pd[t,d] <= psi_d_undercap[t,d] * M[1])

@constraint(Step_2_5_b, [t=1:T, d=1:D], mu_d_undercap[t,d] <= (1-psi_d_undercap[t,d]) * M[2]) 

@constraint(Step_2_5_b, [t=1:T, s=1:S], 0 <= strat_gen_cap_24[t,s] - ps[t,s]) # Strategic producer capacity constraint

@constraint(Step_2_5_b, [t=1:T, s=1:S], strat_gen_cap_24[t,s] - ps[t,s] <= psi_s_cap[t,s] * M[3]) 

@constraint(Step_2_5_b, [t=1:T, s=1:S], mu_s_cap[t,s] <= (1-psi_s_cap[t,s]) * M[4]) 

@constraint(Step_2_5_b, [t=1:T, s=1:S], ps[t,s] <= psi_s_undercap[t,s] * M[3])

@constraint(Step_2_5_b, [t=1:T, s=1:S], mu_s_undercap[t,s] <= (1-psi_s_undercap[t,s]) * M[4]) 

@constraint(Step_2_5_b, [t=1:T, o=1:O], 0 <= non_strat_gen_cap_24[t,o] - po[t,o]) # Non-stratgic producer capacity constraint

@constraint(Step_2_5_b, [t=1:T, o=1:O], non_strat_gen_cap_24[t,o] - po[t,o] <= psi_o_cap[t,o] * M[5]) 

@constraint(Step_2_5_b, [t=1:T, o=1:O], mu_o_cap[t,o] <= (1-psi_o_cap[t,o]) * M[6]) 

@constraint(Step_2_5_b, [t=1:T, o=1:O], po[t,o] <= psi_o_undercap[t,o] * M[5])

@constraint(Step_2_5_b, [t=1:T, o=1:O], mu_o_undercap[t,o] <= (1-psi_o_undercap[t,o]) * M[6]) 

# ramping constraints
@constraint(Step_2_5_b, [t=2:T, s=1:S], -ramp_strat[s] <= ps[t,s] - ps[t-1,s] <= ramp_strat[s]) # Strategic producer ramping constraint
@constraint(Step_2_5_b, [t=2:T, o=2:O], -ramp_non_strat[o] <= po[t,o] - po[t-1,o] <= ramp_non_strat[o]) # Strategic producer ramping constraint

for t=1:T
    for n=1:N
        for m=1:N   
            if transm_capacity[n,m] != 0
                @constraint(Step_2_5_b,
                0 <= transm_capacity[n,m] - B * (theta[t,n] - theta[t,m])) # transmission capacity constraint
                @constraint(Step_2_5_b,
                transm_capacity[n,m] - B * (theta[t,n] - theta[t,m]) <= psi_n_m_cap[t,n,m] .* M[7])
                @constraint(Step_2_5_b,
                rho_cap[t,n,m] <= (1 .- psi_n_m_cap[t,n,m]) .* M[8])
            end
        end
    end
end 

for t=1:T
    for n=1:N
        for m=1:N   
            if transm_capacity[n,m] != 0
                @constraint(Step_2_5_b,
                0 <= transm_capacity[n,m] + B * (theta[t,n] - theta[t,m]))
                @constraint(Step_2_5_b,
                transm_capacity[n,m] + B * (theta[t,n] - theta[t,m]) <= psi_n_m_undercap[t,n,m] .* M[7])
                @constraint(Step_2_5_b,
                rho_undercap[t,n,m] <= (1 .- psi_n_m_undercap[t,n,m]) .* M[8])
            end
        end
    end
end

#************************************************************************
# Solve
solution = optimize!(Step_2_5_b)
end
#**************************************************

# Print results
if termination_status(Step_2_5_b) == MOI.OPTIMAL
    println("Optimal solution found")

    println("Objective value: ", objective_value(Step_2_5_b))

    # Market clearing price
    mc_price = zeros(T)
    mc_price = value.(lambda[:,1])
    for t= 1:T
        println("Market clearing price for hour $t ", mc_price[t])
    end 
    
    # strategic offer price
    str_offer_price = zeros(T,S)
    str_offer_price = value.(alpha_s_offer[:,:])
    for t=1:T
        for s=1:S
            println("Strategic offer price for generator S$s at hour $t ", str_offer_price[t,s])
        end 
    end

else 
    println("No optimal solution found")
end