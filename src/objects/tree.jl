@enum GitMode mode_dir=0o040000 mode_normal=0o100644 mode_executable=0o100755 mode_symlink=0o120000 mode_submodule=0o160000

struct GitTreeEntry
    mode::GitMode
    name::String
    hash::SHA1Hash
end

struct GitTree <: GitObject
    entries::Vector{GitTreeEntry}
end

Base.sizeof(entry::GitTreeEntry) =
    ndigits(UInt32(entry.mode), 8) + 1 + sizeof(entry.name) + 1 + 20
Base.sizeof(tree::GitTree) = sum(sizeof, tree.entries)

function Base.read(io::IO, ::Type{GitTreeEntry})
    mode = GitMode(parse(UInt32,chop(readuntil(io, ' ')),8))
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
        SHA.update!(ctx, Vector{UInt8}(string(oct(UInt32(entry.mode)),' ',entry.name,'\0')))
        SHA.update!(ctx, Vector{UInt8}(entry.hash))
    end
    return SHA1Hash(SHA.digest!(ctx))
end

entryorder(entry::GitTreeEntry) = entry.mode == mode_dir ? entry.name*"/" : entry.name

"""
    GitTreeEntry(fpath[, name])

Construct a `GitTreeEntry` object based on `path`. If no `name` is provided, it is
assumed to be the `basename(path)`.
"""
function GitTreeEntry(path::AbstractString, name::AbstractString=basename(filepath))
    mode = isdir(path) ? mode_dir : mode_normal
    hash = oid(path)
    GitTreeEntry(mode, name, hash)
end

function GitTree(path::AbstractString, ignore::Glob.FilenameMatch=fn"")
    names = filter(name -> !ismatch(ignore,name), readdir(path))
    entries = map(names) do name
        GitTreeEntry(joinpath(path, name), name)
    end
    sort!(entries, by=entryorder)
    GitTree(entries)
end

function oid(path::AbstractString, ignore::Glob.FilenameMatch=fn".git")
    if isdir(path)
        oid(GitTree(path, ignore))
    else
        oid(GitBlob(read(path)))
    end
end
