include("Sources of Uncertainty (data input).jl")

scenario = zeros(Float64, 24, 3, 600)

for i = 1:600
    a = rand(1:10)
    b = rand(1:6)
    c = rand(1:10)
    scenario[:, :, i] = hcat(price_da[:, a], wind_production_real[:, b], System_need[:, c])
end