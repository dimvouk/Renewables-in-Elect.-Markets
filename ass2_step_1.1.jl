# Import libraries
using JuMP
using Gurobi
using Printf
using Random, Distributions 

# ----------------------------- Input data -----------------------------#

# Import scenarios
Random.seed!(1234)
include("Scenario generation.jl")

# Define parameters
T = 24 # Number of time periods
S = 200 # Number of scenarios
prob = 1/S # Probability of each scenario
Pmax = 150 # Maximum power output of the wind turbine

# Define balancing price for each hour in each scenario
balancing_price = zeros(S, T)
for s = 1:S
    for t = 1:T
        if seen_scenarios[t, 3, s] == 1
            balancing_price[s, t] = 0.9 * seen_scenarios[t, 1, s]
        else
            balancing_price[s, t] = 1.2 * seen_scenarios[t, 1, s]
        end
    end
end

#----------------------------- Model -----------------------------#

# Create Model
Step_1_1 = Model(Gurobi.Optimizer)

# Define variables
@variables Step_1_1 begin
    p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
    imbalance[t=1:T, s=1:S] # Imbalance between day-ahead and real-time power production
    balance_up[t=1:T, s=1:S] >= 0 # Upward balance
    balance_down[t=1:T, s=1:S] >= 0 # Downward balance
end

# Define objective function
@objective(Step_1_1, Max,
            sum(sum(prob * 
            (seen_scenarios[t, 1, s] * p_DA[t] 
            + balancing_price[s, t] * balance_up[t, s]
            - balancing_price[s, t] * balance_down[t, s])
            for s = 1:S) for t = 1:T))

# Define constraints
@constraint(Step_1_1, [t=1:T], p_DA[t] <= Pmax)

@constraint(Step_1_1, [t=1:T, s=1:S], 
            imbalance[t, s] == seen_scenarios[t, 2, s] - p_DA[t])

@constraint(Step_1_1, [t=1:T, s=1:S],
            imbalance[t, s] == balance_up[t, s] - balance_down[t, s])

# Solve model
optimize!(Step_1_1)

#----------------------------- Results -----------------------------#

if termination_status(Step_1_1) == MOI.OPTIMAL
    println("Optimal solution found")

    # Expected profit
    exp_profit_1_1 = objective_value(Step_1_1)
    println("Expected profit ", exp_profit_1_1)

    # Optimal power production in the day-ahead market
    p_DA_opt_1_1 = zeros(T)
    p_DA_opt_1_1 = value.(p_DA[:])

    # profit from day ahead market
    profit_DA_1_1 = zeros(S)
    for s = 1:S
        profit_DA_1_1[s] = sum(prob * (seen_scenarios[t, 1, s] * p_DA_opt_1_1[t]) for t = 1:T)
    end
    

    # expected profit in the balancing market
    profit_bal_1_1 = zeros(S)
    for s = 1:S
        profit_bal_1_1[s] = sum(prob * 
        (balancing_price[s, t] * value.(balance_up[t, s])
        - balancing_price[s, t] * value.(balance_down[t, s]))
        for t = 1:T)
    end

    # expected profit from each scenario
    profit_scen_1_1 = zeros(S)
    for s = 1:S
        profit_scen_1_1[s] = profit_DA_1_1[s] + profit_bal_1_1[s]
    end

else
    println("No optimal solution found")
end

#=
So conclusion is:
The optimal production is either 0 or 150, so the minimum or maximum.
It is 150 when it is more profitable to do downward balancing, so when system is also in deficit.
And it is 0 when it is more profitable to do upward balancing, so when system is in excess.
In the one-price scheme, the wind farm always tries to maximize its profit from playing the balancing market.
Does this make sence?
=#