# Renewables-in-Elect.-Markets-
The aim of these scripts is to solve the Assignmnent 2 of the course "46755 - Renewbles in Electricity Mmarkets".

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--------------------------------STEP 1---------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
"scenario generation.jl"

This script iteratates through a for loop and creates the 600 scenarios needed for the whole step 1. The scenarios are generated randomly and are already dividede into the in-sample ("seen") and out-of-sample ("unseen") scenarios.

-----------------------------------------------------------------------
-----------------------------------------------------------------------
"Sources of Uncertainty (data input.jl)"

This script is used to generate the wind production values (MWh) for the 6 wind farm scenarios and the day ahead prices for the 10 respective scenarios. 
The system need (excess or deficit) is then randomly generated based on a Bernoulli distribution for each scenario and a specific matrix is created based on these values.  

-----------------------------------------------------------------------
-----------------------------------------------------------------------
"ass2.1_data"

	- Define the production capacity for conventional generators (MW)
	- Define production cost for one hour for conventional generators in $/MWh (constant)
	- Define demand consumption matrix for each hour and for each generator
	- Define  cost of bids matrix for each hour and for each generator
	- Define nodes relationship
	- Define transmission capacity on the line to avoid congestion
	- Re-define the transmission capacities for step 2.3 based on the results of step 2.2 (set the capacity of certain lines to the actual power flow)
	- make a list of all connections and store them
	- 2.3: make a list of all "congested" connections and store them

-----------------------------------------------------------------------
-----------------------------------------------------------------------
"ass2_PlotResults.ipynb"

This Jupiter notebook just created the graphs and plots used in the report to show the results obtained for the various steps.

-----------------------------------------------------------------------
-----------------------------------------------------------------------
"ass2_step_1.1.jl"

This script implements a 1-price-scheme market problem for the balancing market. The balancing price is therefore computed before the optimisation problem (line 20) and is fixed for the script.

-----------------------------------------------------------------------
-----------------------------------------------------------------------
"ass2_step_1_2.jl"

Diversely from the previous script, this one runs a 2-price-scheme anmd therefore the balancing price depends both on the system status and on the fact that the wind turbine is helping the system to reduce imbalance or not. 
This is done be including the dependency of these variables in the balancing price and therefore determing its value for each scenario.

-----------------------------------------------------------------------
-----------------------------------------------------------------------
"ass2_step_1.4.1.jl"

This script is identical to the one used for step 1.1, with the difference that CVaR is taken into account. This is done by defining alfa and beta values and running the new optimisation problem for each value of both these parameters (line 43, 44). Also, the CVaR value is calculated and included in the objective function (lines 66, 67).

-----------------------------------------------------------------------
-----------------------------------------------------------------------
"ass2_step_1.4.2.jl"

This optimisation problem, as the one in step 1.2, takes into account an market clearing algorithm for a two price scheme. The model is ran for each value of alpha and beta given and the value of the CVaR function is computed for each iteration in the objective function (line 56). 
The mean expected profit is then printed just for comparison, but the assignment shows the trend of this expected profit when the value of the coefficients varies as said in the report instructions.

-----------------------------------------------------------------------
-----------------------------------------------------------------------
Step 1.5

For all the sections in step 1.5, the optimisation problem is solved for the 400/600 out-of-sample scenarios. These are generated in the file "scenario generation.jl" and recalled here by recalling this file at the start of the code. 
For each script ("ass2_step_1.5.a.jl" to "ass2_step_1.5.d") the steps followed are the same as in the previous scripts, but the scenarios considered are switched from "seen_scenarios" to "unseen_scenarios". 

Schematically, each scripts considers:

"ass2_step_1.5.b.jl"
	- Out of sample scenarios for step 1.1
	- 1-price scheme 
	- no CVaR 

"ass2_step_1.5.b.jl"
	- Out of sample scenarios for step 1.2
	- 2-price scheme 
	- no CVaR 

"ass2_step_1.5.c.jl"
	- Out of sample scenarios for step 1.4.1
	- 1-price scheme 
	- Yes CVaR 

"ass2_step_1.5.d.jl"
	- Out of sample scenarios for step 1.4.2
	- 2-price scheme 
	- yes CVaR 

-----------------------------------------------------------------------
-----------------------------------------------------------------------
Step 1.6.1

The first step of the cross validation consits of solving the optimisation problems 1.1 to 1.4.2 with different in-sample scenarios. This means taking 200 diffrent scenarios out of the 600 generated ones for solving the optimisation problems. 

