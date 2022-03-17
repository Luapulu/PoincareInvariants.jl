"""
    ChebyshevImplementation

implementation of computation of second Poincare invariant by approximating surface with
Chebyshev polynomials
"""
module ChebyshevImplementation

using ...PoincareInvariants: @argcheck
import ...PoincareInvariants: compute!, getpoints, getpointnum

using Base: Callable
using LinearAlgebra

include("PaduaTransforms.jl")
using .PaduaTransforms

const AbstractArray3 = AbstractArray{<:Any, 3}

## Differentiation ##

function getdiffmat(::Type{T}, degree::Integer) where T
    D = zeros(T, degree+1, degree+1)

    D[1, 2:2:end] .= 1:2:degree

    for i in 3:2:degree+1
        D[2:2:i-1, i] .= 2 * (i-1)
    end

    for i in 4:2:degree+1
        D[3:2:i-1, i] .= 2 * (i-1)
    end

    D
end

struct DiffPlan{T}
    D::Matrix{T}
end

DiffPlan{T}(degree::Integer) where T = DiffPlan{T}(getdiffmat(T, degree))

# differentiate in the Chebyshev basis
function differentiate!(∂x::AbstractMatrix, ∂y::AbstractMatrix, P::DiffPlan, coeffs::AbstractMatrix)
    ∂x[:, :] = coeffs  # differentiate each row
    rmul!(∂x, LowerTriangular(P.D'))

    ∂y[:, :] = coeffs  # differentiate each column
    lmul!(UpperTriangular(P.D), ∂y)

    ∂x, ∂y
end

function differentiate!(∂x, ∂y, P::DiffPlan, coeffs)
    eltype(∂x) <: AbstractMatrix && eltype(∂y) <: AbstractMatrix &&
        eltype(coeffs) <: AbstractMatrix || throw(ArgumentError(
            "coefficients must be AbstractMatrix or iterable thereof"))
    length(∂x) == length(∂y) == length(coeffs) || throw(ArgumentError(
        "number of coefficient matrices must match number of derivative matrices to write to"))

    for (∂xi, ∂yi, coeffsi) in zip(∂x, ∂y, coeffs)
        differentiate!(∂xi, ∂yi, P, coeffsi)
    end

    ∂x, ∂y
end

## Integration ##

getintegrator(::Type{T}, n) where T = T[isodd(i) ? 0 : T(2) / T(1 - i^2) for i in 0:n]
getintegrator(n) = getintegrator(Float64, n)

integrate(coeffs, integrator) = dot(integrator, coeffs, integrator)

## getintegrand for Ω Callable and out-of-place ##

struct OOPIntPlan{T, IP, P}
    invpaduaplan::IP
    phasevals::Matrix{T}
    ∂xvals::Matrix{T}
    ∂yvals::Matrix{T}
    intvals::Vector{T}
    paduaplan::P
end

function OOPIntPlan{T}(D, degree) where T
    invpaduaplan = InvPaduaTransformPlan{T}(degree)
    phasevals = Matrix{T}(undef, D, getpaduanum(degree))
    ∂xvals = Matrix{T}(undef, D, getpaduanum(degree))
    ∂yvals = Matrix{T}(undef, D, getpaduanum(degree))
    intvals = Vector{T}(undef, getpaduanum(degree))
    paduaplan = PaduaTransformPlan{T}(degree)

    OOPIntPlan{T, typeof(invpaduaplan), typeof(paduaplan)}(
        invpaduaplan, phasevals, ∂xvals, ∂yvals, intvals, paduaplan
    )
end

function getintegrand!(
    intcoeffs::AbstractMatrix, plan::OOPIntPlan{T}, Ω::Callable,
    phasepoints, t, p, ∂xcoeffs, ∂ycoeffs
) where T
    invpaduatransform!(eachrow(plan.∂xvals), plan.invpaduaplan, ∂xcoeffs)
    invpaduatransform!(eachrow(plan.∂yvals), plan.invpaduaplan, ∂ycoeffs)

    D = length(phasepoints)
    for d in 1:D
        plan.phasevals[d, :] .= phasepoints[d]
    end

    for i in axes(plan.intvals, 1)
        pnti = view(plan.phasevals, :, i)
        ∂xi = view(plan.∂xvals, :, i)
        ∂yi = view(plan.∂yvals, :, i)
        plan.intvals[i] = dot(∂yi, Ω(pnti, t, p), ∂xi)
    end

    paduatransform!(intcoeffs, plan.paduaplan, plan.intvals)

    intcoeffs
end

## ChebyshevPlan and compute! ##

getintplan(::Type{T}, ::Callable, D, degree, ::Val{false}) where T = OOPIntPlan{T}(D, degree)
# getintplan(::Type{T}, ::Callable, D, degree, ::Val{true}) where T = IPIntPlan{T}(D, degree)
# getintplan(::Type{T}, Ω::AbstractMatrix, D, degree, ::Val{nothing}) where T = IPIntPlan{T}(Ω, D, degree)

struct ChebyshevPlan{T, IP, PP<:PaduaTransformPlan}
    degree::Int
    paduaplan::PP
    phasecoeffs::Vector{Matrix{T}}
    diffplan::DiffPlan{T}
    ∂x::Vector{Matrix{T}}
    ∂y::Vector{Matrix{T}}
    intplan::IP  # getting coefficients of integrand to integrate
    intcoeffs::Matrix{T}
    integrator::Vector{T}
end

function ChebyshevPlan{T}(Ω::Callable, D::Integer, N::Integer, ::Val{inplace}) where {T, inplace}
    degree = getdegree(nextpaduanum(N))

    paduaplan = PaduaTransformPlan{T}(degree)
    phasecoeffs = [zeros(T, degree+1, degree+1) for _ in 1:D]
    diffplan = DiffPlan{T}(degree)
    ∂x = [Matrix{T}(undef, degree+1, degree+1) for _ in 1:D]
    ∂y = [Matrix{T}(undef, degree+1, degree+1) for _ in 1:D]
    intplan = getintplan(T, Ω, D, degree, Val(inplace))
    intcoeffs = zeros(T, degree+1, degree+1)
    integrator = getintegrator(T, degree)

    ChebyshevPlan{T, typeof(intplan), typeof(paduaplan)}(
        degree, paduaplan, phasecoeffs, diffplan, ∂x, ∂y, intplan, intcoeffs, integrator
    )
end

function compute!(plan::ChebyshevPlan, Ω::Callable, phasepoints, t, p)
    paduatransform!(plan.phasecoeffs, plan.paduaplan, phasepoints)
    differentiate!(plan.∂x, plan.∂y, plan.diffplan, plan.phasecoeffs)
    getintegrand!(plan.intcoeffs, plan.intplan, Ω, phasepoints, t, p, plan.∂x, plan.∂y)
    integrate(plan.intcoeffs, plan.integrator)
end

# function _compute!(plan::ChebyshevPlan, Ω::AbstractMatrix, D, phasepoints)
#     paduatransform!(plan.phasecoeffs, plan.paduaplan, phasepoints)
#     differentiate!(plan.∂x, plan.∂y, plan.diffplan, plan.phasecoeffs)
#     getintegrand!(plan.intcoeffs, plan.intplan, Ω, plan.∂x, plan.∂y)
#     integrate(plan.intcoeffs, plan.intplan)
# end

## getpoints and getpointnum ##

getpointnum(plan::ChebyshevPlan) = getpaduanum(plan.degree)
getpoints(plan::ChebyshevPlan) = getpaduapoints(plan.degree) do x, y
    (x + 1) / 2, (y + 1) / 2
end

getpoints(f::Function, plan::ChebyshevPlan) = getpaduapoints(plan.degree) do x, y
    f((x + 1) / 2, (y + 1) / 2)
end

end  # module ChebyshevImplementation
