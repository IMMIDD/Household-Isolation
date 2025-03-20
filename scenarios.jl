using GEMS, DataFrames, Plots, Statistics, StatsPlots
using Printf, Distributions, Dates, Proj, JLD2, Measures

# INLCUDES
include("predicates.jl")
include("contributions.jl")
include("contact_sampling.jl")
include("model_analysis.jl")
include("result_data_style.jl")

# RUNNING INITIAL SIMULATION
# function to initialize the test simulation
init_sim() = Simulation("SL_model.toml", "SL", label = "custom contacts")
sim = init_sim()
run!(sim)
rd = ResultData(sim, style = "CustomRD") # this custom RD-style doesn't store strategies (prevents sim-object from being referenced in RDs)
pp = PostProcessor(sim)
infs = infections(pp)

# RESULT FOLDER
folder = joinpath("results", "$(Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM-SS_sss"))")
mkpath(folder)


# MODEL ANALYSIS / SETTING SIZES AND MAPPING
hh_s = hh_sizes(sim)
hh_plot = bar(hh_s.size, hh_s.cnt,
    bins = 1:1:7,
    label = " Num. of Households",
    color = :black,
    tickfontsize = 10,
    legendfontsize = 10,
    top_margin=5mm,
    bottom_margin=5mm,
    #ylabel = "# of Settings",
    xformatter = (x -> x == 7 ? "7+" : "$(Int(x))"))

wp_s = wp_sizes(sim, 30, 200)
wp_plot = bar(wp_s.cnt,
    color = :red,
    tickfontsize = 10,
    legendfontsize = 10,
    bottom_margin=5mm,
    #ylabel = "# of Settings",
    xticks=(1:length(wp_s.size), format_xticks(wp_s.size)),  
    label = " Num. of Workplaces")

s_s = s_sizes(sim, 30, 200)
s_plot = bar(s_s.cnt,
    color = :blue,
    tickfontsize = 10,
    legendfontsize = 10,
    bottom_margin=5mm,
    xlabel = "Size\n",
    #ylabel = "# of Settings",
    xticks=(1:length(s_s.size), format_xticks(s_s.size)),  
    label = " Num. of Schools")

setting_map = plot_settings(sim)


l = @layout [a{0.7w} grid(3, 1)]

p = plot(
    setting_map, hh_plot, wp_plot, s_plot,
    layout = l,
)

png(p, joinpath(folder, "settings_and_map.png"))


# MODEL ANALYSIS / DISEASE PROGRESSION

dpr = gemsplot(rd, type = :CumulativeDiseaseProgressions,
    ylabel = "Disease State",
    size = (400, 200),
    title = "")

png(dpr, joinpath(folder, "disease_progressions.png"))


##### CREATE HOUSEHOLD DATAFRAME WITH TYPE ATTRIBUTIONS #####

# list of predicate functions and names (function, label)
predicates = Dict(
    "all"               => (all_households,             "all households"),
    "rand_34percent"    => (rand34_percent,             "random 34%"),
    "i2"                => (i2,                         "2-person households"),
    "i3"                => (i3,                         "3-person households"),
    "i4"                => (i4,                         "4-person households"),
    "i5"                => (i5,                         "5-person households"),
    "i6plus"            => (i6plus,                     "6plus-person households"),
    "w_school"          => (with_schoolkids,            "household with schoolkids"),
    "wo_school"         => (without_schoolkids,         "household without schoolkids"),
    "multiple_schools"  => (multiple_schools,           "kids in multiple different schools"),
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
    "big_schools"       => (big_schools,                "one student in 150+ sized school"),
)

# dataframe with household information
hhlds = DataFrame(
    hh_id = id.(households(sim)),
    size = size.(households(sim)),
    avg_age =(h -> mean(age.(individuals(h)))).(households(sim))
)

# apply predicate functions
for (k, p) in predicates
    hhlds[!, k] = (h -> p[1](h, sim)).(households(sim))
end

