import GEMS.sample_contacts

mutable struct SizeBasedSampling <: GEMS.ContactSamplingMethod
    threshold::Int64
    std_dev::Float64 # avg distance of sampled individual in vector of individuals
    contactparameter::Float64

    function SizeBasedSampling(;threshold = 100, std_dev = 5.0, contactparameter = 1.0)
        return new(threshold, std_dev, contactparameter)
    end
end


custom_modulo(a, n) = mod(a - 1, n) + 1

function GEMS.sample_contacts(size_based_sampling::SizeBasedSampling, setting::Setting, individual::Individual, present_inds::Vector{Individual}, tick::Int16)
   
    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    if length(present_inds) == 1
        return Individual[]
    end

    # get number of contacts
    number_of_contacts = rand(Poisson(size_based_sampling.contactparameter))
    res = Vector{Individual}(undef, number_of_contacts)

    cnt = 0
    
    # normal distribution for size-based sampling
    N = Normal(0, size_based_sampling.std_dev)

    # Draw until contact list is filled, skip whenever the index individual was selected
    while cnt < number_of_contacts

        # if fewer individuals present than given in the 
        # threshold, sample randomly
        if length(present_inds) < size_based_sampling.threshold
            contact = rand(present_inds)
                
        # if more individuals present than given in the
        # threshold, sample based on proximity in individual vector
        else
            pos = findfirst(isequal(individual), present_inds)
            contact = present_inds[custom_modulo(pos + round(Int, rand(N)), length(present_inds))]
            # contact = present_inds[custom_modulo(id(individual) + round(Int, rand(N)), length(present_inds))]
        end

        # if contact is NOT index individual, add them to contact list
        if Ref(contact) .!== Ref(individual)
            res[cnt + 1] = contact
            cnt += 1
        end
    end

    return res
end
