include("Sources of Uncertainty (data input).jl")

# Create a 3D array with dimensions 24x3x600 for all possible scenarios
scenario = zeros(Float64, 24, 3, 600)

n1 = 10  # price_da scenarios
n2 = 6   # wind_production_da scenarios 
n3 = 10  # system need scenarios

# Fill scenario array with all the possible scenarios

for i in 1:600
    for k in 1:n1
        for l in 1:n2
            for m in 1:n3
                scenario[:, 1, i] = price_da[:, k]
                scenario[:, 2, i] = wind_production_da[:, l]
                scenario[:, 3, i] = System_need[:, m]
            end
        end
    end
end 

# Split the scenarios into two sets 

# Training set should contain the first 200 scenarios

train_set = scenario[:, :, 1:200]

# Testing set should contain  the rest 400 scenarios

test_set = scenario[:, :, 201:600]