# this file defines *and* loads one module

module MultivariateStats_

export RidgeRegressor 

import MLJInterface
import MLJ
import MultivariateStats
import DataFrames

struct LinearFitresult <: MLJInterface.MLJType
    coefficients::Vector{Float64}
    bias::Float64
end

# Following helper function returns a `DataFrame` with three columns:
#
# column name | description
# :-----------|:-------------------------------------------------
# `:index`    | index of a feature used to train `fitresult`
# `:feature`  | corresponding feature label provided by `features`
# `:coef`     | coefficient for that feature in the fitresult
#
# The rows are ordered by the absolute value of the coefficients.
function coef_info(fitresult::LinearFitresult, features)
    coef_given_index = Dict{Int, Float64}()
    abs_coef_given_index = Dict{Int, Float64}()
    v = fitresult.coefficients
    for k in eachindex(v)
        coef_given_index[k] = v[k]
        abs_coef_given_index[k] = abs(v[k])
    end
    df = DataFrames.DataFrame()
    df[:index] = reverse(MLJ.keys_ordered_by_values(abs_coef_given_index))
    df[:feature] = map(df[:index]) do index
        features[index]
    end
    df[:coef] = map(df[:index]) do index
        coef_given_index[index]
    end
    return df
end

mutable struct RidgeRegressor <: MLJInterface.Deterministic{LinearFitresult}
    lambda::Float64
end

# lazy keywork constructor
RidgeRegressor(; lambda=0.0) = RidgeRegressor(lambda)

MLJInterface.coerce(model::RidgeRegressor, Xtable) = (MLJInterface.matrix(Xtable), Xtable[MLJ.Names])

function MLJInterface.fit(model::RidgeRegressor, verbosity, Xplus, y::Vector{<:Real})

    X, features = Xplus

    weights = MultivariateStats.ridge(X, y, model.lambda)

    coefficients = weights[1:end-1]
    bias = weights[end]

    fitresult = LinearFitresult(coefficients, bias)

    # report on the relative strength of each feature in the fitresult:
    report = Dict{Symbol, Any}()

    # temporary hack because fit doesn't know feature names:
    # features = [Symbol(string("_", j)) for j in 1:size(X, 2)]

    cinfo = coef_info(fitresult, features) # a DataFrame object
    u = String[]
    v = Float64[]
    for i in 1:size(cinfo, 1)
        feature, coef = (cinfo[i, :feature], cinfo[i, :coef])
        coef = floor(1000*coef)/1000
        if coef < 0
            label = string(feature, " (-)")
        else
            label = string(feature, " (+)")
        end
        push!(u, label)
        push!(v, abs(coef))
    end
    report[:feature_importance_curve] = (u, v)
    cache = nothing

    return fitresult, cache, report

end

function MLJInterface.predict(model::RidgeRegressor, fitresult::LinearFitresult, Xnew)
    X, features = Xnew
    return X*fitresult.coefficients .+ fitresult.bias
end

# metadata:
function MLJInterface.info(::Type{RidgeRegressor})
    d = Dict()
    d["package name"] = "MultivariateStats"
    d["package uuid"] = "6f286f6a-111f-5878-ab1e-185364afe411"
    d["properties"] = ["can rank feature importances"]
    d["is_pure_julia"] = "yes"
    d["operations"] = ["predict"]
    d["inputs_can_be"] = ["numeric"]
    d["outputs_are"] = ["numeric", "deterministic", "univariate"]
    return d
end

end # of module


## EXPOSE THE INTERFACE

using .MultivariateStats_
export RidgeRegressor

