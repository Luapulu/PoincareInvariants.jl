@safetestset "ChebyshevImplementation" begin include("test_ChebyshevImplementation.jl") end

@safetestset "SecondPoincareInvariant OOP" begin
    using PoincareInvariants

    @testset "$N Points on Square in $(D)D" for D in [2, 10], N in [10, 123, 4321]
        Ω(z, t, p) = CanonicalSymplecticMatrix(D)
        pinv = SecondPoincareInvariant{Float64}(Ω, D, N, Val(false))

        parampoints = getpoints(pinv)

        phasepoints = zeros(Float64, getpointnum(pinv), D)
        for i in 1:getpointnum(pinv)
            phasepoints[i, 1] = parampoints[i][1]
            phasepoints[i, D ÷ 2 + 1] = parampoints[i][2]
        end

        @test abs(1 - compute!(pinv, phasepoints, 0, nothing)) / eps() < 10
    end
end

@safetestset "Free Particle" begin
    using PoincareInvariants

    function free_particle!(state, δt)
        mid = length(state) ÷ 2
        state[1:mid] += state[mid+1:end] .* δt
    end

    @testset "$N Points on Square in $(D)D" for D in [2, 6], N in [500, 10_000]
        Ω(z, t, p) = CanonicalSymplecticMatrix(D)
        pinv = SecondPoincareInvariant{Float64}(Ω, D, N, Val(false))

        parampoints = getpoints(pinv)

        phasepoints = zeros(Float64, getpointnum(pinv), D)
        for i in 1:getpointnum(pinv)
            phasepoints[i, 1] = parampoints[i][1]
            phasepoints[i, D ÷ 2 + 1] = parampoints[i][2]
        end

        @test abs(1 - compute!(pinv, phasepoints, 0, nothing)) / eps() < 10

        free_particle!.(eachrow(phasepoints), 10)
        @test abs(1 - compute!(pinv, phasepoints, 0, nothing)) / eps() < 10

        free_particle!.(eachrow(phasepoints), 100)
        @test abs(1 - compute!(pinv, phasepoints, 0, nothing)) / eps() < 50

        free_particle!.(eachrow(phasepoints), 1000)
        @test abs(1 - compute!(pinv, phasepoints, 0, nothing)) / eps() < 500
    end

    @testset "$N Points on Quarter Circle in $(D)D " for D in [4, 12], N in [234, 5678]
        Ω(z, t, p) = CanonicalSymplecticMatrix(D)
        pinv = SecondPoincareInvariant{Float64}(Ω, D, N, Val(false))

        parampoints = getpoints(pinv)

        phasepoints = ones(Float64, getpointnum(pinv), D)
        phasepoints[:, 2] .= map(parampoints) do v
            v[1] * cos(v[2] * π/2)
        end
        phasepoints[:, D ÷ 2 + 2] .= map(parampoints) do v
            v[1] * sin(v[2] * π/2)
        end

        @test abs(π/4 - compute!(pinv, phasepoints, 0, nothing)) / eps() < 10

        free_particle!.(eachrow(phasepoints), 10)
        @test abs(π/4 - compute!(pinv, phasepoints, 0, nothing)) / eps() < 10

        free_particle!.(eachrow(phasepoints), 100)
        @test abs(π/4 - compute!(pinv, phasepoints, 0, nothing)) / eps() < 200

        free_particle!.(eachrow(phasepoints), 1000)
        @test abs(π/4 - compute!(pinv, phasepoints, 0, nothing)) / eps() < 1_000
    end
end
