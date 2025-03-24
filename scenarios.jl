using GEMS, DataFrames, Plots, Statistics, StatsPlots
using Printf, Distributions, Dates, Proj, JLD2, Measures
using DataStructures, Colors


# INLCUDES
include("predicates.jl")
include("contributions.jl")
include("contact_sampling.jl")
include("model_analysis.jl")
include("result_data_style.jl")

# RESULT FOLDER
folder = joinpath("results", "$(Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM-SS_sss"))")
mkpath(folder)

#####
##### GLOBAL PARAMETERS
#####

num_of_baseline_sims = 3
num_of_scenario_sims = 3
quarantine_duration = 14

#####
##### RUNNING BASELINE SIMULATIONS
#####


# function to initialize the test simulation
init_sim() = Simulation("SL_model.toml", "SL")
#init_sim() = Simulation(label = "Baseline")

baseline_rds = ResultData[]
baseline_infections = DataFrame[]
for i in 1:num_of_baseline_sims
    sim = init_sim()
    sim.label = "Baseline"
    run!(sim)
    # this custom RD-style doesn't store strategies (prevents sim-object from being referenced in RDs)
    pp = PostProcessor(sim)
    # store infections dataframes seperately
    infs = infections(pp)
    push!(baseline_infections, infs)
    rd = ResultData(pp, style = "CustomRD")
    push!(baseline_rds, rd)
end

# store raw data
JLD2.save_object(joinpath(folder, "baseline_rds.jld2"), baseline_rds)
JLD2.save_object(joinpath(folder, "baseline_infections.jld2"), baseline_infections)

# one single baseline simulation to run model analyses
baseline_sim = init_sim()


#####
##### BASELINE ANALYSIS
#####

# --> BASELINE DISEASE PROGRESSION

# plot baseline analysis
p_baseline = plot(
    gemsplot(baseline_rds, type = :TickCases,
        plot_title = "",
        title = "Infections per Day",
        titlefontsize = 12,
        bottom_margin = 8mm,
        ylabel = ""),
    gemsplot(baseline_rds, type = :EffectiveReproduction,
        plot_title = "",
        title = "Reproduction Number",
        titlefontsize = 12,
        ylabel = ""),
    gemsplot(baseline_rds[1], type = :CumulativeDiseaseProgressions,
        plot_title = "",    
        title = "Disease States",
        titlefontsize = 12,
        ylabel = ""),
    layout = (1, 3),
    size = (1200, 300)
)
png(p_baseline, joinpath(folder, "baseline.png"))

# --> SETTING SIZES AND MAP

# household sizes
hh_s = hh_sizes(baseline_sim)
hh_plot = bar(hh_s.size, hh_s.cnt,
    bins = 1:1:7,
    label = " Num. of Households",
    color = :black,
    tickfontsize = 10,
    legendfontsize = 10,
    top_margin=5mm,
    bottom_margin=5mm,
    xformatter = (x -> x == 7 ? "7+" : "$(Int(x))"))

# workplace sizes
wp_s = wp_sizes(baseline_sim, 30, 200)
wp_plot = bar(wp_s.cnt,
    color = :red,
    tickfontsize = 10,
    legendfontsize = 10,
    bottom_margin=5mm,
    xticks=(1:length(wp_s.size), format_xticks(wp_s.size)),  
    label = " Num. of Workplaces")

# school sizes
s_s = s_sizes(baseline_sim, 30, 200)
s_plot = bar(s_s.cnt,
    color = :blue,
    tickfontsize = 10,
    legendfontsize = 10,
    bottom_margin=5mm,
    xlabel = "Size\n",
    xticks=(1:length(s_s.size), format_xticks(s_s.size)),  
    label = " Num. of Schools")

# map
setting_map = plot_settings(baseline_sim)

# combined plot
l = @layout [a{0.7w} grid(3, 1)]
p = plot(
    setting_map, hh_plot, wp_plot, s_plot,
    layout = l,
)
png(p, joinpath(folder, "settings_and_map.png"))


#####
##### HOUSEHOLD ATTRIBUTES (PREDICATES)
#####

# predicate functions that filter for size-based
# household types "identifier" => (function(h, sim), label)
size_predicates = OrderedDict(
    "all_sizes"                => (all_sizes,                  "all sizes"),
    "i1"                       => (i1,                         "1 person"),
    "i2"                       => (i2,                         "2 persons"),
    "i3"                       => (i3,                         "3 persons"),
    "i4"                       => (i4,                         "4 persons"),
    "i5"                       => (i5,                         "5 persons"),
    "i6plus"                   => (i6plus,                     "6+ persons")
)

