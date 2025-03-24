# SIZE

# returns true for all households
all_sizes(h, sim) = true

# 1-person household
i1(h, sim) = size(h) == 1

# 2(+)-person households
i2(h, sim) = size(h) == 2
i2plus(h, sim) = size(h) >= 2

# 3(+)-person household
i3(h, sim) = size(h) == 3
i3plus(h, sim) = size(h) >= 3

# 4(+)-person household
i4(h, sim) = size(h) == 4
i4plus(h, sim) = size(h) >= 4

# 5(+)-person household
i5(h, sim) = size(h) == 5
i5plus(h, sim) = size(h) >= 5

# 6(+)-person household
i6(h, sim) = size(h) == 6
i6plus(h, sim) = size(h) >= 6


# COMPOSITION

# with school kids
w_schoolkids(h, sim) = sum(is_student.(individuals(h))) > 0

# with exactly one school kid
w_1_schoolkid(h, sim) = sum(is_student.(individuals(h))) == 1

# with exactly one school kids
w_2plus_schoolkids(h, sim) = sum(is_student.(individuals(h))) >= 2

# without school kids
wo_schoolkids(h, sim) = sum(is_student.(individuals(h))) == 0

# get the school from a schoolclass setting object
school(schoolclass, sim) = begin
    sch_year = settings(sim, contained_type(schoolclass))[contained(schoolclass)]
    return settings(sim, contained_type(sch_year))[contained(sch_year)]
end

# multiple different schools
multiple_schools(h, sim) = (i -> (is_student(i) ? school(schoolclass(i, sim), sim).id : -1)).(individuals(h)) |> unique |>
    usc -> usc[usc .>= 0] |> sum > 1
 
# big schools (at least one person in school with 150+ students)
big_schools(h, sim) = sum((i -> (is_student(i) && size(school(schoolclass(i, sim), sim), sim) > 150 ? 1 : 0)).(individuals(h))) > 0



# with workers
w_workers(h, sim) = sum(is_working.(individuals(h))) > 0

# with workers
w_1_worker(h, sim) = sum(is_working.(individuals(h))) == 1

# with 2plus workers
w_2plus_workers(h, sim) = sum(is_working.(individuals(h))) >= 2

# with workers
wo_workers(h, sim) = sum(is_working.(individuals(h))) == 0


# with schoolkids and workers
w_schoolkids_w_workers(h, sim) = w_schoolkids(h, sim) && w_workers(h, sim)

# with schoolkids but without workers
w_schoolkids_wo_workers(h, sim) = w_schoolkids(h, sim) && wo_workers(h, sim)

# without schoolkids but with workers
wo_schoolkids_w_workers(h, sim) = wo_schoolkids(h, sim) && w_workers(h, sim)

# without schoolkids and without workers
wo_schoolkids_wo_workers(h, sim) = wo_schoolkids(h, sim) && wo_workers(h, sim)

# minimum age difference of 50 years
three_generation(h, sim) = age.(individuals(h)) |> a -> maximum(a) - minimum(a) >= 50 