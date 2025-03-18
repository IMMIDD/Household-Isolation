using GEMS, DataFrames, Plots, Statistics, StatsPlots, Printf, Distributions

include("predicates.jl")
include("contributions.jl")
include("contact_sampling.jl")

#sim = Simulation(population = "SH")
sim = Simulation("SL_model.toml", "SL", label = "custom contacts")
run!(sim)
rd = ResultData(sim)
pp = PostProcessor(sim)
infs = infections(pp)
# calculate contributions
contributions = household_contribution(infs)



# list of predicate functions and names (function, label)
predicates = Dict(
    "i2"                => (i2,                         "2-person households"),
    "i3"                => (i3,                         "3-person households"),
    "i4"                => (i4,                         "4-person households"),
    "i5"                => (i5,                         "5-person households"),
    "i6plus"            => (i6plus,                     "6plus-person households"),
    "w_school"          => (with_schoolkids,            "household with schoolkids"),
    "wo_school"         => (without_schoolkids,         "household without schoolkids"),
    "mutliple_schools"  => (multiple_schools,           "kids in multiple different schools"),
    "i3_w_school"       => (i3_with_schoolkids,         "3p-household with schoolkids"),
    "i3_wo_school"      => (i3_without_schoolkids,      "3p-household without schoolkids"),
    "i4_w_school"       => (i4_with_schoolkids,         "4p-household with schoolkids"),
    "i4_wo_school"      => (i4_without_schoolkids,      "4p-household without schoolkids"),
    "i5_w_school"       => (i5_with_schoolkids,         "5p-household with schoolkids"),
    "i5_wo_school"      => (i5_without_schoolkids,      "5p-household without schoolkids"),
    "i6plus_w_school"   => (i6plus_with_schoolkids,     "6plus-household with schoolkids"),
    "i6plus_wo_school"  => (i6plus_without_schoolkids,  "6plus-household without schoolkids"),
    "i3_w_workers"      => (i3_with_workers,            "3p-household with workers"),
    "i3_wo_workers"     => (i3_without_workers,         "3p-household without workers"),
    "i4_w_workers"      => (i4_with_workers,            "4p-household with workers"),
    "i4_wo_workers"     => (i4_without_workers,         "4p-household without workers"),
    "i5_w_workers"      => (i5_with_workers,            "5p-household with workers"),
    "i5_wo_workers"     => (i5_without_workers,         "5p-household without workers"),
    "i6plus_w_workers"  => (i6plus_with_workers,        "6plus-household with workers"),
    "i6plus_wo_workers" => (i6plus_without_workers,     "6plus-household without workers"),
)

# dataframe with household information
hhlds = DataFrame(
    hh_id = id.(households(sim)),
    size = size.(households(sim)),
    avg_age =(h -> mean(age.(individuals(h)))).(households(sim))
)

# apply predicate functions
for (k, p) in predicates
    hhlds[!, k] = p[1].(households(sim))
end

# join with households-dataframe
df = leftjoin(hhlds, contributions, on = :hh_id)
# replace missing values
df.hh_contribution = coalesce.(df.hh_contribution, 0)
df.hh_contribution_ratio = coalesce.(df.hh_contribution_ratio, 0.0)


# plotting
boxplot(
    [p[2] for (k, p) in predicates], # labels
    [df.hh_contribution_ratio[df[!, k]] for (k, p) in predicates], # data
    label="", title="Household Contributions",
    ylabel="Contribution Ratio", xlabel="Household Types")

# takes a dataframe and a function to extract data
# from a dataframe and a particular column
function apply_to_column(df, f)
    res = Dict()
    for (k, v) in predicates
        res[k] = f(df, k)
    end
    return res
end

# number of households that match a criteria
number_of_households = apply_to_column(df, (df, c) -> sum(df[!, c]))

# number of households with 0 contribution (no follow-up infections)
zero_contribution = apply_to_column(df, (df, c) -> sum(df[!, c] .&& df.hh_contribution .== 0))

# ratio of household with 0 contribution (fraction of all households)
zero_contribution_ratio = apply_to_column(df, (df, c) -> zero_contribution[c] / number_of_households[c])

# average contribution (including 0s)
avg_contribution = apply_to_column(df, (df, c) -> mean(df.hh_contribution_ratio[df[!, c]]))

# average contribution (excluding 0s)
avg_pos_contribution = apply_to_column(df, (df, c) -> mean(df.hh_contribution_ratio[df[!, c] .&& df.hh_contribution_ratio .> 0]))

# median contribution (excluding 0s)
median_pos_contribution = apply_to_column(df, (df, c) ->  median(df.hh_contribution_ratio[df[!, c] .&& df.hh_contribution_ratio .> 0]))




plts = []
max_no_of_households = maximum([v for (k, v) in number_of_households])
max_zero_contribution_ratio = maximum([v for (k, v) in zero_contribution_ratio])
max_median_contribution = maximum([v for (k, v) in median_pos_contribution])
max_avg_contribution = maximum([v for (k, v) in avg_contribution])


xlims = (0, 1.1 * max_no_of_households)
ylims = (0.0, 1.1 * max_avg_contribution)
clims = (0, max_no_of_households)

# columns in combined plot
cols = 5
cnt = 0

for (k, p) in predicates
    show_x = length(predicates) - cnt < cols
    show_y = cnt % cols == 0

    push!(plts,
        scatter([number_of_households[k]], [avg_contribution[k]],
            # zcolor = number_of_households[k],
            # cmap=:reds,
            # clims = clims,
            #yaxis = show_y,
            #xformatter = show_x ? x -> "$(Int64(round(100 * x)))%" : :none,
            xformatter = show_x ? x -> x : :none,
            yformatter = show_y ? y -> "$(@sprintf("%.4f", round(100 * y, digits = 4)))%" : :none,
            tickfontsize = 12,
            xlims = xlims, 
            ylims = ylims,
            markersize= 7.5 + 7.5 * number_of_households[k] / max_no_of_households,
            color = :red,
            markerstrokewidth=0,
            #label = k,
            title = predicates[k][2],
            legend = false)
    )

    cnt += 1
end

plot(plts..., size = (2000, 1400))
#, layout = (1, 7), size = (1000, 200))










#### EXPERIMENTS 



scatter([df.avg_age], [df.hh_contribution], size = (1000, 1000))


gemsplot(rd)



sum(hhlds.size[hhlds.size .>= 500])

hhlds |> nrow


sim1 = Simulation(population = "SL", label = "default",
    school_complex_contact_rate = 0.0,
    school_contact_rate = 0.0,
    school_year_contact_rate = 0.0,
    school_class_contact_rate = 0.0,
    workplace_site_contact_rate = 0.0,
    workplace_contact_rate = 0.0,
    department_contact_rate = 0.0,
    office_contact_rate = 0.0,
    municipality_contact_rate = 0.0,
    global_contact_rate = 0.5,
    household_contact_rate = 1.5,
    global_setting = true,
    transmission_rate = 0.15
)
sim2 = Simulation("SL_model.toml", "SL", label = "custom contacts")

run!(sim1)
run!(sim2)

rd1 = ResultData(sim1)
rd2 = ResultData(sim2)


gemsplot([rd1, rd2])

gemsplot([rd1, rd2], type = :TickCasesBySetting)

gemsplot(rd2, type = :TickCasesBySetting)


rd1 |> infections |> nrow
rd2 |> infections |> nrow



N = Normal(0, 3)
rand(N, 100) |> histogram
