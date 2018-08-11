import Base: string, print, show, isless, hash, ==, read

if VERSION < v"0.7-"

    """
        SHA1(x::Vector{UInt8})
        SHA1(str::AbstractString)

    A 20-byte sha1 hash.
    """
    struct SHA1
        bytes::Vector{UInt8}
        function SHA1(bytes::Vector{UInt8})
            length(bytes) == 20 ||
                throw(ArgumentError("wrong number of bytes for SHA1 hash: $(length(bytes))"))
            return new(bytes)
        end
    end
    SHA1(s::AbstractString) = SHA1(hex2bytes(s))

    string(hash::SHA1) = bytes2hex(hash.bytes)
    print(io::IO, hash::SHA1) = print(io, string(hash))

    show(io::IO, hash::SHA1) = print(io, "SHA1(\"", string(hash), "\")")
    isless(a::SHA1, b::SHA1) = lexless(a.bytes, b.bytes)
    hash(a::SHA1, h::UInt) = hash((SHA1, a.bytes), h)
    ==(a::SHA1, b::SHA1) = a.bytes == b.bytes

end

macro sha1_str(str)
    SHA1(str)
end

function Base.read(io::IO, ::Type{SHA1})
    data = Array{UInt8}(undef, 20)
    SHA1(read!(io, data))
end
