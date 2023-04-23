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
S = 200 # Number of scenarios
prob = 1/S # Probability of each scenario
Pmax = 150 # Maximum power output of the wind turbine

exp_prof = []

for i = 1:50

    # Generate a random permutation of column indices
    col1 = randperm(size(scenario, 1))
    col2 = randperm(size(scenario, 2))
    col3 = randperm(size(scenario, 3))
    # Reorder the columns of the matrix using the permutation
    new_scenario = scenario[col1,col2, col3]
    new_seen_scenarios = new_scenario[:,:,1:200]

    println(size(scenario))
    println(size(new_scenario))
    println(size(new_seen_scenarios))


    #----------------------------- Model -----------------------------#

    # Create Model
    Step_1_2 = Model(Gurobi.Optimizer)

    # Define variables
    @variables Step_1_2 begin
        p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
        imbalance[t=1:T, s=1:S] # Imbalance between day-ahead and real-time power production
        balance_up[t=1:T, s=1:S] >= 0 # Upward balance
        balance_down[t=1:T, s=1:S] >= 0 # Downward balance
    end

    # Define objective function
    @objective(Step_1_2, Max,
                sum(sum(prob .* 
                (new_seen_scenarios[t, 1, s] * p_DA[t] 
                + 0.9 * new_seen_scenarios[t, 1, s] * balance_up[t, s] * new_seen_scenarios[t, 3, s]
                + 1 * new_seen_scenarios[t, 1, s] * balance_up[t, s] * (1-new_seen_scenarios[t, 3, s])
                - 1 * new_seen_scenarios[t, 1, s] * balance_down[t, s] * new_seen_scenarios[t, 3, s]
                - 1.2 * new_seen_scenarios[t, 1, s] * balance_down[t, s] * (1-new_seen_scenarios[t, 3, s])
                for s = 1:S) for t = 1:T)))

    # Define constraints
    @constraint(Step_1_2, [t=1:T], p_DA[t] <= Pmax)

    @constraint(Step_1_2, [t=1:T, s=1:S], 
                imbalance[t, s] == new_seen_scenarios[t, 2, s] - p_DA[t])

    @constraint(Step_1_2, [t=1:T, s=1:S],
                imbalance[t, s] == balance_up[t, s] - balance_down[t, s])

    # Solve model
    optimize!(Step_1_2)

    #----------------------------- Results -----------------------------#

    if termination_status(Step_1_2) == MOI.OPTIMAL
        println("Optimal solution found")

        # Expected profit
        exp_profit_1_2 = objective_value(Step_1_2)
        append!(exp_prof,exp_profit_1_2)

        # Optimal power production in the day-ahead market
        p_DA_opt_1_2 = zeros(T)
        p_DA_opt_1_2 = value.(p_DA[:])

        # expected profit from each scenario
        exp_profit_scenarios_1_2 = zeros(S)
        for s = 1:S
            exp_profit_scenarios_1_2[s] = sum(prob .* 
            (new_seen_scenarios[t, 1, s] * p_DA_opt_1_2[t] 
            + 0.9 * new_seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * new_seen_scenarios[t, 3, s]
            + 1 * new_seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * (1-new_seen_scenarios[t, 3, s])
            - 1 * new_seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * new_seen_scenarios[t, 3, s]
            - 1.2 * new_seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * (1-new_seen_scenarios[t, 3, s])
            for t = 1:T))
        end
        #println("Expected profit in the scenarios: ", sum(exp_profit_scenarios_1_2))


        # expected profit in the balancing market
        profit_bal_1_2 = zeros(S)
        for s = 1:S
            profit_bal_1_2[s] = sum(prob .* 
            (0.9 * new_seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * new_seen_scenarios[t, 3, s]
            + 1 * new_seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * (1-new_seen_scenarios[t, 3, s])
            - 1 * new_seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * new_seen_scenarios[t, 3, s]
            - 1.3 * new_seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * (1-new_seen_scenarios[t, 3, s])
            for t = 1:T))
        end
        #println("Expected profit in the BAL stage: ", sum(profit_bal_1_2))


        # profit from day ahead market
        profit_DA_1_2 = zeros(S)
        for s = 1:S
            profit_DA_1_2[s] = sum(prob * (new_seen_scenarios[t, 1, s] * p_DA_opt_1_2[t]) for t = 1:T)
        end
        #println("Expected profit in the DA stage:  ", sum(profit_DA_1_2))

        #println("DA + BAL = ", sum(profit_DA_1_2)+sum(profit_bal_1_2))
        #println("DA [%] = ", (sum(profit_DA_1_2)*100)/exp_profit_1_2)
        #println("BAL [%] = ", (sum(profit_bal_1_2)*100)/exp_profit_1_2)
    else
        println("No optimal solution found")
    end

    #=
    In 2-price scheme, the wind farm does not have the same incentive to bid lower in the day-ahead-market
    to get a higher profit in the balancing market.
    So here we see a lower expected profit than the 1-price scheme.
    And we see a more precise day-ahead bidding based.
    =#
end


println("Expected profit ",exp_prof)
println(size(exp_prof))
println("Mean expected profit ",mean(exp_prof))