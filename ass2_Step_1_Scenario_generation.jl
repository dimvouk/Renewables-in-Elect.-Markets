include("ass2_step_1_Sources_of_Uncertainty_data_input.jl")

# Create a 3D array with dimensions 24x3x600 for all possible scenarios
scenario = zeros(Float64, 24, 3, 600)

n1 = 10  # price_da scenarios
n2 = 6   # wind_production_da scenarios 
n3 = 10  # system need scenarios


for i = 1:600
    k = rand(1:n1)
    l = rand(1:n2)
    m = rand(1:n3)
    scenario[:, :, i] = hcat(price_da[:, k], wind_production_real[:, l], System_need[:, m])
end

# Split the scenarios into two sets 

# Training set should contain the first 200 scenarios

seen_scenarios = scenario[:, :, 1:200]

# Testing set should contain the rest of the 400 scenarios

unseen_scenarios = scenario[:, :, 201:600]