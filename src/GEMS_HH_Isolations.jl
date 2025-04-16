module GEMS_HH_Isolations

    using GEMS, DataFrames, Plots, Statistics, StatsPlots
    using Printf, Distributions, Dates, Proj, JLD2, Measures
    using DataStructures, Colors, CSV, GLM, TOML, Revise

    export run_experiments

    # INLCUDES
    include("predicates.jl")
    include("contributions.jl")
    include("contact_sampling.jl")
    include("model_analysis.jl")
    include("result_data_style.jl")
    include("output_analysis.jl")


    function run_experiments(;
        num_of_baseline_sims = 10,
        num_of_scenario_sims = 10,
        quarantine_duration = 14,
        input_config = "models/SL_model_R0_3.26.toml",
        population_model = "SL"
    )

        # RESULT FOLDER
        folder = joinpath("results", "$(Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM-SS_sss"))")
        mkpath(folder)

        #####
        ##### GLOBAL PARAMETERS
        #####



        ##### 
        ##### RUNNING BASELINE SIMULATIONS
        #####

        printinfo("START RUNNING BASELINE SIMULATIONS")

        # function to initialize the test simulation
        init_sim() = Simulation(input_config, population_model)
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

        # one single baseline simulation to run model analyse
        baseline_sim = init_sim()


        #####
        ##### BASELINE ANALYSIS
        #####

        # --> BASELINE OUTCOMES

        baseline_outcomes = outcomes.(baseline_rds) |> df_from_outcomes |> summarize_outcomes
        JLD2.save_object(joinpath(folder, "baseline_outcomes.jld2"), baseline_outcomes)

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
                title = "Effective Reproduction Number",
                titlefontsize = 12,
                ylabel = ""),
            gemsplot(baseline_rds[1], type = :CumulativeDiseaseProgressions,
                plot_title = "",    
                title = "Disease States",
                titlefontsize = 12,
                ylabel = ""),
            layout = (1, 3),
            size = (1200, 300),
            fontfamily = "Times Roman",
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
            fontfamily = "Times Roman",
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
            "all_compositions"         => (all_sizes,                  "all compositions",                    :circle, :black),    
            # school
            "w_schoolkids"             => (w_schoolkids,               "with schoolkids",                     :circle,    :red),
            #"w_1_schoolkid"            => (w_1_schoolkid,              "with 1 schoolkid",                    :square,    :red),
            "w_2plus_schoolkid"        => (w_2plus_schoolkids,         "with 2+ schoolkids",                  :utriangle, :red),
            "wo_schoolkids"            => (wo_schoolkids,              "without schoolkids",                  :dtriangle, :red),
            "multiple_schools"         => (multiple_schools,           "with kids in multiple schools",       :diamond,   :red),
            "big_schools"              => (big_schools,                "with 1+ kid in big schools",          :pentagon,  :red),
            #workers
            "w_workers"                => (w_workers,                  "with workers",                        :circle,    :blue),
            #"w_1_worker"               => (w_1_worker,                 "with 1 worker",                       :square,    :blue),
            "w_2plus_worker"           => (w_2plus_workers,            "with 2+ workers",                     :utriangle, :blue),
            "wo_workers"               => (wo_workers,                 "without workers",                     :dtriangle, :blue),
            # combinations
            "w_schoolkids_w_workers"   => (w_schoolkids_w_workers,     "with schoolkids; with workers",       :circle,    :orange),
            #"w_schoolkids_wo_workers"  => (w_schoolkids_wo_workers,    "with schoolkids; without workers",    :square),
            "wo_schoolkids_w_workers"  => (wo_schoolkids_w_workers,    "without schoolkids; with workers",    :diamond,   :orange),
            "wo_schoolkids_wo_workers" => (wo_schoolkids_wo_workers,   "without schoolkids; without workers", :pentagon,  :orange),
        )

        # predicate functions that filter for minimum-size-based
        # household types "identifier" => (function(h, sim), label)
        size_limit_predicates = OrderedDict(
            "all_sizes"                => (all_sizes,                  "all sizes"),
            "i2plus"                   => (i2plus,                     "2+ persons"),
            "i3plus"                   => (i3plus,                     "3+ persons"),
            "i4plus"                   => (i4plus,                     "4+ persons"),
            "i5plus"                   => (i5plus,                     "5+ persons"),
            "i6plus"                   => (i6plus,                     "6+ persons")
        )

        # all predicate (size-composition) combinations
        predicates = OrderedDict()
        for (s, p1) in size_limit_predicates
            for (c, p2) in composition_predicates
                predicates["$(s)_$c"] = ((h, sim) -> (p1[1](h, sim) && p2[1](h, sim)), "$(p1[2]); $(p2[2])", p2[3], p2[4])
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

        printinfo("START CALCULATING INFECTION CONTRIBUTIONS")

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
                println(subinfo("Infection contribution of $k"))
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
        ##### CALCULATE DEATH CONTRIBUTIONS
        #####

        printinfo("START CALCULATING DEATH CONTRIBUTIONS")

        # calculate death contributions for each of the baseline runs
        death_contribution_per_type = OrderedDict[]
        for infs in baseline_infections

            # join infections dataframe with household predicate data
            joined_df = infs |>
                x -> DataFrames.select(x, :source_infection_id, :infection_id, :death_tick, :household_b => :hh_id) |>
                x -> leftjoin(x, hhlds, on = :hh_id) |>
                x -> sort(x, :infection_id)

            # rename household IDs to only "true" or "false", depending
            # on whether they match the predicates. This will cause the
            # household-contribution function to calculate the fraction 
            # of infections that involve this household type at any point
            res = OrderedDict()
            for (k ,v) in predicates
                println(subinfo("Death contribution of $k"))
                joined_df |>
                    x -> DataFrames.select(x, :source_infection_id, :infection_id, :death_tick, Symbol(k) => :household_b) |>
                    x -> household_contribution_deaths(x) |>
                    x -> x.hh_contribution_ratio[x.hh_id] |>
                    x -> res[k] = length(x) == 0 ? 0 : first(x) # set 0 if no contribution was found
            end

            push!(death_contribution_per_type, res)    
        end

        # store JLD object
        JLD2.save_object(joinpath(folder, "death_contribution_per_type.jld2"), death_contribution_per_type)


        # calculate mean over all contribution calculations
        mean_death_contribution_per_type = OrderedDict()
        for (k, p) in predicates
            mean_death_contribution_per_type[k] = mean([conts[k] for conts in death_contribution_per_type])
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

        # death contribution by infection contribution
        death_contribution_by_infection_contribution_ratio = apply_to_column(hhlds, (df, c) -> mean_death_contribution_per_type[c] / mean_contribution_per_type[c])


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
                tickfontsize = 11,
                bottom_margin = 50mm,
                size = (2000, 800),
                fontfamily = "Times Roman",)

        png(p_relative_contribution, joinpath(folder, "relative_contribution_per_type_and_number_of_people.png"))

        # --> PLOT RELATIVE DEATH CONTRIBUTION BY RELATIVE INFECTION CONTRIBUTION

        # plot bar chart of relative death contribution
        # by relative infection contribution
        p_relative_death_contribution = DataFrame(
            label = collect(keys(death_contribution_by_infection_contribution_ratio)),
            value = collect(values(death_contribution_by_infection_contribution_ratio))
        ) |>
            x -> sort(x, :value, rev = true) |>
            x -> bar(x.value, xrotation=90,
                xticks=(1:length(x.label), x.label),
                tickfontsize = 12,
                bottom_margin = 50mm,
                size = (2000, 800))

        png(p_relative_death_contribution, joinpath(folder, "relative_death_contr_by_infection_contr.png"))


        # --> PLOT INFECTION CONTRIBUTION BY SIZE AND COMPOSITION

        # helper functions to access ordered dict's keys and values by index
        key_id(od, id) = collect(keys(od))[id]
        val_id(od, id) = collect(values(od))[id]
        val_range(od, range) = (v -> val_id(od, v)).(collect(range))
        getsize(sc, pred, compos) = ((findfirst(x -> x == sc, collect(keys(pred))) / length(compos)) + 1) |> floor |> Int



        num_of_sizes = length(size_predicates)
        num_of_compositions = length(composition_predicates)

        # point labels taken from composition predicates
        labels = collect(keys(composition_predicates))
        # color palette
        #colors = palette(:Set1, num_of_compositions)
        colors = distinguishable_colors(length(composition_predicates))
        shapes = []


        plts = []
        for i in 1:length(size_limit_predicates)
            # extract values from flat ordered dictionaries
            filter_range = ((i-1) * num_of_compositions + 1):(i * num_of_compositions)
            contributions = val_range(mean_contribution_per_type, filter_range)
            people = val_range(number_of_people_ratio, filter_range)
            
            show_x = i >= 4
            show_y = (i-1) % 3 == 0

            p = plot(
                xformatter = show_x ? x -> "$(Int64(round(100 * x)))%" : :none,
                yformatter = show_y ? y -> "$(Int64(round(100 * y)))%" : :none,
                xlabelfontsize = 20,
                ylabelfontsize = 20,
                xlabel = show_x ? "% of people living in \n this HH type" : "",
                ylabel = show_y ? "% of infection chains\n involving this HH type" : "",
                leftmargin = show_y ? 15mm : 0mm,
                bottommargin = show_x ? 15mm : 0mm,
                tickfontsize = 14,
                titlefontsize = 20,
                xlims = (0, 1.1), 
                ylims = (0, 1.1),
                title = val_id(size_limit_predicates, i)[2],
                legend = false
            )

            for x in eachindex(contributions)
                scatter!(p, [people[x]], [contributions[x]],
                    color = val_id(composition_predicates,x)[4],
                    markerstrokewidth=0,
                    markersize= 10,
                    marker=(val_id(composition_predicates,x)[3]),
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
            legendfontsize = 14,
            legend=:left,
            bottommargin = 5mm
        )
        cnt = 1
        for (k, p) in composition_predicates
            scatter!(gp, [0.5],[0.5],
                color = p[4],
                markerstrokewidth=0,
                marker=(p[3]),
                label = p[2])
            cnt += 1
        end

        push!(plts, gp)

        l = @layout [
            [grid(2,3)] a{0.22w}
        ]

        p = plot(plts...,
            fontfamily = "Times Roman",
            size = (2000, 1000),
            #layout = (2, 4))
            layout = l)


        png(p, joinpath(folder, "contribution_analysis.png"))

        # --> PLOT DEATH CONTRIBUTION BY SIZE AND COMPOSITION

        num_of_sizes = length(size_predicates)
        num_of_compositions = length(composition_predicates)

        # point labels taken from composition predicates
        labels = collect(keys(composition_predicates))
        # color palette
        #colors = palette(:Set1, num_of_compositions)
        colors = distinguishable_colors(length(composition_predicates))
        shapes = []


        plts = []
        for i in 1:length(size_limit_predicates)
            # extract values from flat ordered dictionaries
            filter_range = ((i-1) * num_of_compositions + 1):(i * num_of_compositions)
            contributions = val_range(mean_contribution_per_type, filter_range)
            people = val_range(number_of_people_ratio, filter_range)
            
            show_x = i >= 4
            show_y = (i-1) % 3 == 0

            p = plot(
                xformatter = show_x ? x -> "$(Int64(round(100 * x)))%" : :none,
                yformatter = show_y ? y -> "$(Int64(round(100 * y)))%" : :none,
                xlabelfontsize = 20,
                ylabelfontsize = 20,
                xlabel = show_x ? "% of people living in \n this HH type" : "",
                ylabel = show_y ? "% of infection chains\n involving this HH type" : "",
                leftmargin = show_y ? 15mm : 0mm,
                bottommargin = show_x ? 15mm : 0mm,
                tickfontsize = 14,
                titlefontsize = 20,
                xlims = (0, 1.1), 
                ylims = (0, 1.1),
                title = val_id(size_limit_predicates, i)[2],
                legend = false
            )

            for x in eachindex(contributions)
                scatter!(p, [people[x]], [contributions[x]],
                    color = val_id(composition_predicates,x)[4],
                    markerstrokewidth=0,
                    markersize= 10,
                    marker=(val_id(composition_predicates,x)[3]),
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
            legendfontsize = 14,
            legend=:left,
            bottommargin = 5mm
        )
        cnt = 1
        for (k, p) in composition_predicates
            scatter!(gp, [0.5],[0.5],
                color = p[4],
                markerstrokewidth=0,
                marker=(p[3]),
                label = p[2])
            cnt += 1
        end

        push!(plts, gp)

        l = @layout [
            [grid(2,3)] a{0.22w}
        ]

        p = plot(plts...,
            fontfamily = "Times Roman",
            size = (2000, 1000),
            #layout = (2, 4))
            layout = l)


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
        res = ResultData[]
        cnt = 0
        for (k, p) in sim_predicates
            for i in 1:num_of_scenario_sims
                printinfo("Running simulation $(cnt += 1)/$(length(sim_predicates) * num_of_scenario_sims)")
                try # try-catch block is important so the stuff don't crash if run without geolocalized test-model
                    sim = init_sim()
                    sim.label = k
                    scenario(sim, p[1])
                    run!(sim)
                    rd = ResultData(sim, style = "CustomRD")
                    push!(res, rd)
                catch
                end
            end
        end

        # store simulation data
        JLD2.save_object(joinpath(folder, "sim_data.jld2"), res)


        #####
        ##### SIMULATION RESULT ANALYSIS
        #####

        # build dataframe of outcomes
        sim_outcomes = outcomes.(res) |> df_from_outcomes |> summarize_outcomes

        # calculate differences to baseline
        sim_diffs = calc_diff(outcomes.(res) |> df_from_outcomes |> summarize_outcomes, baseline_outcomes)



        # find pareto optimal frontier of effectiveness and efficiency
        quarantine_pareto = sim_diffs |>
            x -> DataFrames.select(x, :scenario, :r0_diff, :deaths_diff, :quarantine_days, :lost_schooldays, :lost_workdays) |>
            x -> x[x.r0_diff .>= 0, :] # filter values with positive R-Reduction

        quarantine_pareto.quarantine_pareto_optimal = fill(false, nrow(quarantine_pareto))
        quarantine_pareto.schooldays_pareto_optimal = fill(false, nrow(quarantine_pareto))
        quarantine_pareto.workdays_pareto_optimal = fill(false, nrow(quarantine_pareto))
        quarantine_pareto.quarantine_color = fill(:lightgrey, nrow(quarantine_pareto))
        quarantine_pareto.schooldays_color = fill(:lightgrey, nrow(quarantine_pareto))
        quarantine_pareto.workdays_color = fill(:lightgrey, nrow(quarantine_pareto))
        quarantine_pareto.quarantine_shape = fill(:circle, nrow(quarantine_pareto))
        quarantine_pareto.schooldays_shape = fill(:circle, nrow(quarantine_pareto))
        quarantine_pareto.workdays_shape = fill(:circle, nrow(quarantine_pareto))
        quarantine_pareto.quarantine_dotsize = fill(3.0, nrow(quarantine_pareto))
        quarantine_pareto.schooldays_dotsize = fill(3.0, nrow(quarantine_pareto))
        quarantine_pareto.workdays_dotsize = fill(3.0, nrow(quarantine_pareto))


        for i in 1:nrow(quarantine_pareto)
            r_diff = quarantine_pareto.r0_diff[i]
            q_days = quarantine_pareto.quarantine_days[i]
            s_days = quarantine_pareto.lost_schooldays[i]
            w_days = quarantine_pareto.lost_workdays[i]

            # total quarantines
            if quarantine_pareto.scenario[
                quarantine_pareto.r0_diff .> r_diff .&&
                quarantine_pareto.quarantine_days .<= q_days] |> isempty    
                quarantine_pareto.quarantine_pareto_optimal[i] = true
            end

            # total lost school days
            if quarantine_pareto.scenario[
                quarantine_pareto.r0_diff .> r_diff .&&
                quarantine_pareto.lost_schooldays .<= s_days] |> isempty     
                quarantine_pareto.schooldays_pareto_optimal[i] = true
            end

            # total lost work days
            if quarantine_pareto.scenario[
                quarantine_pareto.r0_diff .> r_diff .&&
                quarantine_pareto.lost_workdays .<= w_days] |> isempty 
                quarantine_pareto.workdays_pareto_optimal[i] = true
            end
        end


        # color dots
        for i in 1:nrow(quarantine_pareto)

            sc = quarantine_pareto.scenario[i]

            if quarantine_pareto.quarantine_pareto_optimal[i]
                quarantine_pareto.quarantine_color[i] = predicates[sc][4]
                quarantine_pareto.quarantine_shape[i] = predicates[sc][3]
                quarantine_pareto.quarantine_dotsize[i] = 11 - 1.3 * getsize(sc, predicates, composition_predicates)
            end

            if quarantine_pareto.schooldays_pareto_optimal[i]
                quarantine_pareto.schooldays_color[i] = predicates[sc][4]
                quarantine_pareto.schooldays_shape[i] = predicates[sc][3]
                quarantine_pareto.schooldays_dotsize[i] = 11 - 1.3  *  getsize(sc, predicates, composition_predicates)
            end

            if quarantine_pareto.workdays_pareto_optimal[i]
                quarantine_pareto.workdays_color[i] = predicates[sc][4]
                quarantine_pareto.workdays_shape[i] = predicates[sc][3]
                quarantine_pareto.workdays_dotsize[i] = 11 - 1.3  *  getsize(sc, predicates, composition_predicates)
            end
        end


        p_xlims = (-0.1 * maximum(quarantine_pareto.quarantine_days), maximum(quarantine_pareto.quarantine_days) * 1.1)
        p_ylims = (-0.1 * maximum(quarantine_pareto.r0_diff) * 1.1, maximum(quarantine_pareto.r0_diff) * 1.1)

        p_quarantine = scatter(quarantine_pareto.quarantine_days, quarantine_pareto.r0_diff,
            color = quarantine_pareto.quarantine_color,
            legend = false,
            markerstrokewidth = 0,
            marker = quarantine_pareto.quarantine_shape,
            markersize= quarantine_pareto.quarantine_dotsize,
            #xlims = p_xlims,
            ylims = p_ylims,
            ylabel = "R0-Reduction",
            xlabel = "Cumulative Quarantine Days",
            size = (600, 800))

        p_schooldays = scatter(quarantine_pareto.lost_schooldays, quarantine_pareto.r0_diff,
            color = quarantine_pareto.schooldays_color,
            legend = false,
            markerstrokewidth = 0,
            marker = quarantine_pareto.schooldays_shape,
            markersize= quarantine_pareto.schooldays_dotsize,
            #xlims = p_xlims,
            ylims = p_ylims,
            ylabel = "R0-Reduction",
            xlabel = "Cumulative Lost School Days")

        p_workdays = scatter(quarantine_pareto.lost_workdays, quarantine_pareto.r0_diff,
            color = quarantine_pareto.workdays_color,
            legend = false,
            markerstrokewidth = 0,
            marker = quarantine_pareto.workdays_shape,
            markersize= quarantine_pareto.workdays_dotsize,
            #xlims = p_xlims,
            ylims = p_ylims,
            ylabel = "R0-Reduction",
            xlabel = "Cumulative Lost Workdays Days")


        # p_deaths = scatter(quarantine_pareto.quarantine_days, quarantine_pareto.deaths_diff,
        #     color = :lightgrey,
        #     title = "Deaths",
        # #   size = (800, 600),
        #     legend = false,
        #     markerstrokewidth = 0,
        #     ylabel = "Saved Lives",
        #     xlabel = "Cumulative Quarantine Days")


        p_pareto = plot(
            p_quarantine,
            gp,
            p_schooldays,
            p_workdays,
            layout = (2,2),
            size = (1200, 1000),
            left_margin = 6mm,
            bottom_margin = 10mm,
            fontfamily = "Times Roman",
            labelfontsize = 16,
            tickfontsize = 10,
        )

        png(p_pareto, joinpath(folder, "pareto_fronts.png"))


        #####
        ##### COMBINE ALL DATAFRAMES
        #####

        #=
        COLUMNS:
            1.  scenario: scenario identifier
            2.  label: label of the scenario (for printing)
            3.  mean_contribution_rate: mean contribution over all simulation runs
            4.  mean_death_contribution_rate: mean death contribution over all simulation runs
            5.  number_of_households: number of households that match the predicate
            6.  number_of_households_ratio: fraction of households that match the predicate
            7.  number_of_people: number of people in the population that match the predicate
                (i.e., that live in a household that matches the predicate)
            8.  number_of_people_ratio: fraction of people in the population that match the predicate
                (i.e., that live in a household that matches the predicate)
            9.  contribution_by_size_ratio: mean contribution per household size
            10. contribution_by_people_ratio: mean contribution per person
            11. death_contribution_by_infection_contribution_ratio: mean death contribution per infection contribution
                (>1 means, infections caused by that household type result in more deaths, <1 means less deaths)
            12. r0: average R0 of the scenario
            13. infections: average number of infections in the scenario
            14. deaths: average number of deaths in the scenario
            15. quarantine_days: average number of quarantine days in the scenario
            16. lost_schooldays: average number of lost school days in the scenario
            17. lost_workdays: average number of lost work days in the scenario
            18. lost_otherdays: average number of lost other days (not school && not work) in the scenario
            19. r0_diff: average difference in R0 between baseline and scenario
            20. infections_diff: average difference in infections between baseline and scenario
            21. deaths_diff: average difference in deaths between baseline and scenario
            22. quarantine_days_diff: average difference in quarantine days between baseline and scenario
            23. lost_schooldays_diff: average difference in lost school days between baseline and scenario
            24. lost_workdays_diff: average difference in lost work days between baseline and scenario
            25. lost_otherdays_diff: average difference in lost other days (not school && not work) between baseline and scenario
            26. qdays_per_r0_diff: average number of quarantine days per R0 reduction of 0.1
            27. q_ratio_school: number of lost school days as part of qdays_per_r0_diff
            28. q_ratio_work: number of lost work days as part of qdays_per_r0_diff
            29. q_ratio_other: number of lost other days as part of qdays_per_r0_diff
            30. quarantine_pareto_optimal: boolean value indicating whether the scenario is
                pareto optimal with regards to total quarantine days
            31. schooldays_pareto_optimal: boolean value indicating whether the scenario is
                pareto optimal with regards to lost school days
            32. workdays_pareto_optimal: boolean value indicating whether the scenario is
                pareto optimal with regards to lost work days
        =#

        combined_df = DataFrame(
            scenario = collect(keys(predicates)),
            label = (p -> p[2]).(collect(values(predicates)))
        ) |>
            df -> leftjoin(df,
                DataFrame(
                    scenario = collect(keys(mean_contribution_per_type)),
                    mean_contribution_rate = collect(values(mean_contribution_per_type))
                ), on = :scenario) |>
            df -> leftjoin(df,
                DataFrame(
                    scenario = collect(keys(mean_death_contribution_per_type)),
                    mean_death_contribution_rate = collect(values(mean_death_contribution_per_type))
                ), on = :scenario) |>
            df -> leftjoin(df,
                DataFrame(
                    scenario = collect(keys(number_of_households)),
                    number_of_households = collect(values(number_of_households))
                ), on = :scenario) |>
            df -> leftjoin(df,
                DataFrame(
                    scenario = collect(keys(number_of_households_ratio)),
                    number_of_households_ratio = collect(values(number_of_households_ratio))
                ), on = :scenario) |>
            df -> leftjoin(df,
                DataFrame(
                    scenario = collect(keys(number_of_people)),
                    number_of_people = collect(values(number_of_people))
                ), on = :scenario) |>
            df -> leftjoin(df,
                DataFrame(
                    scenario = collect(keys(number_of_people_ratio)),
                    number_of_people_ratio = collect(values(number_of_people_ratio))
                ), on = :scenario) |>
            df -> leftjoin(df,
                DataFrame(
                    scenario = collect(keys(contribution_by_size_ratio)),
                    contribution_by_size_ratio = collect(values(contribution_by_size_ratio))
                ), on = :scenario) |>
            df -> leftjoin(df,
                DataFrame(
                    scenario = collect(keys(contribution_by_people_ratio)),
                    contribution_by_people_ratio = collect(values(contribution_by_people_ratio))
                ), on = :scenario) |>
            df -> leftjoin(df,
                DataFrame(
                    scenario = collect(keys(death_contribution_by_infection_contribution_ratio)),
                    death_contribution_by_infection_contribution_ratio = collect(values(death_contribution_by_infection_contribution_ratio))
                ), on = :scenario) |>
            df -> leftjoin(df, sim_diffs, on = :scenario) |> 
            df -> leftjoin(df,
                DataFrames.select(quarantine_pareto,
                    :scenario, :quarantine_pareto_optimal, :schooldays_pareto_optimal, :workdays_pareto_optimal
                ), on = :scenario)

        # export CSV document in output folder
        CSV.write(joinpath(folder, "combined_scenario_data.csv"), combined_df)



        #####
        ##### PLOT CONTRIBUTION BY PEOPLE RATIO VS QUARANTINE DAYS PER R0 REDUCTION
        #####

        # linear regression model
        model = lm(@formula(qdays_per_r0_diff ~ contribution_by_people_ratio), combined_df)

        # Extract coefficients
        intercept = coef(model)[1]
        slope = coef(model)[2]

        p_r0eff_by_CR = combined_df |>
            df -> df[df.qdays_per_r0_diff .>= 0, :] |>
            df -> scatter(
                df.contribution_by_people_ratio, df.qdays_per_r0_diff,
                #color = (sc -> predicates[sc][4]).(df.scenario),
                color = :black,
                #legend = false,
                label = "Quarantine Scenarios",
                size = (1400, 600),
                markerstrokewidth = 0,
                #marker = (sc -> predicates[sc][3]).(df.scenario),
                #markersize = 3 .+ 5 .* df.number_of_people_ratio,
                #markersize = 20 .* df.infections_at_home,
                markersize = (sc -> (2 + 1.1 * getsize(sc, predicates, composition_predicates))).(df.scenario),
                fontfamily = "Times Roman",
                labelfontsize = 16,
                tickfontsize = 10,
                legendfontsize = 10,
                left_margin = 8mm,
                bottom_margin = 8mm,
                #xlims = (1, 1.1 * maximum(df.contribution_by_people_ratio)),
                ylims = (0, 1.1 * maximum(df.qdays_per_r0_diff)),
                ylabel = "Quarantine Days \n per 0.1 R0 Reduction",
                xlabel = "Contribution by People Ratio") |>
            # add trendline
            sc_p -> plot!(sc_p,
            combined_df.contribution_by_people_ratio,
                intercept .+ slope .* combined_df.contribution_by_people_ratio,
                color = :red,
                label = "Trendline",
                linewidth = 2,
                #linestyle = :dash,
            )

        png(p_r0eff_by_CR, joinpath(folder, "quarantine_day_efficiency_by_contribution_by_people_ratio.png"))


        # re-load data
        # folder = "results/2025-03-31_15-45-40_537"
        # baseline_outcomes = JLD2.load_object(joinpath(folder, "baseline_outcomes.jld2"))
        # contribution_per_type = JLD2.load_object(joinpath(folder, "contribution_per_type.jld2"))
        # death_contribution_per_type = JLD2.load_object(joinpath(folder, "death_contribution_per_type.jld2"))
        # combined_df = CSV.read(joinpath(folder, "combined_scenario_data.csv"), DataFrame)
        # baseline_rds = JLD2.load_object(joinpath(folder, "baseline_rds.jld2"))
        # res = JLD2.load_object(joinpath(folder, "sim_data.jld2"))

    end

end # module GEMS_HH_Isolations
