using SafeTestsets, Test

@safetestset "CanoincalSymplecticStructures" begin
    include("test_CanonicalSymplecticStructures.jl")
end

@safetestset "FirstPoincareInvariants" begin
    include("FirstPoincareInvariants/test_FirstPoincareInvariants.jl")
end

@safetestset "SecondPoincareInvariants" begin
    include("SecondPoincareInvariants/test_SecondPoincareInvariants.jl")
end
