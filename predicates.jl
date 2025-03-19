# SIZE

# 2-person household
i2(h, sim) = size(h) == 2

# 3-person household
i3(h, sim) = size(h) == 3

# 4-person household
i4(h, sim) = size(h) == 4

# 5-person household
i5(h, sim) = size(h) == 5

# 6+-person household
i6plus(h, sim) = size(h) >= 6

# SCHOOL

# with school kids
with_schoolkids(h, sim) = sum(is_student.(individuals(h))) > 0

# with school kids
without_schoolkids(h, sim) = sum(is_student.(individuals(h))) == 0

# 3-persons with school kids
i3_with_schoolkids(h, sim) = size(h) == 3 && sum(is_student.(individuals(h))) > 0

# 3-persons without school kids
i3_without_schoolkids(h, sim) = size(h) == 3 && sum(is_student.(individuals(h))) == 0

# 4-persons with school kids
i4_with_schoolkids(h, sim) = size(h) == 4 && sum(is_student.(individuals(h))) > 0

# 4-persons without school kids
i4_without_schoolkids(h, sim) = size(h) == 4 && sum(is_student.(individuals(h))) == 0

# 5-persons with school kids
i5_with_schoolkids(h, sim) = size(h) == 5 && sum(is_student.(individuals(h))) > 0

# 5-persons without school kids
i5_without_schoolkids(h, sim) = size(h) == 5 && sum(is_student.(individuals(h))) == 0

# 6plus-persons with school kids
i6plus_with_schoolkids(h, sim) = size(h) >= 6 && sum(is_student.(individuals(h))) > 0

# 6plus-persons without school kids
i6plus_without_schoolkids(h, sim) = size(h) >= 6 && sum(is_student.(individuals(h))) == 0

# multiple school classes
multiple_schools(h, sim) = (i -> i.schoolclass).(individuals(h)) |> unique |>
    usc -> usc[usc .>= 0] |> sum > 1

# get the school from a schoolclass setting object
school(schoolclass, sim) = begin
    sch_year = settings(sim, contained_type(schoolclass))[contained(schoolclass)]
    return settings(sim, contained_type(sch_year))[contained(sch_year)]
end
   

# big schools (at least one person in school with 150+ students)
big_schools(h, sim) = sum((i -> (is_student(i) && size(school(schoolclass(i, sim), sim), sim) > 150 ? 1 : 0)).(individuals(h))) > 0

# WORKERS

# with workers
with_workers(h, sim) = sum(is_working.(individuals(h))) > 0

# with workers
without_workers(h, sim) = sum(is_working.(individuals(h))) == 0

# 3-persons with workers
i3_with_workers(h, sim) = size(h) == 3 && sum(is_working.(individuals(h))) > 0

# 3-persons without workers
i3_without_workers(h, sim) = size(h) == 3 && sum(is_working.(individuals(h))) == 0

# 4-persons with workers
i4_with_workers(h, sim) = size(h) == 4 && sum(is_working.(individuals(h))) > 0

# 4-persons without workers
i4_without_workers(h, sim) = size(h) == 4 && sum(is_working.(individuals(h))) == 0

# 5-persons with workers
i5_with_workers(h, sim) = size(h) == 5 && sum(is_working.(individuals(h))) > 0

# 5-persons without workers
i5_without_workers(h, sim) = size(h) == 5 && sum(is_working.(individuals(h))) == 0

# 6plus-persons with workers
i6plus_with_workers(h, sim) = size(h) >= 6 && sum(is_working.(individuals(h))) > 0

# 6plus-persons without workers
i6plus_without_workers(h, sim) = size(h) >= 6 && sum(is_working.(individuals(h))) == 0