# predicate functions that filter for composition-based
# household types "identifier" => (function(h, sim), label)
composition_predicates = OrderedDict(
    "all_compositions"         => (all_sizes,                  "all compositions"),    
    # school
    "w_schoolkids"             => (w_schoolkids,               "with schoolkids"),
    "w_1_schoolkid"            => (w_1_schoolkid,              "with 1 schoolkid"),
    "w_2plus_schoolkid"        => (w_2plus_schoolkids,          "with 2+ schoolkids"),
    "wo_schoolkids"            => (wo_schoolkids,              "without schoolkids"),
    "multiple_schools"         => (multiple_schools,           "with kids in multiple schools"),
    "big_schools"              => (big_schools,                "with 1+ kid in big schools"),
    #workers
    "w_workers"                => (w_workers,                  "with workers"),
    "w_1_worker"               => (w_1_worker,                 "with 1 worker"),
    "w_2plus_worker"           => (w_2plus_workers,            "with 2+ workers"),
    "wo_workers"               => (wo_workers,                 "without workers"),
    # combinations
    "w_schoolkids_w_workers"   => (w_schoolkids_w_workers,     "with schoolkids; with workers"),
    "w_schoolkids_wo_workers"  => (w_schoolkids_wo_workers,    "with schoolkids; without workers"),
    "wo_schoolkids_w_workers"  => (wo_schoolkids_w_workers,    "without schoolkids; with workers"),
    "wo_schoolkids_wo_workers" => (wo_schoolkids_wo_workers,   "without schoolkids; without workers"),
)

# predicate functions that filter for minimum-size-based
# household types "identifier" => (function(h, sim), label)
size_limit_predicates = OrderedDict(
    "all sizes"                => (all_sizes,                  "all sizes"),
    "i2plus"                   => (i2plus,                     "2 persons"),
    "i3plus"                   => (i3plus,                     "3 persons"),
    "i4plus"                   => (i4plus,                     "4 persons"),
    "i5plus"                   => (i5plus,                     "5 persons"),
    "i6plus"                   => (i6plus,                     "6+ persons")
)

# all predicate (size-composition) combinations
predicates = OrderedDict()
for (s, p1) in size_predicates
    for (c, p2) in composition_predicates
        predicates["$(s)_$c"] = ((h, sim) -> (p1[1](h, sim) && p2[1](h, sim)), "$(p1[2]); $(p2[2])")
    end
end

# dataframe with household information
hhlds = DataFrame(
    hh_id = id.(households(baseline_sim)),
    size = size.(households(baseline_sim)),
    avg_age =(h -> mean(age.(individuals(h)))).(households(baseline_sim))
)

# apply predicate functions
for (k, p) in predicates
    hhlds[!, k] = (h -> p[1](h, baseline_sim)).(households(baseline_sim))
end


#####
##### CALCULATE CONTRIBUTIONS
#####

# calculate contributions for each of the baseline runs
contribution_per_type = OrderedDict[]
for infs in baseline_infections

    # join infections dataframe with household predicate data
    joined_df = infs |>
        x -> DataFrames.select(x, :source_infection_id, :infection_id, :household_b => :hh_id) |>
        x -> leftjoin(x, hhlds, on = :hh_id) |>
        x -> sort(x, :infection_id)

    # rename household IDs to only "true" or "false", depending
    # on whether they match the predicates. This will cause the
    # household-contribution function to calculate the fraction 
    # of infections that involve this household type at any point
    res = OrderedDict()
    for (k ,v) in predicates
        joined_df |>
            x -> DataFrames.select(x, :source_infection_id, :infection_id, Symbol(k) => :household_b) |>
            x -> household_contribution_2(x) |>
            x -> x.hh_contribution_ratio[x.hh_id] |>
            x -> res[k] = length(x) == 0 ? 0 : first(x) # set 0 if no contribution was found
    end

    push!(contribution_per_type, res)    
end

# store JLD object
JLD2.save_object(joinpath(folder, "contribution_per_type.jld2"), contribution_per_type)


# calculate mean over all contribution calculations
mean_contribution_per_type = OrderedDict()
for (k, p) in predicates
    mean_contribution_per_type[k] = mean([conts[k] for conts in contribution_per_type])
end


#####
##### ANALYZE HOUSEHOLD TYPE CONTRIBUTIONS
#####

# takes a dataframe and a function to extract data
# from a dataframe and a particular column
function apply_to_column(df, f)
    res = OrderedDict()
    for (k, v) in predicates
        res[k] = f(df, k)
    end
    return res
end

# number of households that match a criteria
number_of_households = apply_to_column(hhlds, (df, c) -> sum(df[!, c]))

# fraction of households that match a criteria
number_of_households_ratio = apply_to_column(hhlds, (df, c) -> number_of_households[c] / nrow(df))

# number of people in households
number_of_people = apply_to_column(hhlds, (df, c) -> sum(df.size[df[!, c]]))

# number of people in households
number_of_people_ratio = apply_to_column(hhlds, (df, c) -> sum(df.size[df[!, c]]) / sum(df.size))

# contribution by size
contribution_by_size_ratio = apply_to_column(hhlds, (df, c) -> mean_contribution_per_type[c] / number_of_households_ratio[c])

# contribution by people 
contribution_by_people_ratio = apply_to_column(hhlds, (df, c) -> mean_contribution_per_type[c] / number_of_people_ratio[c])

# --> PLOT RELATIVE CONTRIBUTION BY NUMBER OF PEOPLE IN GROUP

