"""
Sensitivity analysis 
- step 1.1 
- 1-price scheme 
- 200 in sample scenarios
- no CVaR
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
include("Scenario generation.jl")

# Define parameters
T = 24 # Number of time periods
S_in = [150,200,250,300,350] # Number of scenarios for in sample 
Pmax = 150 # Maximum power output of the wind turbine

for scen in S_in
    
    prob_in = 1/scen # Probability of each scenario
    seen_scenarios = scenario[:, :, 1:scen]

    println(size(scenario))
    println(size(seen_scenarios))

    #----------------------------- IN SAMPLE -----------------------------#
    #---------------------------------------------------------------------#
    # Define balancing price for each hour in each scenario
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

    #----------------------------- Model -----------------------------#

    # Create Model
    Step_1_6_2_a_in = Model(Gurobi.Optimizer)

    # Define variables
    @variables Step_1_6_2_a_in begin
        p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
        imbalance[t=1:T, s=1:scen] # Imbalance between day-ahead and real-time power production
        balance_up[t=1:T, s=1:scen] >= 0 # Upward balance
        balance_down[t=1:T, s=1:scen] >= 0 # Downward balance
    end

    # Define objective function
    @objective(Step_1_6_2_a_in, Max,
                sum(sum(prob_in * 
                (seen_scenarios[t, 1, s] * p_DA[t] 
                + balancing_price[s, t] * balance_up[t, s]
                - balancing_price[s, t] * balance_down[t, s])
                for s = 1:scen) for t = 1:T))

    # Define constraints
    @constraint(Step_1_6_2_a_in, [t=1:T], p_DA[t] <= Pmax)

    @constraint(Step_1_6_2_a_in, [t=1:T, s=1:scen], 
                imbalance[t, s] == seen_scenarios[t, 2, s] - p_DA[t])

    @constraint(Step_1_6_2_a_in, [t=1:T, s=1:scen],
                imbalance[t, s] == balance_up[t, s] - balance_down[t, s])

    # Solve model
    optimize!(Step_1_6_2_a_in)

    #----------------------------- Results -----------------------------#

    if termination_status(Step_1_6_2_a_in) == MOI.OPTIMAL
        println("Optimal solution found for in sample")

        # Expected profit
        exp_prof_1_6_2_a_in = objective_value(Step_1_6_2_a_in)

        # Optimal power production in the day-ahead market
        p_DA_opt_1_6_2_a_in = zeros(T)
        p_DA_opt_1_6_2_a_in = value.(p_DA[:])

        # profit from day ahead market
        profit_DA_1_6_2_a_in = zeros(scen)
        for s = 1:scen
            profit_DA_1_6_2_a_in[s] = sum(prob_in * (seen_scenarios[t, 1, s] * p_DA_opt_1_6_2_a_in[t]) for t = 1:T)
        end
        #println("Expected profit from DA market: ",sum(profit_DA_1_1))
        

        # expected profit in the balancing market
        profit_bal_1_6_2_a_in = zeros(scen)
        for s = 1:scen
            profit_bal_1_6_2_a_in[s] = sum(prob_in * 
            (balancing_price[s, t] * value.(balance_up[t, s])
            - balancing_price[s, t] * value.(balance_down[t, s]))
            for t = 1:T)
        end

        # expected profit from each scenario
        3
        profit_scen_1_6_2_a_in = zeros(scen)
        for s = 1:scen
            profit_scen_1_6_2_a_in[s] = profit_DA_1_6_2_a_in[s] + profit_bal_1_6_2_a_in[s]
        end

    else
        println("No optimal solution found for in sample")
    end

    println("Considered scenarios: ",scen)
    println("Expected profit for in sample ",exp_prof_1_6_2_a_in)
end

