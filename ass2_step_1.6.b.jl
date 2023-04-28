"""
Sensitivity analysis 
- step 1.2 
- 2-price scheme 
- 200 in sample scenarios
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
include("Scenario generation.jl")

# Define parameters
T = 24 # Number of time periods

S_in = 200 # Number of scenarios for in sample
S_out = 400 # Number of scenarios for out of sample

prob_in = 1/S_in # Probability of each scenario
prob_out = 1/S_out # Probability of each scenario

Pmax = 150 # Maximum power output of the wind turbine

iteration = 50

exp_profit_1_6b_in = zeros(iteration)
exp_prof_1_6b_out = zeros(iteration)

for i = 1:iteration

    # Generate a random permutation of column indices
    col1 = randperm(size(scenario, 1))
    col2 = [1,2,3]
    col3 = randperm(size(scenario, 3))

    # Reorder the columns of the matrix using the permutation
    new_scenario = scenario[col1,col2, col3]

    # Define new scenarios
    new_seen_scenarios = new_scenario[:,:,1:200]
    new_unseen_scenarios = new_scenario[:,:,201:600]

    println(size(scenario))
    println(size(new_scenario))
    println(size(new_seen_scenarios))
    println(size(new_unseen_scenarios))


    #----------------------------- IN SAMPLE -----------------------------#
    #---------------------------------------------------------------------#
    #----------------------------- Model -----------------------------#

    # Create Model
    Step_1_6b_in = Model(Gurobi.Optimizer)

    # Define variables
    @variables Step_1_6b_in begin
        p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
        imbalance[t=1:T, s=1:S_in] # Imbalance between day-ahead and real-time power production
        balance_up[t=1:T, s=1:S_in] >= 0 # Upward balance
        balance_down[t=1:T, s=1:S_in] >= 0 # Downward balance
    end

    # Define objective function
    @objective(Step_1_6b_in, Max,
                sum(sum(prob_in .* 
                (new_seen_scenarios[t, 1, s] * p_DA[t] 
                + 0.9 * new_seen_scenarios[t, 1, s] * balance_up[t, s] * new_seen_scenarios[t, 3, s]
                + 1 * new_seen_scenarios[t, 1, s] * balance_up[t, s] * (1-new_seen_scenarios[t, 3, s])
                - 1 * new_seen_scenarios[t, 1, s] * balance_down[t, s] * new_seen_scenarios[t, 3, s]
                - 1.2 * new_seen_scenarios[t, 1, s] * balance_down[t, s] * (1-new_seen_scenarios[t, 3, s])
                for s = 1:S_in) for t = 1:T)))

    # Define constraints
    @constraint(Step_1_6b_in, [t=1:T], p_DA[t] <= Pmax)

    @constraint(Step_1_6b_in, [t=1:T, s=1:S_in], 
                imbalance[t, s] == new_seen_scenarios[t, 2, s] - p_DA[t])

    @constraint(Step_1_6b_in, [t=1:T, s=1:S_in],
                imbalance[t, s] == balance_up[t, s] - balance_down[t, s])

    # Solve model
    optimize!(Step_1_6b_in)

    #----------------------------- Results -----------------------------#

    if termination_status(Step_1_6b_in) == MOI.OPTIMAL
        println("Optimal solution found for in sample")

        # Expected profit
        exp_profit_1_6b_in[i] = objective_value(Step_1_6b_in)
        

        # Optimal power production in the day-ahead market
        p_DA_opt_1_6b_in = zeros(T)
        p_DA_opt_1_6b_in = value.(p_DA[:])

        # expected profit from each scenario
        exp_profit_scenarios_1_6b_in = zeros(S_in)
        for s = 1:S_in
            exp_profit_scenarios_1_6b_in[s] = sum(prob_in .* 
            (new_seen_scenarios[t, 1, s] * p_DA_opt_1_6b_in[t] 
            + 0.9 * new_seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * new_seen_scenarios[t, 3, s]
            + 1 * new_seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * (1-new_seen_scenarios[t, 3, s])
            - 1 * new_seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * new_seen_scenarios[t, 3, s]
            - 1.2 * new_seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * (1-new_seen_scenarios[t, 3, s])
            for t = 1:T))
        end


        # expected profit in the balancing market
        profit_bal_1_6b_in = zeros(S_in)
        for s = 1:S_in
            profit_bal_1_6b_in[s] = sum(prob_in .* 
            (0.9 * new_seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * new_seen_scenarios[t, 3, s]
            + 1 * new_seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * (1-new_seen_scenarios[t, 3, s])
            - 1 * new_seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * new_seen_scenarios[t, 3, s]
            - 1.3 * new_seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * (1-new_seen_scenarios[t, 3, s])
            for t = 1:T))
        end


        # profit from day ahead market
        profit_DA_1_6b_in = zeros(S_in)
        for s = 1:S_in
            profit_DA_1_6b_in[s] = sum(prob_in * (new_seen_scenarios[t, 1, s] * p_DA_opt_1_6b_in[t]) for t = 1:T)
        end
    else
        println("No optimal solution found for in sample")
    end










    #----------------------------- OUT OF SAMPLE -----------------------------#
    #-------------------------------------------------------------------------#
    #----------------------------- Model -----------------------------#

    # Create Model
    Step_1_6b_out = Model(Gurobi.Optimizer)

    # Define variables
    @variables Step_1_6b_out begin
        p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
        imbalance[t=1:T, s=1:S_out] # Imbalance between day-ahead and real-time power production
        balance_up[t=1:T, s=1:S_out] >= 0 # Upward balance
        balance_down[t=1:T, s=1:S_out] >= 0 # Downward balance
    end

    # Define objective function
    @objective(Step_1_6b_out, Max,
                sum(sum(prob_out .* 
                (new_unseen_scenarios[t, 1, s] * p_DA[t] 
                + 0.9 * new_unseen_scenarios[t, 1, s] * balance_up[t, s] * new_unseen_scenarios[t, 3, s]
                + 1 * new_unseen_scenarios[t, 1, s] * balance_up[t, s] * (1-new_unseen_scenarios[t, 3, s])
                - 1 * new_unseen_scenarios[t, 1, s] * balance_down[t, s] * new_unseen_scenarios[t, 3, s]
                - 1.3 * new_unseen_scenarios[t, 1, s] * balance_down[t, s] * (1-new_unseen_scenarios[t, 3, s])
                for s = 1:S_out) for t = 1:T)))

    # Define constraints
    @constraint(Step_1_6b_out, [t=1:T], p_DA[t] <= Pmax)

    @constraint(Step_1_6b_out, [t=1:T, s=1:S_out], 
                imbalance[t, s] == new_unseen_scenarios[t, 2, s] - p_DA[t])

    @constraint(Step_1_6b_out, [t=1:T, s=1:S_out],
                imbalance[t, s] == balance_up[t, s] - balance_down[t, s])

    # Solve model
    optimize!(Step_1_6b_out)

    #----------------------------- Results -----------------------------#

    if termination_status(Step_1_6b_out) == MOI.OPTIMAL
        println("Optimal solution found for out of sample")

        # Expected profit
        exp_prof_1_6b_out[i] = objective_value(Step_1_6b_out)

        # Optimal power production in the day-ahead market
        p_DA_opt_1_6b_out = zeros(T)
        p_DA_opt_1_6b_out = value.(p_DA[:])

        # expected profit from each scenario
        exp_profit_scenarios_1_6b_out = zeros(S_out)
        for s = 1:S_out
            exp_profit_scenarios_1_6b_out[s] = sum(prob_out .* 
            (new_unseen_scenarios[t, 1, s] * p_DA_opt_1_6b_out[t] 
            + 0.9 * new_unseen_scenarios[t, 1, s] * value.(balance_up[t, s]) * new_unseen_scenarios[t, 3, s]
            + 1 * new_unseen_scenarios[t, 1, s] * value.(balance_up[t, s]) * (1-new_unseen_scenarios[t, 3, s])
            - 1 * new_unseen_scenarios[t, 1, s] * value.(balance_down[t, s]) * new_unseen_scenarios[t, 3, s]
            - 1.2 * new_unseen_scenarios[t, 1, s] * value.(balance_down[t, s]) * (1-new_unseen_scenarios[t, 3, s])
            for t = 1:T))
        end


        # expected profit in the balancing market
        profit_bal_1_6b_out = zeros(S_out)
        for s = 1:S_out
            profit_bal_1_6b_out[s] = sum(prob_out .* 
            (0.9 * new_unseen_scenarios[t, 1, s] * value.(balance_up[t, s]) * new_unseen_scenarios[t, 3, s]
            + 1 * new_unseen_scenarios[t, 1, s] * value.(balance_up[t, s]) * (1-new_unseen_scenarios[t, 3, s])
            - 1 * new_unseen_scenarios[t, 1, s] * value.(balance_down[t, s]) * new_unseen_scenarios[t, 3, s]
            - 1.3 * new_unseen_scenarios[t, 1, s] * value.(balance_down[t, s]) * (1-new_unseen_scenarios[t, 3, s])
            for t = 1:T))
        end


        # profit from day ahead market
        profit_DA_1_6b_out = zeros(S_out)
        for s = 1:S_out
            profit_DA_1_6b_out[s] = sum(prob_out * (new_unseen_scenarios[t, 1, s] * p_DA_opt_1_6b_out[t]) for t = 1:T)
        end

    else
        println("No optimal solution found for out of sample")
    end
end


println("Expected profit for in sample ",exp_profit_1_6b_in)
println("Expected profit for out of sample ",exp_prof_1_6b_out)

println(size(exp_profit_1_6b_in))
println(size(exp_prof_1_6b_out))

println("Mean expected profit for in sample ",mean(exp_profit_1_6b_in))
println("Mean expected profit for out of sample ",mean(exp_prof_1_6b_out))