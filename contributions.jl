# returns the infection ids caused by a source infection
function get_infections(df, source_id)
    return df[df.source .== source_id, :target]
end

# returns a dictionary with each household (that followed after the
# provided source infection id) # as key and the value which is the
# number of infections that can be traced back to any of the members
# of the key-household
function contribution(df, hh_lookup, source_id)::Dict{Int32, Int64}
    children = get_infections(df, source_id)

    # if household has no secondary infections, return empty dict
    if isempty(children)
        return Dict{Int32, Int64}(hh_lookup[source_id] => 0)
    end

    val = 0 # value for this node
    res = Dict{Int32, Int64}() # result dictionary

    for c in children
        c_h = hh_lookup[c] # child hh number
        cont = contribution(df, hh_lookup, c)
        for (h, i) in cont
            if haskey(res, h)
                res[h] += i
            else
                res[h] = i
            end
        end
        val += cont[c_h] + 1
    end
    res[hh_lookup[source_id]] = val
    
    return res
end

# returns a dictionary with each household of the infections dataframe
# as key and the value which is the number of infections that can be
# traced back to any of the members of the key-household
function rec_contributions(df)

    # household lookup
    hh_lookup = df |>
        x -> groupby(x, :target) |>
        x -> combine(x, :hh_id => first => :hh_id) |>
        x -> Dict(x.target .=> x.hh_id)
    
    # initial infections
    init_infections = get_infections(df, -1)

    # merge initial results
    res = Dict{Int32, Int64}()

    for inf in init_infections
        cont = contribution(df, hh_lookup, inf)
        for (h, i) in cont
            if haskey(res, h)
                res[h] += i
            else
                res[h] = i
            end
        end
    end

    return res
end


# calculates contribution to infection dynamics per household
# based on the infections-dataframe which comes out of the PostProcessor
function household_contribution(input_infs)
    total_infections = nrow(input_infs)

    # format input dataframe
    df = input_infs |>
        x -> DataFrames.select(x,
            :source_infection_id => :source,
            :infection_id => :target,
            :household_b => :hh_id)

    # run recursive contribution calculation
    cont = rec_contributions(df)
    
    # make result dictionary into dataframe
    infs = DataFrame(
        hh_id = collect(keys(cont)),
        hh_contribution = collect(values(cont))
    )

    infs.hh_contribution_ratio = infs.hh_contribution ./ total_infections

    return infs
end