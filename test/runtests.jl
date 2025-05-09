using Test, Random
using Quadmath

@testset "fp properties" begin
    # Test that the definitions of sign_mask, exponent_mask, significand_bits,
    # etc. are compatible with the definitions in base/float.jl. Compare to:
    # https://github.com/JuliaLang/julia/blob/5595d20a2877560583cd4891ce91605d10b1bb75/base/float.jl#L106
    @test Base.significand_bits(Float128) ===
        trailing_ones(Base.significand_mask(Float128))
    @test Base.exponent_bits(Float128) ===
        sizeof(Float128)*8 - Base.significand_bits(Float128) - 1
    @test Base.exponent_bias(Float128) === Int(
        Base.exponent_one(Float128) >> Base.significand_bits(Float128))
    @test Base.exponent_max(Float128) ===
        Int(Base.exponent_mask(Float128) >> Base.significand_bits(Float128)) -
            Base.exponent_bias(Float128) - 1
    @test Base.exponent_raw_max(Float128) === Int(
        Base.exponent_mask(Float128) >> Base.significand_bits(Float128))
    @test Base.uinttype(Float128) === UInt128
    @test Base.inttype(Float128) === Int128
end

@testset "fp decomp" begin
    y = Float128(2.0)
    x,n = frexp(y)
    @test x == Float128(0.5)
    @test n == 2
    z = ldexp(Float128(0.5), 2)
    @test z == y
end

@testset "conversions" begin
@testset "conversion $T" for T in (Float16, Float32, Float64, Int32, Int64, Int128, UInt32, UInt64, UInt128, BigFloat, BigInt)
    @test Float128(T(1)) + Float128(T(2)) == Float128(T(3))
    @test Float128(T(1)) + Float128(T(2)) <= Float128(T(3))
    @test Float128(T(1)) + Float128(T(2)) != Float128(T(4))
    @test Float128(T(1)) + Float128(T(2)) < Float128(T(4))
    if isbitstype(T)
        @test T(Float128(T(1)) + Float128(T(2))) === T(3)
    else
        @test T(Float128(T(1)) + Float128(T(2))) == T(3)
    end
    if isbitstype(T) && T <: Integer
        nb = 8*sizeof(T) - 5
        x = T(9) << nb
        xf = Float128(9) * 2.0^nb
        @test Float128(x) == xf
        @test T(xf) == x
    end
end

@testset "conversion $T exceptions" for T in (Int32, Int64, UInt32, UInt64)
    x = Float128(typemax(T))
    @test_throws InexactError T(x+Float128(1))
    x = Float128(typemin(T))
    @test_throws InexactError T(x-Float128(1))
end

@testset "conversion $T exceptions" for T in (Float32, Float64)
    x = Float128(typemax(T))
    @test isinf(T(x+Float128(1)))
    x = Float128(typemin(T))
    @test isinf(T(x-Float128(1)))
end

@testset "BigFloat" begin
    x = parse(Float128, "0.1")
    y = parse(Float128, "0.2")
    @test Float64(x+y) == Float64(BigFloat(x) + BigFloat(y))
    @test x+y == Float128(BigFloat(x) + BigFloat(y))
end

@testset "BigInt" begin
    x = parse(Float128, "100.0")
    y = parse(Float128, "25.0")
    @test Float64(x+y) == Float64(BigInt(x) + BigInt(y))
    @test x+y == Float128(BigInt(x) + BigInt(y))
end
end

@test Base.exponent_one(Float128) == reinterpret(UInt128, Float128(1.0))

@testset "flipsign" begin
    x = Float128( 2.0)
    y = Float128(-2.0)
    @test x == flipsign(y, -one(Float128))
    @test y == flipsign(y,  1)
end

@testset "arithmetic" begin
    fpi = Float128(pi)
    finvpi = inv(fpi)
    @test (fpi + 3) - fpi == 3
    @test fpi * finvpi === one(Float128)
    @test finvpi / fpi == finvpi^2
end

@testset "modf" begin
    x = Float128(pi)
    fpart, ipart = modf(x)
    @test x == ipart + fpart
    @test signbit(fpart) == signbit(ipart) == false

    y = Float128(-pi)
    fpart, ipart = modf(y)
    @test y == ipart + fpart
    @test signbit(fpart) == signbit(ipart) == true

    z = x^3
    fpart, ipart = modf(x) .+ modf(y)
    @test x+y == ipart+fpart
end

isnan128(x) = isa(x, Float128) && isnan(x)
isinf128(x) = isa(x, Float128) && isinf(x)

@testset "nonfinite" begin
    Zero = Float128(0)
    One = Float128(1)
    huge = floatmax(Float128)
    myinf = huge + huge
    myminf = -myinf
    @test isinf128(myinf)
    @test isnan128(Zero / Zero)
    @test isinf128(One / Zero)
    @test isnan128(myinf - myinf)
    @test isnan128(myinf + myminf)
    @test Inf128 === myinf
    @test typemax(Float128) === myinf
    @test typemin(Float128) === myminf
