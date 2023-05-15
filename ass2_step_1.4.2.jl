# Import libraries
using JuMP
using Gurobi
using Printf
using Random, Distributions 
@time begin
# ----------------------------- Input data -----------------------------#

# Import scenarios
Random.seed!(1234)
include("ass2_Step_1_Scenario_generation.jl")

# Define parameters
T = 24 # Number of time periods
S = 200 # Number of scenarios
prob = 1/S # Probability of each scenario
Pmax = 150 # Maximum power output of the wind turbine
beta = [0, 0.25, 0.5, 0.75, 1] # Weighting parameter, the higher the value the more risk adverse the wind producer. Risk-neutral case when 0
alpha = [0.8, 0.9, 0.95] # Confidence level
B = length(beta) # Number of beta values
A = length(alpha) # Number of alpha values

# empty lists for storing results
CVaR_1_4_2 = zeros(A, B)
exp_profit_1_4_2 = zeros(A, B)
p_DA_1_4_2 = zeros(T, A, B)

#----------------------------- Model -----------------------------#

# Loop over all values of beta and alpha
for a = 1:A
    for b=1:B

        # Create Model
        Step_1_4_2 = Model(Gurobi.Optimizer)

        # Define variables
        @variables Step_1_4_2 begin
            p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
            imbalance[t=1:T, s=1:S] # Imbalance between day-ahead and real-time power production
            balance_up[t=1:T, s=1:S] >= 0 # Upward balance
            balance_down[t=1:T, s=1:S] >= 0 # Downward balance
            eta[s=1:S] >= 0 # Used in the CVaR: eta value for each scenario
            zeta # Used in the CVaR
        end

        # Define objective function
        @objective(Step_1_4_2, Max,
                    sum(sum((1-beta[b])*prob .* 
                    (seen_scenarios[t, 1, s] * p_DA[t] 
                    + 0.9 * seen_scenarios[t, 1, s] * balance_up[t, s] * seen_scenarios[t, 3, s]
                    + 1 * seen_scenarios[t, 1, s] * balance_up[t, s] * (1-seen_scenarios[t, 3, s])
                    - 1 * seen_scenarios[t, 1, s] * balance_down[t, s] * seen_scenarios[t, 3, s]
                    - 1.2 * seen_scenarios[t, 1, s] * balance_down[t, s] * (1-seen_scenarios[t, 3, s])
                    for s = 1:S) for t = 1:T))
                    + beta[b] * (zeta - (1/(1-alpha[a]))
                    * sum(prob*eta[s] for s = 1:S))
                    )

        # Define constraints
        @constraint(Step_1_4_2, [t=1:T], p_DA[t] <= Pmax)

        @constraint(Step_1_4_2, [t=1:T, s=1:S], 
                    imbalance[t, s] == seen_scenarios[t, 2, s] - p_DA[t])

        @constraint(Step_1_4_2, [t=1:T, s=1:S],
                    imbalance[t, s] == balance_up[t, s] - balance_down[t, s])

        @constraint(Step_1_4_2, [s=1:S], 
        - sum(seen_scenarios[t, 1, s] * p_DA[t] 
        + 0.9 * seen_scenarios[t, 1, s] * balance_up[t, s] * seen_scenarios[t, 3, s]
        + 1 * seen_scenarios[t, 1, s] * balance_up[t, s] * (1-seen_scenarios[t, 3, s])
        - 1 * seen_scenarios[t, 1, s] * balance_down[t, s] * seen_scenarios[t, 3, s]
        - 1.2 * seen_scenarios[t, 1, s] * balance_down[t, s] * (1-seen_scenarios[t, 3, s])
        for t = 1:T) + zeta - eta[s] <= 0)

        # Solve model
        optimize!(Step_1_4_2)

    #----------------------------- Results -----------------------------#

        CVaR_1_4_2[a, b] = (value.(zeta) - 1/(1-alpha[a]) * sum(prob*value.(eta[s]) for s = 1:S))

        # expected profit
        exp_profit_1_4_2[a, b] = sum(sum(prob .* 
        (seen_scenarios[t, 1, s] * value.(p_DA[t]) 
        + 0.9 * seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * seen_scenarios[t, 3, s]
        + 1 * seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * (1-seen_scenarios[t, 3, s])
        - 1 * seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * seen_scenarios[t, 3, s]
        - 1.2 * seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * (1-seen_scenarios[t, 3, s])
        for s = 1:S) for t = 1:T))

        # day-ahead power production
        p_DA_1_4_2[:, a, b] = value.(p_DA[:])
        
    end # end of beta loop
end # end of alpha loop
end 
println("Expected profit: ", mean(exp_profit_1_4_2))
