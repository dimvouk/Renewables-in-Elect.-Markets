#Import libraries
using JuMP
using Gurobi
using Printf
using CSV, DataFrames
@time begin
#**************************************************
#Get Data
include("ass2_step_2_data.jl")
# model including 24 hours and ramping limits, following Step 2.1
#**************************************************

# Conventional Generator Set [24:12]
G = 8
# Demand set [24 : 17]
D = 4
# Node set
N = 6
# Sucseptance
B = 50
# hours
T = 24

#**************************************************
# MODEL
Step_2_5_a=Model(Gurobi.Optimizer)

#**************************************************

#Variables - power in MW
@variable(Step_2_5_a,pg[t=1:T, g=1:G] >=0)      #Hourly power generation - Conventional generator g (MW)
@variable(Step_2_5_a,pd[t=1:T, d=1:D] >=0)      #Hourly power demand (MW)
@variable(Step_2_5_a,theta[t=1:T, n=1:N])      #Voltage angle of node n at time t

#**************************************************

#Objective function
@objective(Step_2_5_a, Max,
sum(demand_bid_24[t,d] * pd[t, d] for t=1:T, d=1:D)                 #Total offer value 
-sum(gen_cost[g] * pg[t,g] for t=1:T, g=1:G)                #Total value of generator production       
)

# Capacity constraints
@constraint(Step_2_5_a,[t=1:T, d=1:D], 0 <= pd[t,d] <= demand_cons_24[t,d] )               # Capacity for demand (MW)
@constraint(Step_2_5_a, [t=1:T, g=1:G], 0 <= pg[t,g] <= gen_cap_24[t,g] )                   # Capacity for generator (MW)

# Ramping constraints
@constraint(Step_2_5_a, [t=2:T, g=1:4], -ramping[g] <= pg[t,g] - pg[t-1,g] <= ramping[g])                # Ramping limits for producer S
@constraint(Step_2_5_a, [t=2:T, g=6:8], -ramping[g] <= pg[t,g] - pg[t-1,g] <= ramping[g])                # Ramping limits for producer O

# Transmission capacity constraint
for t=1:T
    for n=1:N
        for m=1:N   
            if transm_capacity[n,m] != 0
                @constraint(Step_2_5_a,
                -transm_capacity[n,m] <= B * (theta[t,n] - theta[t,m]) <= transm_capacity[n,m])
            end 
        end
    end
end

# Reference constraintnode
@constraint(Step_2_5_a, [t=1:T], theta[t,1] == 0)

# Elasticity constraint, balancing supply and demand
@constraint(Step_2_5_a, powerbalance[t=1:T, n=1:N],
                0 == sum(pd[t,d] for d in node_dem[n]) + # Demand
                sum(B * (theta[t,n] - theta[t,m]) for m in connected_nodes(n)[2]) - # Ingoing transmission lines
                sum(B * (theta[t,m] - theta[t,n]) for m in connected_nodes(n)[1]) - # Outgoing transmission lines
                sum(pg[t,g] for g in node_gen[n]) # Conventional generator production
                )


#************************************************************************
# Solve
solution = optimize!(Step_2_5_a)
end
#**************************************************

# Constructing outputs:
market_price = zeros(T)

#Check if optimal solution was found
if termination_status(Step_2_5_a) == MOI.OPTIMAL
    println("Optimal solution found - Step 2.5.a")

    # Print objective value
    println("Objective value: ", objective_value(Step_2_5_a))

    
    # Print hourly market price in each node
    println("Hourly Market clearing price step 2_5_a")
    market_price = dual.(powerbalance[:,1])
    for t=1:T
        println("hour $t: ", market_price[t])
    end
    
else 
    println("No optimal solution found")
end