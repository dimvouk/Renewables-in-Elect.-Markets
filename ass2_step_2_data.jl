# Define Parameters for cost and capacity of conventional generators and wind farms
# Production capacity for conventional generators in MW
gen_cap = [155, 100, 155, 197, 337.5, 350, 210, 80]
# Production cost for one hour for conventional generators in $/MWh (constant)
gen_cost = [15.2, 23.4, 15.2, 19.1, 0, 5, 20.1, 24.7]

# Strategic and Non-Strategic generators
strat_gen_cap = gen_cap[1:4]
strat_gen_cost = gen_cost[1:4]
non_strat_gen_cap = gen_cap[5:8]
non_strat_gen_cost = gen_cost[5:8]

#**************************************************
# Define demand variables
# Demand consumption matrix for each hour and for each generator
demand_cons = [200, 400, 300, 250]

# Cost of bids matrix for each hour and for each generator
demand_bid = [26.5, 24.7, 23.1, 22.5]

#**************************************************

# Define node and transmission data in the 24-bus system
node_dem = [[], [], [1], [2], [3], [4]]

node_gen = [[1, 5], [2, 6], [3, 7], [], [8], [4]]
strat_node_gen = [[1], [2], [3], [], [], [4]]
non_strat_node_gen = [[1], [2], [3], [], [4], []]


# Capacity of transmission lines between each node in MW
transm_capacity =  [[0     2000  2000   0     0     0   ];
                    [2000  0     2000   2000  0     0   ];
                    [2000  2000  0      0     0     2000];
                    [0     2000  0      0     2000  2000];
                    [0     0     0      2000  0     2000];
                    [0     0     2000   2000  2000     0];
]

# 2.3 Capacity of "congested" transmission lines between each node in MW
transm_capacity_2_3 =  [[0     2000     2000    0       0     0     ];
                        [2000  0        2000    254.25  0     0     ];
                        [2000  2000     0       0       0     220.75];
                        [0     254.25   0       0       2000  2000  ];
                        [0     0        0       2000    0     2000  ];
                        [0     0        220.75  2000    2000  0     ];
]

# make a list of all connections in transm_capacity
transm_connections = []
for n=1:6
    for m=1:6
        if transm_capacity[n,m] > 0
            push!(transm_connections, [n,m])
        end
    end
end

# 2.3: make a list of all "congested" connections in transm_capacity
transm_connections_2_3 = []
for n=1:6
    for m=1:6
        if transm_capacity_2_3[n,m] > 0
            push!(transm_connections_2_3, [n,m])
        end
    end
end

#*********************************
# Create input functions:

# Create a function that returns the connected nodes in an ingoing and outgoing direction
connections = length(transm_connections)
function connected_nodes(node)
    outgoing = []
    ingoing = []
    for i=1:connections
        if node == transm_connections[i][1]
            push!(outgoing, transm_connections[i][2])
        elseif node == transm_connections[i][2]
            push!(ingoing, transm_connections[i][1])
        end
    end
    return(outgoing, ingoing)
end

# 2.3: Create a function that returns the congested connected nodes in an ingoing and outgoing direction
connections = length(transm_connections_2_3)
function connected_nodes(node)
    outgoing = []
    ingoing = []
    for i=1:connections
        if node == transm_connections_2_3[i][1]
            push!(outgoing, transm_connections_2_3[i][2])
        elseif node == transm_connections_2_3[i][2]
            push!(ingoing, transm_connections_2_3[i][1])
        end
    end
    return(outgoing, ingoing)
end

# make functions receiving a demand, strategic or non-strategic generator as input
# and returning it's node location as output.

function node_demands(demand)
    loc_demands = 0
    for i=1:length(node_dem)
        if node_dem[i] == []
            continue
        end
        if node_dem[i][1] == demand
            loc_demands = i
        end
    end
    return(loc_demands)
end

function node_strat_gen(strat)
    loc_strat = 0
    for i=1:length(strat_node_gen)
        if strat_node_gen[i] == []
            continue
        end
        if strat_node_gen[i][1] == strat
            loc_strat = i
        end
    end
    return(loc_strat)
end

function node_non_strat_gen(nonstrat)
    loc_non_strat = 0
    for i=1:length(non_strat_node_gen)
        if non_strat_node_gen[i] == []
            continue
        end
        if non_strat_node_gen[i][1] == nonstrat
            loc_non_strat = i
        end
    end 
    return(loc_non_strat)
end


#*********************************
# 2.5: Input data over 24 hours with ramping constraints

ramping = [90, 85, 90, 120, 0, 350, 170, 80]
ramp_strat = ramping[1:4]
ramp_non_strat = ramping[5:8]

gen_cap = [155, 100, 155, 197, 337.5, 350, 210, 80]
wind_forecast_profile = [351.64, 336.1, 326.02, 318.4, 323.08, 317.54, 317.89, 329.08, 336.24, 340.11, 351.72, 341.65, 344.81, 323.35, 284.54, 227.4, 171.36, 129.4, 99.62, 89.04, 91.19, 114.89, 146.03, 148.17]
wind_profile_cap = 500

# Create matrix for 24 hours, using a normalized wind forecast for a profile with cap 500 MW.
gen_cap_24 = zeros(24,8)
for i=1:8
    if i == 5
        gen_cap_24[:,i] .= (wind_forecast_profile / wind_profile_cap) * 450
    else
        gen_cap_24[:,i] .= gen_cap[i]
    end
end

strat_gen_cap_24 = gen_cap_24[:,1:4]
non_strat_gen_cap_24 = gen_cap_24[:,5:8]

# Demand quantities for 24 hours, using a normalized demand profile.
demand_cons_profile = [77.17, 69.77, 62.89, 57.06, 53.43, 53.37, 55.06, 57.28, 59.5, 61.74, 64.1, 66.29, 68.04, 69.41, 70.6, 72.01, 75.1, 79.34, 73.94, 77.32, 77.09, 77.36, 76.0, 81.38]
demand_profile_avg = sum(demand_cons_profile) / 24
demand_cons_24 = zeros(24,4)

for i=1:4
    demand_cons_24[:,i] .= (demand_cons_profile / demand_profile_avg) * demand_cons[i]
end

# Demand bids for 24 hours, using a normalized demand bid profile.
demand_bid_profile = [11.94, 10.8, 9.73, 8.83, 8.27, 8.26, 8.52, 8.86, 9.21, 9.56, 9.92, 10.26, 10.53, 10.74, 10.93, 11.14, 11.62, 12.28, 12.99, 13.51, 13.48, 13.52, 13.31, 12.59]
demand_bid_avg = sum(demand_bid_profile) / 24
demand_bid_24 = zeros(24,4)

for i=1:4
    demand_bid_24[:,i] .= (demand_bid_profile / demand_bid_avg) * demand_bid[i]
end