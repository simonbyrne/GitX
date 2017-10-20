module Obj
@enum ObjCode::UInt8 commit=1 tree=2 blob=3 tag=4 offset_delta=6 ref_delta=7
end
import .Obj.ObjCode

function ObjCode(name::AbstractString)
    name == "commit" ? Obj.commit :
    name == "tree"   ? Obj.tree   :
    name == "blob"   ? Obj.blob   :
    name == "tag"    ? Obj.tag    :
    error("unknown tag type $name")
end

immutable GitRawObject <: GitObject
    objcode::ObjCode
    data::Vector{UInt8}
end

function oid(raw::GitRawObject)
    ctx = SHA.SHA1_CTX()
    SHA.update!(ctx, Vector{UInt8}("$(raw.objcode) $(sizeof(raw.data))\0"))
    SHA.update!(ctx, raw.data)
    return SHA1Hash(SHA.digest!(ctx))
end
