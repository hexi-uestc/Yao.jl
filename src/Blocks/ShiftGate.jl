export ShiftGate

"""
    ShiftGate <: PrimitiveBlock

Phase shift gate.
"""
mutable struct ShiftGate{T} <: PrimitiveBlock{1, Complex{T}}
    theta::T
end

mat(gate::ShiftGate{T}) where T = Diagonal(Complex{T}[1.0, exp(im * gate.theta)])
adjoint(blk::ShiftGate) = ShiftGate(-blk.theta)

copy(block::ShiftGate{T}) where T = ShiftGate{T}(block.theta)

# parametric interface
niparameters(::Type{<:ShiftGate}) = 1
iparameters(x::ShiftGate) = x.theta
setiparameters!(r::ShiftGate, param::Real) = (r.theta = param; r)

isunitary(r::ShiftGate) = true

==(lhs::ShiftGate, rhs::ShiftGate) = lhs.theta == rhs.theta

function hash(gate::ShiftGate, h::UInt)
    hash(hash(gate.theta, objectid(gate)), h)
end

cache_key(gate::ShiftGate) = gate.theta

function print_block(io::IO, g::ShiftGate)
    print(io, "Phase Shift Gate:", g.theta)
end
