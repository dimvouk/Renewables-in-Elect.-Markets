# Define Parameters for cost and capacity of conventional generators and wind farms
# Production capacity for conventional generators in MW
gen_cap = [155, 100, 155, 197, 337.5, 350, 210, 80]
# Production cost for one hour for conventional generators in $/MWh (constant)
gen_cost = [15.2, 23.4, 15.2, 19.1, 0, 5, 20.1, 24.7]

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

# make a list of all connections in transm_capacity
transm_connections = []
for n=1:6
    for m=1:6
        if transm_capacity[n,m] > 0
            push!(transm_connections, [n,m])
        end
    end
end

#*********************************
