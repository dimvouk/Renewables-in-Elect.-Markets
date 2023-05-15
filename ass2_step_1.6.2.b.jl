"""
Sensitivity analysis 
- step 1.2 
- 2-price scheme 
- 200 in sample scenarios
- 400 out of sample scenarios
- no CVaR
"""

# Import libraries
using JuMP
using Gurobi
using Printf
using Random, Distributions 
using Random

# ----------------------------- Input data -----------------------------#

# Import scenarios
Random.seed!(1234)
include("ass2_Step_1_Scenario_generation.jl")

# Define parameters
T = 24 # Number of time periods
S_in = [150,200,250,300,350] # Number of scenarios for in sample

Pmax = 150 # Maximum power output of the wind turbine

for scen in S_in

    prob_in = 1/scen

    seen_scenarios = scenario[:, :, 1:scen]

    println(size(scenario))
    println(size(seen_scenarios))


    #----------------------------- IN SAMPLE -----------------------------#
    #---------------------------------------------------------------------#
    #----------------------------- Model -----------------------------#

    # Create Model
    Step_1_6_2_b_in = Model(Gurobi.Optimizer)

    # Define variables
    @variables Step_1_6_2_b_in begin
        p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
        imbalance[t=1:T, s=1:scen] # Imbalance between day-ahead and real-time power production
        balance_up[t=1:T, s=1:scen] >= 0 # Upward balance
        balance_down[t=1:T, s=1:scen] >= 0 # Downward balance
    end

    # Define objective function
    @objective(Step_1_6_2_b_in, Max,
                sum(sum(prob_in .* 
                (seen_scenarios[t, 1, s] * p_DA[t] 
                + 0.9 * seen_scenarios[t, 1, s] * balance_up[t, s] * seen_scenarios[t, 3, s]
                + 1 * seen_scenarios[t, 1, s] * balance_up[t, s] * (1-seen_scenarios[t, 3, s])
                - 1 * seen_scenarios[t, 1, s] * balance_down[t, s] * seen_scenarios[t, 3, s]
                - 1.2 * seen_scenarios[t, 1, s] * balance_down[t, s] * (1-seen_scenarios[t, 3, s])
                for s = 1:scen) for t = 1:T)))

    # Define constraints
    @constraint(Step_1_6_2_b_in, [t=1:T], p_DA[t] <= Pmax)

    @constraint(Step_1_6_2_b_in, [t=1:T, s=1:scen], 
                imbalance[t, s] == seen_scenarios[t, 2, s] - p_DA[t])

    @constraint(Step_1_6_2_b_in, [t=1:T, s=1:scen],
                imbalance[t, s] == balance_up[t, s] - balance_down[t, s])

    # Solve model
    optimize!(Step_1_6_2_b_in)

    #----------------------------- Results -----------------------------#

    if termination_status(Step_1_6_2_b_in) == MOI.OPTIMAL
        println("Optimal solution found for in sample")

        # Expected profit
        exp_profit_1_6_2_b_in = objective_value(Step_1_6_2_b_in)
        

        # Optimal power production in the day-ahead market
        p_DA_opt_1_6_2_b_in = zeros(T)
        p_DA_opt_1_6_2_b_in = value.(p_DA[:])

        # expected profit from each scenario
        exp_profit_scenarios_1_6_2_b_in = zeros(scen)
        for s = 1:scen
            exp_profit_scenarios_1_6_2_b_in[s] = sum(prob_in .* 
            (seen_scenarios[t, 1, s] * p_DA_opt_1_6_2_b_in[t] 
            + 0.9 * seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * seen_scenarios[t, 3, s]
            + 1 * seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * (1-seen_scenarios[t, 3, s])
            - 1 * seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * seen_scenarios[t, 3, s]
            - 1.2 * seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * (1-seen_scenarios[t, 3, s])
            for t = 1:T))
        end


        # expected profit in the balancing market
        profit_bal_1_6_2_b_in = zeros(scen)
        for s = 1:scen
            profit_bal_1_6_2_b_in[s] = sum(prob_in .* 
            (0.9 * seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * seen_scenarios[t, 3, s]
            + 1 * seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * (1-seen_scenarios[t, 3, s])
            - 1 * seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * seen_scenarios[t, 3, s]
            - 1.3 * seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * (1-seen_scenarios[t, 3, s])
            for t = 1:T))
        end


        # profit from day ahead market
        profit_DA_1_6_2_b_in = zeros(scen)
        for s = 1:scen
            profit_DA_1_6_2_b_in[s] = sum(prob_in * (seen_scenarios[t, 1, s] * p_DA_opt_1_6_2_b_in[t]) for t = 1:T)
        end
    else
        println("No optimal solution found for in sample")
    end

    println("Considered scenarios: ",scen)
    println("Expected profit for in sample ",exp_profit_1_6_2_b_in)
end


