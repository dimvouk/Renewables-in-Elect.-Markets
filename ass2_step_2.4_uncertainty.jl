# Sources of uncertainty
using Random, Distributions 

# import data
include("ass2.1_data.jl")

# Change in +- 25% is chosen for all sources of uncertainty, as this is a reasonable change in the market
# and keeps demand lower than supply in all scenarios.

# 1. non strategic offer price - 6 scenarios
o_offer = gen_cost[5:8]
# following a uniform distribution, create 6 scenarios for o_offer. From 0 to +5 for wind farm
o_offer_scenarios = zeros(6,4)
for o=1:4
    for i=1:6
        if o == 1
            o_offer_scenarios[i,o] = o_offer[o]
        else
            o_offer_scenarios[i,o] = rand(Uniform(o_offer[o]*0.75, o_offer[o]*1.25))
        end 
    end 
end

# 2. bid price of demands - 6 scenarios
# following a uniform distribution, create 6 scenarios for demand_bid.
demand_bid_scenarios = zeros(6,4)
for d=1:4
    for i=1:6
        demand_bid_scenarios[i,d] = rand(Uniform(demand_bid[d]*0.75, demand_bid[d]*1.25))
    end 
end

# 3. The quantity bid of demands - 6 scenarios
# following a uniform distribution, create 6 scenarios for demand_cons.
demand_cons_scenarios = zeros(6,4)
for d=1:4
    for i=1:6
        demand_cons_scenarios[i,d] = rand(Uniform(demand_cons[d]*0.75, demand_cons[d]*1.25))
    end 
end

# 4. The production of wind producer O1 - 6 scenarios
o_prod = gen_cap[5:8]
# following a uniform distribution, create 6 scenarios for only O1, O2-4 stays the same in all scenarios.
o_prod_scenarios = zeros(6,4)
for o=1:4
    for i=1:6
        if o == 1
            o_prod_scenarios[i, o] = rand(Uniform(o_prod[o]*0.75, o_prod[o]*1.25))
        else 
            o_prod_scenarios[i, o] = o_prod[o]
        end 
    end 
end