"""
Sensitivity analysis 
- step 1.4.1 
- 1-price scheme 
- 200 in sample scenarios
- yes CVaR
- iterate between 150:50:300 scenarios
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

S_in = [150,200,250,300,350] # Number of scenarios
Pmax = 150 # Maximum power output of the wind turbine

beta = [0, 0.25, 0.5, 0.75, 1] # Weighting parameter, the higher the value the more risk adverse the wind producer. Risk-neutral case when 0
alpha = [0.8, 0.9, 0.95] # Confidence level
B = length(beta) # Number of beta values
A = length(alpha) # Number of alpha values

# empty lists for storing results - in sample
CVaR_1_6_2_c_in = zeros(A, B)
exp_profit_1_6_2_c_in = zeros(A, B)
p_DA_1_6_2_c_in = zeros(T, A, B)

save_scen = []
save_exp_profit_1_6_2_c_in = []

# ----------------------------- Shuffling vector -----------------------------#
for scen in S_in

    prob_in = 1/scen # Probability of each scenario
    seen_scenarios = scenario[:,:,1:scen]

    println(size(scenario))
    println(size(seen_scenarios))

    # Define balancing price for each hour in each scenario - in sample
    balancing_price = zeros(scen, T)
    for s = 1:scen
        for t = 1:T
            if seen_scenarios[t, 3, s] == 1
                balancing_price[s, t] = 0.9 * seen_scenarios[t, 1, s]
            else
                balancing_price[s, t] = 1.2 * seen_scenarios[t, 1, s]
            end
        end
    end

    # Loop over all values of beta and alpha
    for a = 1:A
        for b=1:B
            #----------------------------- IN SAMPLE -----------------------------#
            #---------------------------------------------------------------------#
            #----------------------------- Model -----------------------------#

            # Create Model
            Step_1_6_2_c_in = Model(Gurobi.Optimizer)

            # Define variables
            @variables Step_1_6_2_c_in begin
            p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
            imbalance[t=1:T, s=1:scen] # Imbalance between day-ahead and real-time power production
            balance_up[t=1:T, s=1:scen] >= 0 # Upward balance
            balance_down[t=1:T, s=1:scen] >= 0 # Downward balance
            eta[s=1:scen] >= 0 # Used in the CVaR: eta value for each scenario
            zeta # Used in the CVaR
            end

            # Define objective function
            @objective(Step_1_6_2_c_in, Max,
                        sum(sum((1-beta[b])*(prob_in * 
                        (seen_scenarios[t, 1, s] * p_DA[t] 
                        + balancing_price[s, t] * balance_up[t, s]
                        - balancing_price[s, t] * balance_down[t, s]))
                        for s = 1:scen for t = 1:T)) 
                        + beta[b] * (zeta - (1/(1-alpha[a]))
                        * sum(prob_in*eta[s] for s = 1:scen))
                        )

            # Define constraints
            @constraint(Step_1_6_2_c_in, [t=1:T], p_DA[t] <= Pmax)

            @constraint(Step_1_6_2_c_in, [t=1:T, s=1:scen], 
                        imbalance[t, s] == seen_scenarios[t, 2, s] - p_DA[t])

            @constraint(Step_1_6_2_c_in, [t=1:T, s=1:scen],
                        imbalance[t, s] == balance_up[t, s] - balance_down[t, s])
                        
            @constraint(Step_1_6_2_c_in, [s=1:scen], 
                        - sum(seen_scenarios[t, 1, s] * p_DA[t] 
                        + balancing_price[s, t] * balance_up[t, s]
                        - balancing_price[s, t] * balance_down[t, s] for t = 1:T) + zeta - eta[s] <= 0)

            # Solve model
            optimize!(Step_1_6_2_c_in)

            #---------------------------- Results -----------------------------#
            
            # CVaR
            CVaR_1_6_2_c_in[a, b] = (value.(zeta) - 1/(1-alpha[a]) * sum(prob_in*value.(eta[s]) for s = 1:scen))

            # expected profit
            exp_profit_1_6_2_c_in[a, b] = sum(sum(prob_in *
            (seen_scenarios[t, 1, s] * value.(p_DA[t])
            + balancing_price[s, t] * value.(balance_up[t, s])
            - balancing_price[s, t] * value.(balance_down[t, s]))
            for t = 1:T, s = 1:scen))

            # day-ahead power production
            p_DA_1_6_2_c_in[:, a, b] = value.(p_DA[:])


        end # end of beta loop
    end # end of alpha loop

    push!(save_scen,scen)
    push!(save_exp_profit_1_6_2_c_in,mean(exp_profit_1_6_2_c_in))
end


println("Considered scenarios: ",save_scen)
println("Expected profit for in sample ",save_exp_profit_1_6_2_c_in)