end

@testset "transcendental etc. calls" begin
    # at least enough to cover all the wrapping code
    @testset "real" begin
        x = sqrt(Float128(2.0))
        xd = Float64(x)
        @test (x^Float128(4.0)) ≈ Float128(4.0)
        @test exp(x) ≈ exp(xd)
        @test abs(x) == x
        @test hypot(Float128(3),Float128(4)) == Float128(5)
        @test atan(x,x) ≈ Float128(pi) / 4
        if !Sys.iswindows()
            @test fma(x,x,Float128(-1.0)) ≈ Float128(1)
        end
    end
    @testset "complex" begin
        x = sqrt(ComplexF128(1.0 + 1.0im))
        xd = ComplexF64(x)
        @test x^x ≈ xd^xd
        @test exp(x) ≈ exp(xd)
        @test abs(x) ≈ abs(xd)
        @test sin(x) ≈ sin(xd)
        @test cos(x) ≈ cos(xd)
        @test tan(x) ≈ tan(xd)
        @test log(x) ≈ log(xd)
    end
end

@testset "misc. math" begin
    x = sqrt(Float128(2.0))
    @test abs(x^(-2) - Float128(0.5)) < 1.0e-32
    m = maxintfloat(Float128)
    @test m+one(Float128) == m
    @test m-one(Float128) != m
    @test rem(Float128(3//2), Float128(1//2)) == 0.0
end

function hist(X, n)
    v = zeros(Int, n)
    for x in X
        v[floor(Int, x*n) + 1] += 1
    end
    v
end

@testset "random" begin
    # test for sanity and coarse uniformity
    @test typeof(rand(Float128)) == Float128
    for rng in [MersenneTwister(), RandomDevice()]
        counts = hist(rand(rng, Float128, 2000), 4)
        @test minimum(counts) > 300
        counts = hist([rand(rng, Float128) for i in 1:2000], 4)
        @test minimum(counts) > 300
    end
end

@testset "string conversion" begin
    s = string(Float128(3.0))
    p = r"3\.0+e\+0+"
    m = match(p, s)
    @test (m != nothing) && (m.match == s)
    @test parse(Float128,"3.0") == Float128(3.0)
end

@testset "irrationals" begin
    tiny = 2eps(Float128(1))
    @test abs(cos(Float128(pi)) + 1) < tiny
    @test abs(log(Float128(ℯ)) - 1) < tiny
    @test abs((2*Float128(MathConstants.golden) - 1)^2 - 5) < 5 * tiny
end

@testset "rationals" begin
    @test Float128(0.5) == 1//2
    # onetenth = 1/Float128(10)
    # apparently identical, but do the same as Base test:
    onetenth = parse(Float128, "0.1")
    @test onetenth != 1//10
    # bias + log2(1/8):
    a = Int128(1) << 115
    # rounding as indicated by BigFloat:
    @test onetenth == (a ÷ 10 + 1) // a
    @test Inf128 == 1//0
    @test -Inf128 == -1//0
    fm = floatmin(Float128)
    @test fm != 1//(BigInt(2)^16382+1)
    @test fm == 1//(BigInt(2)^16382)
    @test fm != 1//(BigInt(2)^16382-1)
    @test fm/2 != 1//(BigInt(2)^16383+1)
    @test fm/2 == 1//(BigInt(2)^16383)
    @test fm/2 != 1//(BigInt(2)^16383-1)
    tiny = nextfloat(Float128(0.0))
    @test tiny != 1//(BigInt(2)^16494+1)
    @test tiny == 1//(BigInt(2)^16494)
    @test tiny != 1//(BigInt(2)^16494-1)

    onethird = 1/Float128(3)
    onefifth = 1/Float128(5)
    @test onethird < 1//3
    @test !(1//3 < onethird)
    @test -onethird < 1//3
    @test -onethird > -1//3
    @test onethird > -1//3
    @test onefifth > 1//5
    @test 1//3 < Inf128
    @test 0//1 < Inf128
    @test 1//0 == Inf128
    @test -1//0 == -Inf128
    @test -1//0 != Inf128
    @test 1//0 != -Inf128
    @test !(1//0 < Inf128)
    Zero = Float128(0)
    fnan = Zero / Zero
    @test !(1//3 < fnan)
    @test !(1//3 == fnan)
    @test !(1//3 > fnan)
    @test [Float128(-10//1):Float128(1//10):Float128(0//1);] isa Any
end

@testset "ambiguities" begin
    @test Float128(1.0+0.0im) === Float128(1.0)
    @test_throws InexactError Float128(1.0+2.0im)

    @test Float128('a') === Float128(Int('a'))

    t_hi = 0.1
    t_lo = Float64(big"0.1" - t_hi)
    @test Float128(Base.TwicePrecision(t_hi, t_lo)) == Float128(t_hi) + Float128(t_lo)
end

include("hashing.jl")

include("specfun.jl")

include("printf.jl")

using Aqua
Aqua.test_all(Quadmath)
