using TOML

mutable struct CustomRD <: GEMS.ResultDataStyle
    data::Dict{String, Any}
    function CustomRD(pP::PostProcessor)
        funcs = Dict(
            "meta_data" =>
                Dict(
                    #"timer_output" => () -> TimerOutput(),
                    "execution_date" => () -> Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                    #"GEMS_version" => () -> PkgVersion.Version(GEMS),
                    "config_file" => () -> pP |> simulation |> configfile,
                    "config_file_val" => () -> TOML.parsefile(pP |> simulation |> configfile),
                    "population_file" => () -> pP |> simulation |> populationfile,
                    "population_params" => () -> pP |> simulation |> population |> GEMS.params
                ),
            "sim_data" =>
                Dict(
                    "label" => () -> pP |> simulation |> label,    
                    "final_tick" => () -> pP |> simulation |> tick,
                    "number_of_individuals" => () -> pP |> simulation |> population |> individuals |> length,
                    "initial_infections" => () -> (pP |> infectionsDF |> nrow) - (pP |> sim_infectionsDF |> nrow),
                    "total_infections" => () -> pP |> infectionsDF |> nrow,
                    "total_deaths" => () -> (pP |> tick_deaths).death_cnt |> sum,
                    "attack_rate" => () -> pP |> attack_rate,
                    "setting_data" => () -> pP |> settingdata,
                    "setting_sizes" => () -> pP |> setting_sizes,
                    "region_info" => () -> pP |> simulation |> region_info,
                    "pathogens" => () -> [pP |> simulation |> pathogen],
                    "tick_unit" => () -> pP |> simulation |> tickunit,
                    "start_condition" => () -> pP |> simulation |> start_condition,
                    "stop_criterion" =>  () -> pP |> simulation |> stop_criterion,
                    "total_quarantines" => () -> pP |> total_quarantines,
                    "total_tests" => () -> pP |> total_tests,
                    "detection_rate" => () -> pP |> detection_rate
                ),
            
            # system data
            "system_data" => 
                Dict(
                    "kernel" => () -> String(Base.Sys.KERNEL) * String(Base.Sys.MACHINE),
                    "julia_version" => () -> string(Base.VERSION),
                    "word_size" => () -> Base.Sys.WORD_SIZE,
                    "threads" => () -> Threads.nthreads(),
                    "cpu_data" => () -> GEMS.cpudata(),
                    "total_mem_size" => () -> round(Sys.total_memory()/2^20, digits = 2),
                    "free_mem_size" => () -> round(Sys.free_memory()/2^20, digits = 2),
                    "git_repo" => () -> read_git_repo(),
                    "git_branch" => () -> read_git_branch(),
                    "git_commit" => () -> read_git_commit()#,
                ),

            "aggregated_setting_age_contacts" =>
                Dict(
                    # TODO: interval_steps shouldn't be hard coded. They rather should be defined in the config file.
                    # TODO: This list should be determined dynamically depending on what settings are present in the simulation
                    "Household" => () -> mean_contacts_per_age_group(pP, Household, 5),
                    "SchoolClass" => () -> mean_contacts_per_age_group(pP, SchoolClass, 2),
                    "School" => () -> mean_contacts_per_age_group(pP, School, 2),
                    "SchoolComplex" => () -> mean_contacts_per_age_group(pP, SchoolComplex, 2),
                    "Office" => () -> mean_contacts_per_age_group(pP, Office, 5), 
                    "Department" => () -> mean_contacts_per_age_group(pP, Department, 5), 
                    "Workplace" => () -> mean_contacts_per_age_group(pP, Workplace, 5), 
                    "WorkplaceSite" => () -> mean_contacts_per_age_group(pP, WorkplaceSite, 5), 
                    "Municipality" => () -> mean_contacts_per_age_group(pP, Municipality, 5),
                    "GlobalSetting" => () -> mean_contacts_per_age_group(pP, GlobalSetting, 5)
                ),

            "dataframes" =>
                Dict(
                    "effectiveR" => () -> pP |> effectiveR,
                    "tick_cases" => () -> pP |> tick_cases,
                    "tick_deaths" => () -> pP |> tick_deaths,
                    "tick_serial_intervals" => () -> pP |> tick_serial_intervals,
                    "tick_generation_times" => () -> pP |> tick_generation_times,
                    "cumulative_cases" => () -> pP |> cumulative_cases,
                    "compartment_fill" => () -> pP |> compartment_fill,
                    "aggregated_compartment_periods" => () -> pP |> aggregated_compartment_periods,
                    "cumulative_deaths" => () -> pP |> cumulative_deaths,
                    "age_incidence" => () -> age_incidence(pP, 7, 100_000),
                    "population_pyramid" => () -> pP |> population_pyramid,
                    "cumulative_disease_progressions" => () -> pP |> cumulative_disease_progressions,
                    "cumulative_quarantines" => () -> pP |> cumulative_quarantines,
                    "tick_tests" => () -> pP |> tick_tests,
                    "tick_pooltests" => () -> pP |> tick_pooltests,
                    "detected_tick_cases" => () -> pP |> detected_tick_cases,
                    "rolling_observed_SI" => () -> pP |> rolling_observed_SI,
                    "observed_R" => () -> pP |> observed_R,
                    "time_to_detection" => () -> pP |> time_to_detection,
                    "tick_cases_per_setting" => () -> pP |> tick_cases_per_setting,
                    "customlogger" => () -> pP |> simulation |> customlogger |> dataframe,
                    "household_attack_rates" => () -> pP |> household_attack_rates
                )
        )

        # call all provided functions and replace
        # the dicts with their return values
        return(
            new(GEMS.process_funcs(funcs))
        )
    end
end