# join with households-dataframe
df = leftjoin(hhlds, contributions, on = :hh_id)
# replace missing values
df.hh_contribution = coalesce.(df.hh_contribution, 0)
df.hh_contribution_ratio = coalesce.(df.hh_contribution_ratio, 0.0)




# CALCULATE HOUSEHOLD CONTRIBUTIONS

contributions = household_contribution_2(infs)

# CALCULATE HOUSEHOLD TYPE CONTRIBUTIONS

# join infections dataframe with household predicate data

joined_df = infs |>
    x -> DataFrames.select(x, :source_infection_id, :infection_id, :household_b => :hh_id) |>
    x -> leftjoin(x, hhlds, on = :hh_id) |>
    x -> sort(x, :infection_id)


contribution_per_type = Dict()
# rename household IDs to only "true" or "false", depending
# on whether they match the predicates. This will cause the
# household-contribution function to calculate the fraction 
# of infections that involve this household type at any point
for (k ,v) in predicates
    joined_df |>
        x -> DataFrames.select(x, :source_infection_id, :infection_id, Symbol(k) => :household_b) |>
        x -> household_contribution_2(x) |>
        x -> x.hh_contribution_ratio[x.hh_id] |> first |>
        x -> contribution_per_type[k] = x
end


##### ANALYZE HOUSEHOLD TYPE CONTRIBUTIONS #####

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

# fraction of households that match a criteria
number_of_households_ratio = apply_to_column(df, (df, c) -> number_of_households[c] / nrow(df))

# number of households with 0 contribution (no follow-up infections)
zero_contribution = apply_to_column(df, (df, c) -> sum(df[!, c] .&& df.hh_contribution .== 0))

# ratio of household with 0 contribution (fraction of all households)
zero_contribution_ratio = apply_to_column(df, (df, c) -> zero_contribution[c] / number_of_households[c])

# average contr ibution (including 0s)
avg_contribution = apply_to_column(df, (df, c) -> mean(df.hh_contribution_ratio[df[!, c]]))

# average contribution (excluding 0s)
avg_pos_contribution = apply_to_column(df, (df, c) -> mean(df.hh_contribution_ratio[df[!, c] .&& df.hh_contribution_ratio .> 0]))

# median contribution (excluding 0s)
median_pos_contribution = apply_to_column(df, (df, c) ->  median(df.hh_contribution_ratio[df[!, c] .&& df.hh_contribution_ratio .> 0]))

# contribution by size
contribution_by_size_ratio = apply_to_column(df, (df, c) -> contribution_per_type[c] / number_of_households_ratio[c])

##### PLOTTING CONTRIBUTIONS #####

plts = []
max_no_of_households = maximum([v for (k, v) in number_of_households])
max_ratio_households = maximum([v for (k, v) in number_of_households_ratio])
max_zero_contribution_ratio = maximum([v for (k, v) in zero_contribution_ratio])
max_median_contribution = maximum([v for (k, v) in median_pos_contribution])
max_avg_contribution = maximum([v for (k, v) in avg_contribution])


xlims = (0, 1.1 * max_ratio_households)
ylims = (0.0, 1.1 * max_avg_contribution)
clims = (0, max_no_of_households)

# columns in combined plot
cols = 5
plot_cnt = 0

for (k, p) in predicates
    show_x = length(predicates) - plot_cnt <= cols
    show_y = plot_cnt % cols == 0

    push!(plts,
        scatter([number_of_households_ratio[k]], [contribution_per_type[k]],
            # zcolor = number_of_households[k],
            # cmap=:reds,
            # clims = clims,
            #yaxis = show_y,
            xformatter = show_x ? x -> "$(Int64(round(100 * x)))%" : :none,
            #xformatter = show_x ? x -> x : :none,
            #yformatter = show_y ? y -> "$(@sprintf("%.4f", round(100 * y, digits = 4)))%" : :none,
            yformatter = show_x ? x -> "$(Int64(round(100 * x)))%" : :none,
            tickfontsize = 12,
            xlims = (0, 1), 
            ylims = (0, 1),
            #markersize= 7.5 + 7.5 * number_of_households[k] / max_no_of_households,
            markersize= 10,
            color = :red,
            markerstrokewidth=0,
            #label = k,
            title = predicates[k][2],
            legend = false)
    )

    plot_cnt += 1