# plot bar chart of relative contribution
# by number of people per affected hh type
p_relative_contribution = DataFrame(
    label = collect(keys(contribution_by_people_ratio)),
    value = collect(values(contribution_by_people_ratio))
) |>
    x -> sort(x, :value, rev = true) |>
    x -> bar( x.value, xrotation=90,
        xticks=(1:length(x.label), x.label),
        tickfontsize = 12,
        bottom_margin = 50mm,
        size = (2000, 800))

png(p_relative_contribution, joinpath(folder, "relative_contribution_per_type_and_number_of_people.png"))


# --> PLOT CONTRIBUTION BY SIZE AND COMPOSITION

# helper functions to access ordered dict's keys and values by index
key_id(od, id) = collect(keys(od))[id]
val_id(od, id) = collect(values(od))[id]
val_range(od, range) = (v -> val_id(od, v)).(collect(range))

num_of_sizes = length(size_predicates)
num_of_compositions = length(composition_predicates)

# point labels taken from composition predicates
labels = collect(keys(composition_predicates))
# color palette
#colors = palette(:Set1, num_of_compositions)
colors = distinguishable_colors(14)

plts = []
for i in 1:length(size_predicates)
    # extract values from flat ordered dictionaries
    filter_range = ((i-1) * num_of_compositions + 1):(i * num_of_compositions)
    contributions = val_range(mean_contribution_per_type, filter_range)
    people = val_range(number_of_people_ratio, filter_range)
    
    show_x = i >= 5
    show_y = (i-1) % 4 == 0

    p = plot(
        xformatter = show_x ? x -> "$(Int64(round(100 * x)))%" : :none,
        yformatter = show_y ? y -> "$(Int64(round(100 * y)))%" : :none,
        xlabelfontsize = 18,
        ylabelfontsize = 18,
        xlabel = show_x ? "% of people living in \n this HH type" : "",
        ylabel = show_y ? "% of infection chains\n involving this HH type" : "",
        leftmargin = show_y ? 15mm : 0mm,
        bottommargin = show_x ? 15mm : 0mm,
        tickfontsize = 14,
        titlefontsize = 20,
        xlims = (0, 1.1), 
        ylims = (0, 1.1),
        title = val_id(size_predicates, i)[2],
        legend = false
    )

    for x in eachindex(contributions)
        scatter!(p, [people[x]], [contributions[x]],
            color = colors[x],
            markerstrokewidth=0,
            markersize= 12,
            label = val_id(composition_predicates,x)[2]
        )
    end

    push!(plts, p)
   
end

# add "ghost" plot for legend only
gp = plot(
    xlims = (0,1),
    ylims = (0,1),
    framestyle=:none,
    legendfontsize = 13,
    legend=:bottomleft,
    bottommargin = 5mm
)
cnt = 1
for (k, p) in composition_predicates
    scatter!(gp, [0.5],[0.5],
        color = colors[cnt],
        markerstrokewidth=0,
        label = p[2])
    cnt += 1
end

push!(plts, gp)

p = plot(plts...,
    fontfamily = "Times Roman",
    size = (2000, 1000),
    layout = (2, 4))

png(p, joinpath(folder, "contribution_analysis.png"))


#####
#####
##### SIMULATIONS
#####
#####

# all predicate (size-limit-composition) combinations
sim_predicates = OrderedDict()
for (s, p1) in size_limit_predicates
    for (c, p2) in composition_predicates
        sim_predicates["$(s)_$c"] = ((h, sim) -> (p1[1](h, sim) && p2[1](h, sim)), "$(p1[2]); $(p2[2])")
    end
end

# adds the household isolation scenario
# to a simulation object and conditions
# the execution on the provided predicate
# function (that takes the household and
# the sim object)
function scenario(sim, predicate)

    quarantine_person = IStrategy("quarantine_person", sim)
    add_measure!(quarantine_person, SelfIsolation(quarantine_duration))

    find_hh_members = SStrategy("find_members", sim, condition = h -> predicate(h, sim)) # apply only to selected households
    add_measure!(find_hh_members, FindMembers(quarantine_person))

    find_household = IStrategy("find_household", sim)
    add_measure!(find_household, FindSetting(Household, find_hh_members))

    st = SymptomTrigger(find_household)
    add_symptom_trigger!(sim, st)
end

# run simulations per predicate
res = Dict{String, ResultData}()
for (k, p) in sim_predicates
    for i in 1:num_of_scenario_sims    
        try # try-catch block is important so the stuff don't crash if run without geolocalized test-model
            sim = init_sim()
            sim.label = k
            scenario(sim, p[1])
            run!(sim)
            rd = ResultData(sim, style = "CustomRD")
            res[k] = rd
        catch
        end
    end
end


# gemsplot(collect(values(res)), type = (:TickCases, :CumulativeCases, :EffectiveReproduction), size = (1000, 1500))

# gemsplot(collect(values(res))[1], type = :CumulativeDiseaseProgressions)

# store simulation data
JLD2.save_object(joinpath(folder, "sim_data.jld2"), res)
