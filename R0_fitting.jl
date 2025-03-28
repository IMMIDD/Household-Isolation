using GEMS, JLD2, DataFrames

include("result_data_style.jl")
include("output_analysis.jl")

rds = ResultData[]

for i in 0.01:0.001:0.03
    for y in 1:3
        sim = Simulation("SL_model_other.toml", "SL")
        sim.label = "TR: $i"
        pathogen(sim).transmission_function = ConstantTransmissionRate(transmission_rate = i)
        run!(sim)
        rd = ResultData(sim, style = "CustomRD")
        push!(rds, rd)
    end
end

outc = outcomes.(rds) |> df_from_outcomes |> summarize_outcomes

JLD2.save_object(joinpath("results", "R0_fitting.jld2"), outc)

gemsplot(rds)