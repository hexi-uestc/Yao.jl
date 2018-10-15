export DefaultRegister

"""
    DefaultRegister{B, T} <: AbstractRegister{B, T}

Default type for a quantum register. It contains a dense array that represents
a batched quantum state with batch size `B` of type `T`.
"""
mutable struct DefaultRegister{B, T, MT<:AbstractMatrix{T}} <: AbstractRegister{B, T}
    state::MT # this stores a batched state
end

function DefaultRegister{B}(raw::MT) where {B, T, MT<:AbstractMatrix{T}}
    DefaultRegister{B, T, MT}(raw)
end

# copy method
function DefaultRegister(r::DefaultRegister{B}) where B
    DefaultRegister{B}(copy(r.state))
end


# register without batch
"""
    register(raw) -> DefaultRegister

Returns a [`DefaultRegister`](@ref) from a raw dense array (`Vector` or `Matrix`).
"""
function register(raw::AbstractMatrix; B=size(raw,2))
    ispow2(size(raw, 1)) && ispow2(size(raw, 2) ÷ B) ||
        throw(InexactError(:DefaultRegister, DefaultRegister, raw))
    DefaultRegister{B}(raw)
end
register(raw::AbstractVector) = register(reshape(raw, :, 1))

# Required Properties
nqubits(r::DefaultRegister{B}) where B = log2i(length(r.state) ÷ B)
nactive(r::DefaultRegister) = state(r) |> nactive
state(r::DefaultRegister) = r.state

"""
    relaxedvec(r::DefaultRegister) -> AbstractArray

Return a matrix (vector) for B>1 (B=1) as a vector representation of state, with all qubits activated.
"""
relaxedvec(r::DefaultRegister{B}) where B = reshape(r.state, :, B)
relaxedvec(r::DefaultRegister{1}) = vec(r.state)
"""
    statevec(r::DefaultRegister) -> AbstractArray

Return a state matrix/vector by droping the last dimension of size 1.
"""
statevec(r::DefaultRegister) = r.state |> matvec
"""
    hypercubic(r::DefaultRegister) -> AbstractArray

Return the hypercubic form (high dimensional tensor) of this register, only active qubits are considered.
"""
hypercubic(reg::DefaultRegister{B}) where B = reshape(reg.state, ntuple(i->2, Val(nactive(reg)))..., :)
"""
    rank3(reg::DefaultRegister) -> Array{T, 3}

Return the rank 3 tensor representation of state, the 3 dimensions are (activated space, remaining space, batch dimension).
"""
rank3(reg::DefaultRegister{B}) where B = reshape(reg.state, size(reg.state, 1), :, B)

copy(r::DefaultRegister{B}) where B = DefaultRegister{B}(copy(state(r)))
copyto!(reg1::RT, reg2::RT) where {RT<:AbstractRegister} = (copyto!(reg1.state, reg2.state); reg1)

similar(r::DefaultRegister{B, T}) where {B, T} = DefaultRegister{B}(similar(r.state))

"""
    product_state([::Type{T}], n::Int, config::Int, nbatch::Int=1) -> DefaultRegister

a product state on given configuration `config`, e.g. product_state(ComplexF64, 5, 0) will give a zero state on a 5 qubit register.
"""
product_state(::Type{T}, n::Int, config::Integer, nbatch::Int=1) where T = register((arr=zeros(T, 1<<n, nbatch); arr[config+1,:] .= 1; arr))

"""
    zero_state([::Type{T}], n::Int, nbatch::Int=1) -> DefaultRegister
"""
zero_state(::Type{T}, n::Int, nbatch::Int=1) where T = product_state(T, n, 0, nbatch)

"""
    rand_state([::Type{T}], n::Int, nbatch::Int=1) -> DefaultRegister

here, random complex numbers are generated using `randn(ComplexF64)`.
"""
rand_state(::Type{T}, n::Int, nbatch::Int=1) where T = register(randn(T, 1<<n, nbatch) + im*randn(T, 1<<n, nbatch)) |> normalize!

"""
    uniform_state([::Type{T}], n::Int, nbatch::Int=1) -> DefaultRegister

uniform state, the state after applying H gates on |0> state.
"""
uniform_state(::Type{T}, n::Int, nbatch::Int=1) where T = register(ones(T, 1<<n, nbatch)./sqrt(1<<n))

for FUNC in [:zero_state, :rand_state, :uniform_state]
    @eval $FUNC(n::Int, nbatch::Int=1) = $FUNC(DefaultType, n, nbatch)
end
product_state(n::Int, config::Integer, nbatch::Int=1) = product_state(DefaultType, n, config, nbatch)

function probs(r::DefaultRegister{1})
    if size(r.state, 2) == 1
        return vec(r.state .|> abs2)
    else
        return dropdims(sum(r.state .|> abs2, dims=2), dims=2)
    end
end