Since the scenarios are generated in the script "scenario generation.jl", the considered in-sample ones are always the same and therfore yield to the same results when the optimisation problems are executed. to choose other scenarios, the 600 vector containing all the scenarios is shuffled through indices permutation at the start of the scripts and then the 200 in-sample and 400 ou-of-sample scenarios are generated. 

This recalculation is done for an arbitrary number of iterations. For the cases in which CVaR is not considered (steps 1.1 and 1.2 for in-sample and steps 1.5.a and 1.5.b for the out-of-sample) 50 iterations are considered. When CVaR is considered (steps 1.4.1 and 1.4.2 for in-sample and steps 1.5.c and 1.5.d for out-of-sample), only 2 iterations are considered as the time of the computation increases radically as the optimisation problem has to run through all the values of alpha and beta as well.

Both the in sample and out of sample results are run in the same script in norder to optimise the output ease of read:


"ass2_step_1.6.1.a.jl"
	- Sensitivity analysis 
	- step 1.1 and 1.5.a
	- 1-price scheme 
	- 200 in sample scenarios
	- 400 out of sample scenarios
	- no CVaR

"ass2_step_1.6.1.b.jl"
	- Sensitivity analysis 
	- step 1.2 and 1.5.b
	- 2-price scheme 
	- 200 in sample scenarios
	- 400 out of sample scenarios
	- no CVaR

"ass2_step_1.6.1.c.jl"
	- Sensitivity analysis 
	- step 1.4.1 and 1.5.c 
	- 1-price scheme 
	- 200 in sample scenarios
	- 400 out of sample scenarios
	- yes CVaR

"ass2_step_1.6.1.d.jl"
	- Sensitivity analysis 
	- step 1.4.2 and 1.5.d
	- 2-price scheme 
	- 200 in sample scenarios
	- 400 out of sample scenario
	- yes CVaR
-----------------------------------------------------------------------
-----------------------------------------------------------------------
Step 1.6.2

The second part of this step is considering a different number of scenarios from 200/600. This is done by setting the number of in-sample scenarios to different values:

S_in = [150,200,250,300,350]

The optimization problem is then iterated and the in-sample scenario vector "seen_scenarios" is created for each iteration based on the number of scenarios chosen for that iteration. The scritpts  "ass2_step_1.6.2.a.jl" to "ass2_step_1.6.2.d.jl" recall respectively the scripts "ass2_step_1.1" to "ass2_step_1.4.2" with the new in-sample scenario number determinated in a for loop.

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--------------------------------STEP 2---------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------

"ass2_step_2.1.jl"

A situation as the one explained through Image 1 and Table 1 in the report instructions is implemented in this step through an optimisation problem. All the market players are assumed to be offering the true cost of their production so to not incllude the fact that someone may be behaving strategically.

Connection constraints regarding the capacity (which is chosen so that there is no congestion) is implemented but the objective function is written in order to maximise the social welfare.

-----------------------------------------------------------------------
-----------------------------------------------------------------------
"ass2_step_2.2.jl"

This script implements a problem similar to the one in step 2.1. The only difference is that one market player, namely the units S1-S4 behave strategically. This implies that a bi-level optimisation problem has to be solved. To do this, the optimisation problem that maximises social welfare becomes the constraint to the problem that needs to be  solved, which is the maximisation of the strategic producer's revenue.
To do this and maintain the linearity of the problem, the social welfare maximisation problem is written as the KKT condition that form it and to further linearise these, the "big M" approach is used. 

Different values of the big M are chosen in line 31 and used in the constraints further on in the script.

In line 97 the variables are defined and constrained from line 139 on to formalise the KKT conditions as explained in the report. 

The optimisation problem yields to different visualized results:
	- node market clearing prices, depending on the energy flow to and from the respective node
	- strategic offer prics for each generator
	- offer schedules for the non strategic generators
	- Social welfare
	- Power flow between nodes 
	
-----------------------------------------------------------------------
-----------------------------------------------------------------------
"ass2_step_2.3.jl"

Starting from step 2.2, a matrix called "transm_connections_2_3" is added to the "ass2.1_data" script. This is a matrix in which the power capacity of the lines 2-4 and 3-6 are modified in order to have the power flow of the same lines obtained in the previous point as the capacity. 
The optimisation problem used for step 2.2 is then executed with this new data implemented 

-----------------------------------------------------------------------
-----------------------------------------------------------------------
"ass2_step_2.4.jl"

-----------------------------------------------------------------------
-----------------------------------------------------------------------
"ass2_step_2.4_scenarios.jl"

-----------------------------------------------------------------------
-----------------------------------------------------------------------
"ass2_step_2.4_uncertainty.jl"

















