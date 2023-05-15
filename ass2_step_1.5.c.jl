"""
Out of sample scenarios for step 1.4.1
- 1-price scheme 
- Yes CVaR 
"""

# Import libraries
using JuMP
using Gurobi
using Printf
using Random, Distributions 

# ----------------------------- Input data -----------------------------#

# Import scenarios
Random.seed!(1234)
include("ass2_Step_1_Scenario_generation.jl")

# Define parameters
T = 24 # Number of time periods
S = 400 # Number of scenarios
prob = 1/S # Probability of each scenario
Pmax = 150 # Maximum power output of the wind turbine
beta = [0, 0.25, 0.5, 0.75, 1] # Weighting parameter, the higher the value the more risk adverse the wind producer. Risk-neutral case when 0
alpha = [0.8, 0.9, 0.95] # Confidence level
B = length(beta) # Number of beta values
A = length(alpha) # Number of alpha values

# empty lists for storing results
CVaR_1_4_1 = zeros(A, B)
exp_profit_1_4_1 = zeros(A, B)
p_DA_1_4_1 = zeros(T, A, B)

# Define balancing price for each hour in each scenario
balancing_price = zeros(S, T)
for s = 1:S
    for t = 1:T
        if unseen_scenarios[t, 3, s] == 1
            balancing_price[s, t] = 0.9 * unseen_scenarios[t, 1, s]
        else
            balancing_price[s, t] = 1.2 * unseen_scenarios[t, 1, s]
        end
    end
end

#----------------------------- Model -----------------------------#

# Loop over all values of beta and alpha
for a = 1:A
    for b=1:B

        # Create Model
        Step_1_4_1 = Model(Gurobi.Optimizer)

        # Define variables
        @variables Step_1_4_1 begin
        p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
        imbalance[t=1:T, s=1:S] # Imbalance between day-ahead and real-time power production
        balance_up[t=1:T, s=1:S] >= 0 # Upward balance
        balance_down[t=1:T, s=1:S] >= 0 # Downward balance
        eta[s=1:S] >= 0 # Used in the CVaR: eta value for each scenario
        zeta # Used in the CVaR
        end

        # Define objective function
        @objective(Step_1_4_1, Max,
                    sum(sum((1-beta[b])*(prob * 
                    (unseen_scenarios[t, 1, s] * p_DA[t] 
                    + balancing_price[s, t] * balance_up[t, s]
                    - balancing_price[s, t] * balance_down[t, s]))
                    for s = 1:S for t = 1:T)) 
                    + beta[b] * (zeta - (1/(1-alpha[a]))
                    * sum(prob*eta[s] for s = 1:S))
                    )

        # Define constraints
        @constraint(Step_1_4_1, [t=1:T], p_DA[t] <= Pmax)

        @constraint(Step_1_4_1, [t=1:T, s=1:S], 
                    imbalance[t, s] == unseen_scenarios[t, 2, s] - p_DA[t])

        @constraint(Step_1_4_1, [t=1:T, s=1:S],
                    imbalance[t, s] == balance_up[t, s] - balance_down[t, s])
                    
        @constraint(Step_1_4_1, [s=1:S], 
                    - sum(unseen_scenarios[t, 1, s] * p_DA[t] 
                    + balancing_price[s, t] * balance_up[t, s]
                    - balancing_price[s, t] * balance_down[t, s] for t = 1:T) + zeta - eta[s] <= 0)

        # Solve model
        optimize!(Step_1_4_1)

    #----------------------------- Results -----------------------------#
        
        # CVaR
        CVaR_1_4_1[a, b] = (value.(zeta) - 1/(1-alpha[a]) * sum(prob*value.(eta[s]) for s = 1:S))

        # expected profit
        exp_profit_1_4_1[a, b] = sum(sum(prob *
        (unseen_scenarios[t, 1, s] * value.(p_DA[t])
        + balancing_price[s, t] * value.(balance_up[t, s])
        - balancing_price[s, t] * value.(balance_down[t, s]))
        for t = 1:T, s = 1:S))

        # day-ahead power production
        p_DA_1_4_1[:, a, b] = value.(p_DA[:])

    end # end of beta loop
end # end of alpha loop

println("Expected profit: ", mean(exp_profit_1_4_1))
