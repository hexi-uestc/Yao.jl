module Registers

using Random, LinearAlgebra, SparseArrays
using StatsBase
using MacroTools: @forward
using ..Intrinsics

import Base: length, broadcastable, iterate, getindex, eltype
import Base: cat, repeat
import Base: copy, similar, *, join, copyto!
import Base: show
import Base: +, -, *, /, kron, ==, ≈

# import package APIs
import ..Yao: DefaultType, nqubits, nactive, reorder, invorder
import ..Intrinsics: basis, hypercubic

# APIs
export nqubits, nactive, nremain, nbatch, state, datatype, viewbatch
export relaxedvec, statevec, hypercubic, rank3, focus!, relax!, extend!, basis, probs, isnormalized
export AbstractRegister, Register, ConjRegister, RegOrConjReg
export invorder!, reorder!, addbit!, reset!

# factories
export register, zero_state, product_state, rand_state, uniform_state

# bit_str
export @bit_str, asindex
export DensityMatrix, density_matrix, ρ
export fidelity, tracedist


include("BitStr.jl")
include("Core.jl")
include("ConjRegister.jl")
include("Default.jl")

include("regoperations.jl")
include("DensityMatrix.jl")
# NOTE: these two are not implemented
# include("GPU.jl")
# include("MPS.jl")

end
