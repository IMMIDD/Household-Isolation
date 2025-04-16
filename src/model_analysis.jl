# formats x-ticks in barcharts for size histograms
function format_xticks(data)
    res = []
    for i in eachindex(data)
        if i == length(data)
            push!(res,"$(data[i])+")
        else
            push!(res, "$(data[i])-\n$(data[i+1]-1)")
        end
    end
    return res
end


# returns the number of households of a given size
# combines all households larger than 7 into the 7 category
function hh_sizes(sim)
    flat = (s -> s > 6 ? 7 : s ).(size.(households(sim)))
    return DataFrame(
        size = sort(unique(flat)),
        cnt = [sum(flat .== x) for x in sort(unique(flat))]
    )
end


# returns the number of workplaces of a given size
# combines all households larger than 7 into the 7 category
function wp_sizes(sim, bin_size, limit)
    max_bin = Int(floor(limit / bin_size))
    flat = (w -> size(w, sim)).(workplaces(sim))
    flat = Int.(ceil.(flat ./ bin_size)) .- 1
    flat = (w -> w > max_bin ? max_bin : w).(flat)
    
    bins = collect(0:max_bin)
    
    return DataFrame(
        size = bins .* bin_size,
        cnt = [sum(flat .== x) for x in bins]
    )
end


# returns the number of schools of a given size
# combines all households larger than 7 into the 7 category
function s_sizes(sim, bin_size, limit)
    max_bin = Int(floor(limit / bin_size))
    flat = (s -> size(s, sim)).(schools(sim))
    flat = Int.(ceil.(flat ./ bin_size)) .- 1
    flat = (s -> s > max_bin ? max_bin : s).(flat)
    
    bins = collect(0:max_bin)
    
    return DataFrame(
        size = bins .* bin_size,
        cnt = [sum(flat .== x) for x in bins]
    )
end

# convert lan/lon to shapefile projection format
function convert_points(df)
    # projection transformation
    wgs84 = "+proj=longlat +datum=WGS84 +no_defs"
    dhdn_gk3 = """
    +proj=tmerc +lat_0=0 +lon_0=9 +k=1 +x_0=3500000 +y_0=0 +ellps=bessel
    +datum=potsdam +units=m +no_defs
    """
    trans = Proj.Transformation(wgs84, dhdn_gk3)

    pnts_tuples = []
    for row in eachrow(df)
        push!(pnts_tuples, trans(row.lon, row.lat))
    end

    return DataFrame(
        lon = first.(pnts_tuples),
        lat = last.(pnts_tuples)
    )
end

# plot settings on a map
function plot_settings(sim)

    # load municipalities
    muns = municipalities(sim)
    df = DataFrame(
        ags = ags.(muns),
        cnt = fill(0, length(muns))
    )

    # load settings (filer for settings in
    # any of the ags in municipality list)
    hhlds = households(sim)
    sclasses = schoolclasses(sim) |>
        sc -> sc[(c -> ags(c) in df.ags).(sc)]
    offcs = offices(sim) |>
        off -> off[(c -> ags(c) in df.ags).(off)]

    # geolocations
    hh_pnts = DataFrame(
        lat = lat.(hhlds),
        lon = lon.(hhlds)
    ) |> convert_points

    sc_pnts = DataFrame(
        lat = lat.(sclasses),
        lon = lon.(sclasses)
    ) |> convert_points

    off_pnts = DataFrame(
        lat = lat.(offcs),
        lon = lon.(offcs)
    ) |> convert_points

    # build base map
    p = agsmap(df, fillcolor = :reds, colorbar = false, size = (1500, 700))

    # add households
    scatter!(p, hh_pnts.lon, hh_pnts.lat,
        label = "Households",
        legendfontsize = 10,
        markerstrokewidth=0,
        markersize=1,
        markercolor = :black)

    # add schools
    scatter!(p, sc_pnts.lon, sc_pnts.lat,
        label = "Schools",
        legendfontsize = 10,
        markerstrokewidth=0,
        markersize=1,
        markercolor = :blue)

    # add workplaces
    scatter!(p, off_pnts.lon, off_pnts.lat,
        label = "Workplaces",
        legendfontsize = 10,
        markerstrokewidth=0,
        markersize=1,
        markercolor = :red)

    return p
end