end

# combine plot
p = plot(plts..., size = (2000, 1400))
# store plot
png(p, joinpath(folder, "contribution_analysis.png"))


# condensed plot

combinations = Dict(
    "General" => Dict(
        "all" => :black,
        "w_school" => :red,
        "wo_school" => :blue,
        "rand_34percent" => :indigo,
        "big_schools" => :hotpink,
        "multiple_schools" => :brown,
        "i2" => :bisque4,
    ),
    "3-Person Households" => Dict(
        "i3" => :black,
        "i3_w_school" => :red,
        "i3_wo_school" => :blue,
        "i3_w_workers" => :green,
        "i3_wo_workers" => :orange,
    ),
    "4-Person Households" => Dict(
        "i4" => :black,
        "i4_w_school" => :red,
        "i4_wo_school" => :blue,
        "i4_w_workers" => :green,
        "i4_wo_workers" => :orange,
    ),
    "5-Person Households" => Dict(
        "i5" => :black,
        "i5_w_school" => :red,
        "i5_wo_school" => :blue,
        "i5_w_workers" => :green,
        "i5_wo_workers" => :orange,
    ),
    "6+-Person Households" => Dict(
        "i6plus" => :black,
        "i6plus_w_school" => :red,
        "i6plus_wo_school" => :blue,
        "i6plus_w_workers" => :green,
        "i6plus_wo_workers" => :orange,
    )
)

plts = []
for (comb, data) in combinations
    p = plot(title = comb, aspect_ratio = max_ratio_households / max_avg_contribution)
    for (k, col) in data
        scatter!(p, [number_of_households_ratio[k]], [avg_contribution[k]],
            xformatter = x -> "$(Int64(round(100 * x)))%",
            yformatter =  y -> "$(@sprintf("%.4f", round(100 * y, digits = 4)))%",
            #tickfontsize = 12,
            xlims = xlims, 
            ylims = ylims,
            markersize= 13,
            color = col,
            markerstrokewidth=0,
            legend = :outerright,
            label = predicates[k][2],
            tickfontsize = 12,
        )
    end
    push!(plts, p)
end

p = plot(plts..., layout = (2, 3), size = (2000, 800))


DataFrame(
    label = collect(keys(contribution_by_size_ratio)),
    value = collect(values(contribution_by_size_ratio))
) |>
    x -> sort(x, :value) |>
    x -> bar(x.value,
    xticks=(1:length(x.label), x.label))


##### SIMULATIONS

# adds the household isolation scenario
# to a simulation object and conditions
# the execution on the provided predicate
# function (that takes the household and
# the sim object)
function scenario(sim, predicate)

    quarantine_person = IStrategy("quarantine_person", sim)
    add_measure!(quarantine_person, SelfIsolation(14))

    find_hh_members = SStrategy("find_members", sim, condition = h -> predicate(h, sim)) # apply only to selected households
    add_measure!(find_hh_members, FindMembers(quarantine_person))

    find_household = IStrategy("find_household", sim)
    add_measure!(find_household, FindSetting(Household, find_hh_members))

    st = SymptomTrigger(find_household)
    add_symptom_trigger!(sim, st)
end

# run one simulation per predicate
res = Dict{String, ResultData}()
for (k, p) in predicates
    try # try-catch block is important so the stuff don't crash if run without geolocalized test-model
        sim = init_sim() #Simulation(progression_categories = [0.0, 1.0, 0.0, 0.0])
        sim.label = k
        scenario(sim, p[1])
        run!(sim)
        rd = ResultData(sim, style = "CustomRD")
        res[k] = rd
    catch
    end
end


gemsplot(collect(values(res)), type = (:TickCases, :CumulativeCases, :EffectiveReproduction), size = (1000, 1500))

#gemsplot(collect(values(res))[1], type = :CumulativeDiseaseProgressions)

# store simulation data
JLD2.save_object(joinpath(folder, "sim_data.jld2"), res)
