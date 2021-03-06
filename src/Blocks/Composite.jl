# composite blocks are iterables
import Base: iterate, eltype, length

# composite blocks are indexable
import Base: getindex, setindex!, map!, eachindex

# Additional APIs
export CompositeBlock


"""
    CompositeBlock{N, T} <: MatrixBlock{N, T}

abstract supertype which composite blocks will inherit from.

# extended APIs

`blocks`: get an iteratable of all blocks contained by this `CompositeBlock`

"""
abstract type CompositeBlock{N, T} <: MatrixBlock{N, T} end

const GeneralComposite = Union{CompositeBlock, Sequential}

function map!(f::Function, dst::GeneralComposite, itr)
    @assert length(dst) >= length(itr) "composite block should have the same size"

    for (di, each) in zip(eachindex(dst), itr)
        dst[di] = f(each)
    end
    dst
end

==(lhs::CompositeBlock, rhs::CompositeBlock) = false

include("ChainBlock.jl")
include("AddBlock.jl")
include("KronBlock.jl")
include("Roller.jl")
include("PauliString.jl")
