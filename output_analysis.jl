# creates dictionary with outcome variables from the output of a simulation
function outcomes(rd)
    return Dict(
        "scenario" => label(rd),
        "r0" => effectiveR(rd).effective_R[1:10] |> mean,
        "infections" => total_infections(rd),
        "deaths" => tick_deaths(rd).death_cnt |> sum,
        "quarantine_days" => cumulative_quarantines(rd).quarantined |> sum,
        "lost_workdays" => cumulative_quarantines(rd).workers |> sum,
        "lost_schooldays" => cumulative_quarantines(rd).students |> sum
    )
end

# builds a flat dataframe from a vector of outcome dictionaries
function df_from_outcomes(outcomes::Vector)
    res = DataFrame(
        scenario = [],
        r0 = [],
        infections = [],
        deaths = [],
        quarantine_days = [],
        lost_workdays = [],
        lost_schooldays = []
    )

    for o in outcomes
        push!(res, (o["scenario"], o["r0"], o["infections"], o["deaths"], o["quarantine_days"], o["lost_workdays"], o["lost_schooldays"]))
    end

    return res
end

# builds mean of outcomes dataframe (from rd objects of simulation runs)
function summarize_outcomes(outcomes_df)

    return outcomes_df |>
        x -> groupby(x, :scenario) |>
        x -> combine(x,
            :r0 => mean => :r0,
            :infections => mean => :infections,
            :deaths => mean => :deaths,
            :quarantine_days => mean => :quarantine_days,
            :lost_workdays => mean => :lost_workdays,
            :lost_schooldays => mean => :lost_schooldays
        )
end


function calc_diff(scenarios, baseline)
    return scenarios |>
        x -> transform(x,
            :r0 => ByRow(r -> baseline.r0[1] - r) => :r0_diff,
            :infections => ByRow(i -> baseline.infections[1] - i) => :infections_diff,
            :deaths => ByRow(d -> baseline.deaths[1] - d) => :deaths_diff,
            :quarantine_days => ByRow(q -> baseline.quarantine_days[1] - q) => :quarantine_days_diff,
            :lost_workdays => ByRow(w -> baseline.lost_workdays[1] - w) => :lost_workdays_diff,
            :lost_schooldays => ByRow(s -> baseline.lost_schooldays[1] - s) => :lost_schooldays_diff
        )
end