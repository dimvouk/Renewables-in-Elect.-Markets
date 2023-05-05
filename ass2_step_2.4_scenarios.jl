include("ass2_step_2.4_uncertainty.jl")

s1 = 6  # offer price non strategic scenarios
s2 = 6   # bid price demand scenarios
s3 = 6  # quantity bid demand scenarios
s4 = 6  # wind production scenarios
Scen = s1*s2*s3*s4 # total number of scenarios

# Create a 3D array with dimensions 4x4x1296 for all possible scenarios
scenario = zeros(Float64, 4, 4, Scen)

for i = 1:Scen
    b = rand(1:s1)
    c = rand(1:s2)
    e = rand(1:s3)
    f = rand(1:s4)
    scenario[:, :, i] = hcat(o_offer_scenarios[b, :], demand_bid_scenarios[c, :], demand_cons_scenarios[e, :], o_prod_scenarios[f, :])
end

# Split the scenarios into two sets 

# Training set should contain the first 200 scenarios

seen_scenarios = scenario[:, :, 1:20]

# Testing set should contain the rest of the scenarios

unseen_scenarios = scenario[:, :, 21:Scen]