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
prob = 0.005 # Probability of each scenario
Pmax = 150 # Maximum power output of the wind turbine
beta = 0.5 # Weighting parameter, the higher the value the more risk adverse the wind producer. Risk-neutral case when 0
alpha = 0.9 # Confidence level

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
Step_1_4_1 = Model(Gurobi.Optimizer)

# Define variables
@variables Step_1_4_1 begin
    p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
    imbalance[t=1:T, s=1:S] # Imbalance between day-ahead and real-time power production
    balance_up[t=1:T, s=1:S] >= 0 # Upward balance
    balance_down[t=1:T, s=1:S] >= 0 # Downward balance
    eta[s=1:S] >=0 # Used in the CVaR: eta value for each scenario
    zeta # Used in the CVaR
end

# Define objective function
@objective(Step_1_4_1, Max,
            sum(sum(prob * 
            (seen_scenarios[t, 1, s] * p_DA[t] 
            + balancing_price[s, t] * balance_up[t, s]
            - balancing_price[s, t] * balance_down[t, s])
            for s = 1:S) for t = 1:T) 
            + beta * (zeta - (1/(1-alpha))
            * sum(prob*eta[s] for s = 1:S)))

# Define constraints
@constraint(Step_1_4_1, [t=1:T], p_DA[t] <= Pmax)

@constraint(Step_1_4_1, [t=1:T, s=1:S], 
            imbalance[t, s] == seen_scenarios[t, 2, s] - p_DA[t])

@constraint(Step_1_4_1, [t=1:T, s=1:S],
            imbalance[t, s] == balance_up[t, s] - balance_down[t, s])
            
@constraint(Step_1_4_1, [s=1:S], 
            -sum(seen_scenarios[t, 1, s] * p_DA[t] 
            + balancing_price[s, t] * balance_up[t, s]
            - balancing_price[s, t] * balance_down[t, s] for t = 1:T) + zeta - eta[s] <= 0)

# Solve model
optimize!(Step_1_4_1)

#----------------------------- Results -----------------------------#

if termination_status(Step_1_4_1) == MOI.OPTIMAL
    println("Optimal solution found")

    # Expected profit
    exp_profit_1_4_1 = objective_value(Step_1_4_1)
    println("Expected profit ", exp_profit_1_4_1)

    # CVaR value
    CVaR = (value.(zeta) - 1/(1-alpha) * sum(prob*value.(eta[s]) for s = 1:S))
    println("CVaR value ", CVaR)
    # Optimal power production in the day-ahead market
    p_DA_opt_1_4_1 = zeros(T)
    p_DA_opt_1_4_1 = value.(p_DA[:])

    # expected profit from each scenario
    exp_profit_scenarios_1_4_1 = zeros(S)
    for s = 1:S
        exp_profit_scenarios_1_4_1[s] = sum(prob * 
        (seen_scenarios[t, 1, s] * p_DA_opt_1_4_1[t] 
        + balancing_price[s, t] * value.(balance_up[t, s])
        - balancing_price[s, t] * value.(balance_down[t, s]))
        for t = 1:T)
    end

else
    println("No optimal solution found")
end

#=
So conclusion is:
Interpreting CVaR in a risk-averse offering strategy problem involves understanding 
the confidence level or threshold chosen and the potential loss beyond that level. 
The CVaR at a 90% confidence level is $101,209, it means that there is a 10% chance of
incurring a loss greater than $101,209.
With Beta = 0.5, the expected profit will be 50%*CVaR higher than the risk-neutral case.
=#