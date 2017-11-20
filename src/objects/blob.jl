struct GitBlob <: GitObject
    data::Vector{UInt8}
end

function Base.sizeof(blob::GitBlob)
    length(blob.data)
end

function oid(blob::GitBlob)
    ctx = SHA.SHA1_CTX()
    SHA.update!(ctx, Vector{UInt8}("blob $(sizeof(blob))\0"))
    SHA.update!(ctx, blob.data)
    return SHA1Hash(SHA.digest!(ctx))
end

oid(filename::String) = oid(GitBlob(Mmap.mmap(filename)))
   
