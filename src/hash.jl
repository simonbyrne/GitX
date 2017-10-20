abstract type AbstractHash end

struct SHA1Hash <: AbstractHash
    bytes::NTuple{20, UInt8}
end

function SHA1Hash(data::Vector{UInt8})
    @assert length(data) == 20
    SHA1Hash(tuple(data...))
end
SHA1Hash(str::AbstractString) = SHA1Hash(hex2bytes(str))

macro sha1_str(str)
    SHA1Hash(str)
end

Base.hex(hash::SHA1Hash) = bytes2hex(collect(hash.bytes))
Base.show(io::IO, hash::SHA1Hash) = print(io,"sha1\"",hex(hash),"\"")
(::Type{Base.Vector{UInt8}})(hash::SHA1Hash) = collect(hash.bytes)


Base.:(<)(x::SHA1Hash, y::SHA1Hash) = x.bytes < y.bytes

function Base.read(io::IO, ::Type{SHA1Hash})
    r = Ref{NTuple{20,UInt8}}()
    unsafe_read(io, r, 20)
    SHA1Hash(r[])
end
