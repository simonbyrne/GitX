struct GitTreeEntry
    mode::UInt32
    name::String
    hash::SHA1Hash
end

struct GitTree <: GitObject
    entries::Vector{GitTreeEntry}
end

Base.sizeof(entry::GitTreeEntry) =
    ndigits(entry.mode, 8) + 1 + sizeof(entry.name) + 1 + 20
Base.sizeof(tree::GitTree) = sum(sizeof, tree.entries)

function Base.read(io::IO, ::Type{GitTreeEntry})
    mode = parse(UInt32,chop(readuntil(io, ' ')),8)
    name = chop(readuntil(io,'\0'))
    hash = read(io, SHA1Hash)
    return GitTreeEntry(mode, name, hash)
end

function GitTree(data::Vector{UInt8})
    entries = GitTreeEntry[]
    io = IOBuffer(data)
    while nb_available(io) > 0
        entry = read(io, GitTreeEntry)
        push!(entries, entry)
    end
    GitTree(entries)
end

function oid(tree::GitTree)
    ctx = SHA.SHA1_CTX()
    SHA.update!(ctx, Vector{UInt8}("tree $(sizeof(tree))\0"))
    for entry in tree.entries
        SHA.update!(ctx, Vector{UInt8}(string(oct(entry.mode),' ',entry.name,'\0')))
        SHA.update!(ctx, Vector{UInt8}(entry.hash))
    end
    return SHA1Hash(SHA.digest!(ctx))
end
