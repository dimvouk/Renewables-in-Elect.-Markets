"""
Sensitivity analysis 
- step 1.4.2 and 1.5.d
- 2-price scheme 
- 200 in sample scenarios
- 400 out of sample scenario
- yes CVaR
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

S_in = 200 # Number of scenarios in sample
prob_in = 1/S_in # Probability of each scenario

S_out = 200 # Number of scenarios out of sample
prob_out = 1/S_out # Probability of each scenario

Pmax = 150 # Maximum power output of the wind turbine
beta = [0, 0.25, 0.5, 0.75, 1] # Weighting parameter, the higher the value the more risk adverse the wind producer. Risk-neutral case when 0
alpha = [0.8, 0.9, 0.95] # Confidence level
B = length(beta) # Number of beta values
A = length(alpha) # Number of alpha values

# empty lists for storing results
CVaR_1_6d_in = zeros(A, B)
exp_profit_1_6d_in = zeros(A, B)
p_DA_1_6d_in = zeros(T, A, B)

# empty lists for storing results
CVaR_1_6d_out = zeros(A, B)
exp_profit_1_6d_out = zeros(A, B)
p_DA_1_6d_out = zeros(T, A, B)

iteration = 2

# ----------------------------- Shuffling vector -----------------------------#
for i = 1:iteration

     # Generate a random permutation of column indices
    col1 = randperm(size(scenario, 1))
    col2 = [1,2,3]
    col3 = randperm(size(scenario, 3))

    # Reorder the columns of the matrix using the permutation
    new_scenario = scenario[col1,col2, col3]

    # Defining new scenarios
    new_seen_scenarios = new_scenario[:,:,1:200]
    new_unseen_scenarios = new_scenario[:,:,201:600]

    println(size(scenario))
    println(size(new_scenario))
    println(size(new_seen_scenarios))
    println(size(new_unseen_scenarios))


    # Loop over all values of beta and alpha
    for a = 1:A
        for b=1:B

            #----------------------------- IN SAMPLE -----------------------------#
            #---------------------------------------------------------------------#
            #----------------------------- Model -----------------------------#
            # Create Model
            Step_1_6d_in = Model(Gurobi.Optimizer)

            # Define variables
            @variables Step_1_6d_in begin
                p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
                imbalance[t=1:T, s=1:S_in] # Imbalance between day-ahead and real-time power production
                balance_up[t=1:T, s=1:S_in] >= 0 # Upward balance
                balance_down[t=1:T, s=1:S_in] >= 0 # Downward balance
                eta[s=1:S_in] >= 0 # Used in the CVaR: eta value for each scenario
                zeta # Used in the CVaR
            end

            # Define objective function
            @objective(Step_1_6d_in, Max,
                        sum(sum((1-beta[b])*prob_in .* 
                        (new_seen_scenarios[t, 1, s] * p_DA[t] 
                        + 0.9 * new_seen_scenarios[t, 1, s] * balance_up[t, s] * new_seen_scenarios[t, 3, s]
                        + 1 * new_seen_scenarios[t, 1, s] * balance_up[t, s] * (1-new_seen_scenarios[t, 3, s])
                        - 1 * new_seen_scenarios[t, 1, s] * balance_down[t, s] * new_seen_scenarios[t, 3, s]
                        - 1.2 * new_seen_scenarios[t, 1, s] * balance_down[t, s] * (1-new_seen_scenarios[t, 3, s])
                        for s = 1:S_in) for t = 1:T))
                        + beta[b] * (zeta - (1/(1-alpha[a]))
                        * sum(prob_in*eta[s] for s = 1:S_in))
                        )

            # Define constraints
            @constraint(Step_1_6d_in, [t=1:T], p_DA[t] <= Pmax)

            @constraint(Step_1_6d_in, [t=1:T, s=1:S_in], 
                        imbalance[t, s] == new_seen_scenarios[t, 2, s] - p_DA[t])

            @constraint(Step_1_6d_in, [t=1:T, s=1:S_in],
                        imbalance[t, s] == balance_up[t, s] - balance_down[t, s])

            @constraint(Step_1_6d_in, [s=1:S_in], 
            - sum(new_seen_scenarios[t, 1, s] * p_DA[t] 
            + 0.9 * new_seen_scenarios[t, 1, s] * balance_up[t, s] * new_seen_scenarios[t, 3, s]
            + 1 * new_seen_scenarios[t, 1, s] * balance_up[t, s] * (1-new_seen_scenarios[t, 3, s])
            - 1 * new_seen_scenarios[t, 1, s] * balance_down[t, s] * new_seen_scenarios[t, 3, s]
            - 1.2 * new_seen_scenarios[t, 1, s] * balance_down[t, s] * (1-new_seen_scenarios[t, 3, s])
            for t = 1:T) + zeta - eta[s] <= 0)

            # Solve model
            optimize!(Step_1_6d_in)

        #----------------------------- Results -----------------------------#
            if termination_status(Step_1_6d_in) == MOI.OPTIMAL
                println("Optimal solution found for in sample")
                
                CVaR_1_6d_in[a, b] = (value.(zeta) - 1/(1-alpha[a]) * sum(prob_in*value.(eta[s]) for s = 1:S_in))

                # expected profit
                exp_profit_1_6d_in[a, b] = sum(sum(prob_in .* 
                (new_seen_scenarios[t, 1, s] * value.(p_DA[t]) 
                + 0.9 * new_seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * new_seen_scenarios[t, 3, s]
                + 1 * new_seen_scenarios[t, 1, s] * value.(balance_up[t, s]) * (1-new_seen_scenarios[t, 3, s])
                - 1 * new_seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * new_seen_scenarios[t, 3, s]
                - 1.2 * new_seen_scenarios[t, 1, s] * value.(balance_down[t, s]) * (1-new_seen_scenarios[t, 3, s])
                for s = 1:S_in) for t = 1:T))


                # day-ahead power production
                p_DA_1_6d_in[:, a, b] = value.(p_DA[:])
            else
                println("No optimal solution found for in sample")
            end





            #----------------------------- OUT OF SAMPLE -----------------------------#
            #-------------------------------------------------------------------------#
            #----------------------------- Model -----------------------------#
            # Create Model
            Step_1_6d_out = Model(Gurobi.Optimizer)

            # Define variables
            @variables Step_1_6d_out begin
                p_DA[t=1:T] >= 0 # Power production of the wind turbine in the day-ahead market
                imbalance[t=1:T, s=1:S_out] # Imbalance between day-ahead and real-time power production
                balance_up[t=1:T, s=1:S_out] >= 0 # Upward balance
                balance_down[t=1:T, s=1:S_out] >= 0 # Downward balance
                eta[s=1:S_out] >= 0 # Used in the CVaR: eta value for each scenario
                zeta # Used in the CVaR
            end

            # Define objective function
            @objective(Step_1_6d_out, Max,
                        sum(sum((1-beta[b])*prob_out .* 
                        ( new_unseen_scenarios[t, 1, s] * p_DA[t] 
                        + 0.9 *  new_unseen_scenarios[t, 1, s] * balance_up[t, s] *  new_unseen_scenarios[t, 3, s]
                        + 1 *  new_unseen_scenarios[t, 1, s] * balance_up[t, s] * (1- new_unseen_scenarios[t, 3, s])
                        - 1 *  new_unseen_scenarios[t, 1, s] * balance_down[t, s] *  new_unseen_scenarios[t, 3, s]
                        - 1.2 *  new_unseen_scenarios[t, 1, s] * balance_down[t, s] * (1- new_unseen_scenarios[t, 3, s])
                        for s = 1:S_out) for t = 1:T))
                        + beta[b] * (zeta - (1/(1-alpha[a]))
                        * sum(prob_out*eta[s] for s = 1:S_out))
                        )

            # Define constraints
            @constraint(Step_1_6d_out, [t=1:T], p_DA[t] <= Pmax)

            @constraint(Step_1_6d_out, [t=1:T, s=1:S_out], 
                        imbalance[t, s] ==  new_unseen_scenarios[t, 2, s] - p_DA[t])

            @constraint(Step_1_6d_out, [t=1:T, s=1:S_out],
                        imbalance[t, s] == balance_up[t, s] - balance_down[t, s])

            @constraint(Step_1_6d_out, [s=1:S_out], 
            - sum( new_unseen_scenarios[t, 1, s] * p_DA[t] 
            + 0.9 *  new_unseen_scenarios[t, 1, s] * balance_up[t, s] *  new_unseen_scenarios[t, 3, s]
            + 1 *  new_unseen_scenarios[t, 1, s] * balance_up[t, s] * (1- new_unseen_scenarios[t, 3, s])
            - 1 *  new_unseen_scenarios[t, 1, s] * balance_down[t, s] *  new_unseen_scenarios[t, 3, s]
            - 1.2 *  new_unseen_scenarios[t, 1, s] * balance_down[t, s] * (1- new_unseen_scenarios[t, 3, s])
            for t = 1:T) + zeta - eta[s] <= 0)

            # Solve model
            optimize!(Step_1_6d_out)

            #----------------------------- Results -----------------------------#
            if termination_status(Step_1_6d_out) == MOI.OPTIMAL
                println("Optimal solution found for out of sample")
                
                CVaR_1_6d_out[a, b] = (value.(zeta) - 1/(1-alpha[a]) * sum(prob_out*value.(eta[s]) for s = 1:S_out))

                # expected profit
                exp_profit_1_6d_out[a, b] = sum(sum(prob_out .* 
                ( new_unseen_scenarios[t, 1, s] * value.(p_DA[t]) 
                + 0.9 *  new_unseen_scenarios[t, 1, s] * value.(balance_up[t, s]) *  new_unseen_scenarios[t, 3, s]
                + 1 *  new_unseen_scenarios[t, 1, s] * value.(balance_up[t, s]) * (1- new_unseen_scenarios[t, 3, s])
                - 1 *  new_unseen_scenarios[t, 1, s] * value.(balance_down[t, s]) *  new_unseen_scenarios[t, 3, s]
                - 1.2 *  new_unseen_scenarios[t, 1, s] * value.(balance_down[t, s]) * (1- new_unseen_scenarios[t, 3, s])
                for s = 1:S_out) for t = 1:T))

                # day-ahead power production
                p_DA_1_6d_out[:, a, b] = value.(p_DA[:])

            else
                println("No optimal solution found for out of sample")
            end
        end # end of beta loop
    end # end of alpha loop
end

println("Expected profit in sample: ",exp_profit_1_6d_in)
println("Expected profit out of sample: ",exp_profit_1_6d_out)

println(size(exp_profit_1_6d_in))
println(size(exp_profit_1_6d_out))

println("Mean expected profit in sample: ",mean(exp_profit_1_6d_in))
println("Mean expected profit out of sample: ",mean(exp_profit_1_6d_out))
