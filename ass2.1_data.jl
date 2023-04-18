# Define Parameters for cost and capacity of conventional generators and wind farms
# Production capacity for conventional generators in MW
conv_gen_cap_hour = [155, 100, 155, 197, 350, 210, 80]
# Production cost for one hour for conventional generators in $/MWh (constant)
conv_gen_cost_hour = [15.2, 23.4, 15.2, 19.1, 5, 20.1, 24.7]
# Production capacity for windfarms in MW
wind_cap_hour = [450]
# Expected wind production for each hour in MW
wind_forecast_hour = [225]
# Production cost for windfarms in $/MWh
wind_cost_hour =[0]

#**************************************************
# Define demand variables
# Demand consumption matrix for each hour and for each generator
demand_cons_hour = [200, 400, 300, 250]

# Cost of bids matrix for each hour and for each generator
demand_bid_hour = [26.5, 24.7, 23.1, 22.5]

#**************************************************

# Define node and transmission data in the 24-bus system
node_dem = [[], [], [1], [2], [3], [4]]

node_wind = [[1], [], [], [], [], []]

node_conv = [[1], [2,3], [4,5], [], [6], [7]]


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
