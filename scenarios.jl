using GEMS, DataFrames, Plots



sim = Simulation()
run!(sim)

pp = PostProcessor(sim)
infs = infections(pp)

# dataframe with household information
hhlds = DataFrame(
    id = id.(households(sim)),
    size = size.(households(sim))
)


# calculates contribution to infection dynamics per household
function household_contribution(input_infs)
    total_infections = nrow(input_infs)

    infs = input_infs |>
        x -> sort(x, :infection_id) |>
        x -> DataFrames.select(x, :source_infection_id, :infection_id, :household_b => :hh_id)

    # calculate the number of infections that
    # happen in the infection graph after each
    # individual (we call that "contribution")
    infs.ind_contribution = fill(0, nrow(infs))
    for i in nrow(infs):-1:1
        val = 0
        for j in infs.infection_id[infs.source_infection_id .== i]
            val += 1 + infs.ind_contribution[j]
        end
        infs.ind_contribution[i] = val
    end

    # add all individual contributions
    infs = infs |>
        x -> groupby(x, :hh_id) |>
        x -> combine(x, :ind_contribution => sum => :hh_contribution)

    infs.hh_contribution_ratio = infs.hh_contribution ./ total_infections

    return infs
end


contributions = household_contribution(infs)


histogram(contributions.hh_contribution_ratio)

infs |> vscodedisplay