"""
    GitObject

An abstract type for git objects.
"""
abstract type GitObject end

include("raw.jl")
include("commit.jl")
include("tree.jl")
include("blob.jl")
include("tag.jl")


ObjCode(::Type{GitCommit}) = Obj.commit
ObjCode(::Type{GitTree})   = Obj.tree
ObjCode(::Type{GitBlob})   = Obj.blob
ObjCode(::Type{GitTag})    = Obj.tag

checkcode(::Type{T}, c::ObjCode) where {T<:GitObject} =
    c == ObjCode(T) ? T : error("invalid tag")

c(::Type{GitObject}, c::ObjCode) =
    t == Obj.commit ? GitCommit :
    t == Obj.tree   ? GitTree   :
    t == Obj.blob   ? GitBlob   :
    t == Obj.tag    ? GitTag    :
    error("invalid tag")


"""
    getobjdata(repo::GitRepo, hash::SHA1)

Fetch the tag and an array of raw bytes of the object id `hash` from `repo`. `t` is one of `Obj.commit`, `Obj.tree`, `Obj.Blob`, `Obj.tag`.
"""
function getobjdata(repo::GitRepo, hash::SHA1)
    h = string(hash)
    objpath = joinpath(repo.path, "objects", h[1:2], h[3:end])
    if isfile(objpath)
        # file is unpacked
        return getobjdata_loose(objpath)
    else
        packpath = joinpath(repo.path, "objects", "pack")
        for idxname in glob(glob"*.idx", packpath)
            offset = lookup_idx(joinpath(packpath,idxname), hash)
            if offset >= 0
                packname = idxname[1:end-4]*".pack"
                return getobjdata_pack(repo, packname, offset)
            end
        end
    end
    error("could not find object")
end

"""
    getobjdata_loose(filename)

Fetch the tag and an array of raw bytes from the "loose" git object name `filename`.
"""
function getobjdata_loose(filename)
    open(filename) do f
        io = ZlibDecompressorStream(f)
        t = ObjCode(chop(readuntil(io, ' ')))
        k = parse(Int, chop(readuntil(io, '\0')))
        GitRawObject(t, read(io, k))
    end
end


function (::Type{T})(repo::GitRepo, hash::SHA1) where {T<:GitObject}
    raw = getobjdata(repo, hash)
    S = checkcode(T, raw.objcode)
    obj = S(raw.data)
    @assert oid(raw) == oid(obj) == hash
    return obj
end
