####################### Gate Utilities ######################

###################### X, Y, Z Gates ######################
"""
    xgate(::Type{MT}, num_bit::Int, bits::Ints) -> PermMatrix

X Gate on multiple bits.
"""
function xgate(::Type{MT}, num_bit::Int, bits::Ints) where MT<:Number
    mask = bmask(bits...)
    order = map(b->flip(b, mask) + 1, basis(num_bit))
    PermMatrix(order, ones(MT, 1<<num_bit))
end

"""
    ygate(::Type{MT}, num_bit::Int, bits::Ints) -> PermMatrix

Y Gate on multiple bits.
"""
function ygate(::Type{MT}, num_bit::Int, bits::Ints) where MT<:Complex
    mask = bmask(bits...)
    order = Vector{Int}(1<<num_bit)
    vals = Vector{MT}(1<<num_bit)
    factor = MT(im)^length(bits)
    for b = basis(num_bit)
        i = b+1
        order[i] = flip(b, mask) + 1
        vals[i] = count_ones(b&mask)%2 == 1 ? factor : -factor
    end
    PermMatrix(order, vals)
end

"""
    zgate(::Type{MT}, num_bit::Int, bits::Ints) -> Diagonal

Z Gate on multiple bits.
"""
function zgate(::Type{MT}, num_bit::Int, bits::Ints) where MT<:Number
    mask = bmask(bits...)
    vals = map(b->count_ones(b&mask)%2==0 ? one(MT) : -one(MT), basis(num_bit))
    Diagonal(vals)
end

####################### Controlled Gates #######################
"""
    general_controlled_gates(num_bit::Int, projectors::Vector{Tp}, cbits::Vector{Int}, gates::Vector{AbstractMatrix}, locs::Vector{Int}) -> AbstractMatrix

Return general multi-controlled gates in hilbert space of `num_bit` qubits,

* `projectors` are often chosen as `P0` and `P1` for inverse-Control and Control at specific position.
* `cbits` should have the same length as `projectors`, specifing the controling positions.
* `gates` are a list of controlled single qubit gates.
* `locs` should have the same length as `gates`, specifing the gates positions.
"""
function general_controlled_gates(
    n::Int,
    projectors::Vector{<:AbstractMatrix},
    cbits::Vector{Int},
    gates::Vector{<:AbstractMatrix},
    locs::Vector{Int}
)
    IMatrix(1<<n) - hilbertkron(n, projectors, cbits) +
        hilbertkron(n, vcat(projectors, gates), vcat(cbits, locs))
end

#### C-X/Y/Z Gates
"""
    cxgate(::Type{MT}, num_bit::Int, b1::Ints, b2::Ints) -> PermMatrix

Single (Multiple) Controlled-X Gate on single (multiple) bits.
"""
function cxgate(::Type{MT}, num_bit::Int, b1::Ints, b2::Ints) where MT<:Number
    mask = bmask(b1)
    mask2 = bmask(b2)
    order = map(i->testall(i, mask) ? flip(i, mask2)+1 : i+1, basis(num_bit))
    PermMatrix(order, ones(MT, 1<<num_bit))
end

"""
    cygate(::Type{MT}, num_bit::Int, b1::Int, b2::Int) -> PermMatrix

Single Controlled-Y Gate on single bit.
"""
function cygate(::Type{MT}, num_bit::Int, b1::Int, b2::Int) where MT<:Complex
    mask2 = bmask(b2)
    order = collect(1:1<<num_bit)
    vals = ones(MT, 1<<num_bit)
    step = 1<<(b1-1)
    step_2 = 1<<b1
    for j = step:step_2:1<<num_bit-1
        @simd for i = j+1:j+step
            b = i-1
            @inbounds order[i] = flip(b, mask2) + 1
            @inbounds vals[i] = (2*takebit(b, b2)-1)*MT(im)
        end
    end
    PermMatrix(order, vals)
end

"""
    czgate(::Type{MT}, num_bit::Int, b1::Int, b2::Int) -> Diagonal

Single Controlled-Z Gate on single bit.
"""
function czgate(::Type{MT}, num_bit::Int, b1::Int, b2::Int) where MT<:Number
    mask2 = bmask(b2)
    vals = ones(MT, 1<<num_bit)
    step = 1<<(b1-1)
    step_2 = 1<<b1
    for j = step:step_2:1<<num_bit-1
        @simd for i = j+1:j+step
            @inbounds vals[i] = 1-2*takebit(i-1, b2)
        end
    end
    Diagonal(vals)
end

"""
    controlled_U1(num_bit::Int, gate::AbstractMatrix, cbits::Vector{Int}, b2::Int) -> AbstractMatrix

Return general multi-controlled single qubit `gate` in hilbert space of `num_bit` qubits.

* `cbits` specify the controling positions.
* `b2` is the controlled position.
"""
function controlled_U1 end


# general multi-control single-gate
function controlled_U1(num_bit::Int, gate::PermMatrix{T}, cbits::Vector{Int}, b2::Int) where {T}
    vals = ones(T, 1<<num_bit)
    order = collect(1:1<<num_bit)
    mask = bmask(cbits...)
    mask2 = bmask(b2)
    @simd for b in basis(num_bit)
        if testall(b, mask)
            bind = b+1
            @inbounds vals[bind] = gate.vals[gate.perm[2-takebit(b, b2)]]
            @inbounds order[bind] = (gate.perm[1] == 1) ? bind : flip(b, mask2)+1
        end
    end
    PermMatrix(order, vals)
end

function controlled_U1(num_bit::Int, gate::SparseMatrixCSC, b1::Vector{Int}, b2::Int)
    general_controlled_gates(2, [P1], b1, [gate], [b2])
end

function controlled_U1(num_bit::Int, gate::Diagonal{T}, cbits::Vector{Int}, b2::Int) where {T}
    mask = bmask(cbits...)
    ######### LW's version ###########
    vals = ones(T, 1<<num_bit)
    @simd for i in basis(num_bit)
        if testall(i, mask)
            @inbounds vals[i+1] = gate.diag[1+takebit(i, b2)]
        end
    end
    ######### simple version ###########
    #a, b = gate.diag
    #vals = map(i->(testall(i, mask) ? (testany(i, b2) ? b : a) : T(1))::T, basis(num_bit))
    Diagonal(vals)
end

function controlled_U1(num_bit::Int, gate::StridedMatrix, b1::Vector{Int}, b2::Int)
    general_controlled_gates(2, [P1], b1, [gate], [b2])
end

# arbituary control PermMatrix gate: SparseMatrixCSC
# TODO: to interface
#toffoligate(num_bit::Int, b1::Int, b2::Int, b3::Int) = controlled_U1(num_bit, PAULI_X, [b1, b2], b3)