function probs(r::DefaultRegister{B}) where B
    if size(r.state, 2) == B
        return r.state .|> abs2
    else
        probs = r |> rank3 .|> abs2
        return dropdims(sum(probs, dims=2), dims=2)
    end
end

"""
    extend!(r::DefaultRegister, n::Int) -> DefaultRegister
    extend!(n::Int) -> Function

extend the register by n bits in state |0>.
i.e. |psi> -> |000> ⊗ |psi>, extended bits have higher indices.
If only an integer is provided, then perform lazy evaluation.
"""
function extend!(r::DefaultRegister{B, T}, n::Int) where {B, T}
    mat = r.state
    M, N = size(mat)
    r.state = zeros(T, M*(1<<n), N)
    r.state[1:M, :] = mat
    r
end

extend!(n::Int) = r->extend!(r, n)

function join(reg1::DefaultRegister{B, T1}, reg2::DefaultRegister{B, T2}) where {B, T1, T2}
    s1 = reg1 |> rank3
    s2 = reg2 |> rank3
    T = promote_type(T1, T2)
    state = Array{T,3}(undef, size(s1, 1)*size(s2, 1), size(s1, 2)*size(s2, 2), B)
    for b = 1:B
        @inbounds @views state[:,:,b] = kron(s2[:,:,b], s1[:,:,b])
    end
    DefaultRegister{B}(reshape(state, size(state, 1), :))
end
join(reg1::DefaultRegister{1}, reg2::DefaultRegister{1}) = DefaultRegister{1}(kron(reg2.state, reg1.state))

"""
    isnormalized(reg::DefaultRegister) -> Bool

Return true if a register is normalized else false.
"""
isnormalized(reg::DefaultRegister) = all(sum(copy(reg) |> relax! |> probs, dims=1) .≈ 1)

# we convert state to a vector to use
# intrincs like gemv, when nremain is
# 0 and the state is actually a vector
*(op::AbstractMatrix, r::AbstractRegister) = op * statevec(r)

import Base: summary
function summary(io::IO, r::DefaultRegister{B, T}) where {B, T}
    println(io, "DefaultRegister{", B, ", ", T, "}")
end

function show(io::IO, r::DefaultRegister{B, T}) where {B, T}
    summary(io, r)
    print(io, "    active qubits: ", nactive(r), "/", nqubits(r))
end

############## Reordering #################
"""
    reorder!(reg::AbstractRegister, order) -> AbstractRegister
    reorder!(orders::Int...) -> Function    # currified

Reorder the lines of qubits, it also works for array.
"""
function reorder!(reg::DefaultRegister, orders)
    for i in 1:size(reg.state, 2)
        reg.state[:,i] = reorder(reg.state[:, i], orders)
    end
    reg
end
reorder!(orders::Int...) = reg::DefaultRegister -> reorder!(reg, [orders...])

"""
    invorder!(reg::AbstractRegister) -> AbstractRegister

Inverse the order of lines inplace.
"""
invorder!(reg::DefaultRegister) = reorder!(reg, collect(nactive(reg):-1:1))

function addbit!(reg::DefaultRegister{B, T}, n::Int) where {B, T}
    state = zeros(T, size(reg.state, 1)*(1<<n), size(reg.state, 2))
    state[1:size(reg.state, 1), :] = reg.state
    reg.state = state
    reg
end

"""
    reset!(reg::AbstractRegister, val::Integer=0) -> AbstractRegister

`reset!` reg to default value.
"""
function reset!(reg::DefaultRegister; val::Integer=0)
    reg.state .= 0
    @inbounds reg.state[val+1,:] .= 1
    reg
end

function fidelity(reg1::DefaultRegister{B}, reg2::DefaultRegister{B}) where B
    state1 = reg1 |> rank3
    state2 = reg2 |> rank3
    size(state1) == size(state2) || throw(DimensionMismatch("Register size not match!"))
    # 1. pure state
    if size(state1, 2) == 1
        return map(b->fidelity_pure(state1[:,1,b], state2[:,1,b]), 1:B)
    else
        return map(b->fidelity_mix(state1[:,:,b], state2[:,:,b]), 1:B)
    end
end

function tracedist(reg1::DefaultRegister{B}, reg2::DefaultRegister{B}) where B
    size(reg1.state, 2) == B ? sqrt.(1 .- fidelity(reg1, reg2).^2) : throw(ArgumentError("trace distance for non-pure state is not defined!"))
end

@inline function viewbatch(reg::DefaultRegister, ind::Int)
    st = reg |> rank3
    @inbounds register(view(st, :, :, ind), B=1)
end

############ ConjDefaultRegister ##############
const ConjDefaultRegister{B, T} = ConjRegister{B, T, <:DefaultRegister}

statevec(bra::ConjDefaultRegister) = Adjoint(parent(bra) |> statevec)
relaxedvec(bra::ConjDefaultRegister) = Adjoint(parent(bra) |> relaxedvec)
rank3(bra::ConjDefaultRegister) = Adjoint(parent(bra) |> rank3)
