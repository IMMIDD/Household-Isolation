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






function household_contribution_2(input_infs)
    total_infections = nrow(input_infs)

    infs = input_infs |>
        x -> sort(x, :infection_id) |>
        x -> DataFrames.select(x, :source_infection_id, :infection_id, :household_b => :hh_id)

    # caclulate sets of distinct infections
    infection_sets = Dict(i => Set{Int}() for i in infs.infection_id)
    for i in nrow(infs):-1:1
        src = infs.source_infection_id[i]
        if src != -1
            push!(infection_sets[src], infs.infection_id[i])
            union!(infection_sets[src], infection_sets[infs.infection_id[i]]) 
        end
    end

    # merge individual sets into household sets
    hh_infection_sets = Dict(hh => Set{Int}() for hh in unique(infs.hh_id))
    for row in eachrow(infs)
        union!(hh_infection_sets[row.hh_id], infection_sets[row.infection_id])
    end

    # calculate household contributions
    hh_contributions = DataFrame(
        hh_id = collect(keys(hh_infection_sets)),
        hh_contribution = [length(v) for v in values(hh_infection_sets)]
    )
    hh_contributions.hh_contribution_ratio = hh_contributions.hh_contribution ./ total_infections
    sort!(hh_contributions, :hh_id)

    return hh_contributions
end







# union-find
function find(u)
    while parent[u] != u
        parent[u] = parent[parent[u]] 
        u = parent[u]
    end
    return u
end

function union(u, v)
    u_root = find(u)
    v_root = find(v)
    if u_root != v_root
        if size[u_root] < size[v_root]
            u_root, v_root = v_root, u_root
        end
        parent[v_root] = u_root
        size[u_root] += size[v_root]
    end
end


function household_contribution_union_find(input_infs)
    total_infections = nrow(input_infs)

    infs = input_infs |>
        x -> sort(x, :infection_id) |>
        x -> DataFrames.select(x, :source_infection_id, :infection_id, :household_b => :hh_id)

    # initialize union-find
    parent = Dict(i => i for i in infs.infection_id)  
    size = Dict(i => 1 for i in infs.infection_id) 

    # build union-find 
    for row in eachrow(infs)
        src = row.source_infection_id
        if src != -1
            union(src, row.infection_id)
        end
    end

    # identify root infections for each household
    hh_root_infections = Dict{Int, Set{Int}}()
    for row in eachrow(infs)
        hh_id = row.hh_id
        root = find(row.infection_id)
        if !haskey(hh_root_infections, hh_id)
            hh_root_infections[hh_id] = Set{Int}()
        end
        push!(hh_root_infections[hh_id], root)
    end

    # calculate household contributions
    hh_contributions = DataFrame(
        hh_id = Int[],
        hh_contribution = Int[],
        hh_contribution_ratio = Float64[]
    )
    for (hh_id, roots) in hh_root_infections
        total_size = sum(size[root] for root in roots)
        push!(hh_contributions, (hh_id, total_size, total_size / total_infections))
    end

    sort!(hh_contributions, :hh_id)

    return hh_contributions
end
