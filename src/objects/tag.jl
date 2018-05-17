struct GitTag <: GitObject
    object::SHA1
    objcode::ObjCode
    tag::String
    tagger::String
    message::String
end


function GitTag(data::Vector{UInt8})
    io = IOBuffer(data)
    fieldname = readuntil(io, ' ')
    @assert fieldname == "object "
    object = SHA1(readline(io))

    fieldname = readuntil(io, ' ')
    @assert fieldname == "type "
    objcode = ObjCode(readline(io))

    fieldname = readuntil(io, ' ')
    @assert fieldname == "tag "
    tag = readline(io)

    fieldname = readuntil(io, ' ')
    @assert fieldname == "tagger "
    tagger = readline(io)

    empty = readline(io)
    @assert empty == ""

    message = String(read(io))
    GitTag(object, objcode, tag, tagger, message)
end

function Base.sizeof(tag::GitTag)
    6 + 1 + 2*20 + 1 +
    4 + 1 + sizeof(string(tag.objcode)) + 1 +
    3 + 1 + sizeof(tag.tag) + 1 +
    6 + 1 + sizeof(tag.tagger) + 1 +
    1 +
    sizeof(tag.message)
end

function oid(tag::GitTag)
    ctx = SHA.SHA1_CTX()
    SHA.update!(ctx, Vector{UInt8}("tag $(sizeof(tag))\0"))
    SHA.update!(ctx, Vector{UInt8}("object $(tag.object)\n"))
    SHA.update!(ctx, Vector{UInt8}("type $(tag.objcode)\n"))
    SHA.update!(ctx, Vector{UInt8}("tag $(tag.tag)\n"))
    SHA.update!(ctx, Vector{UInt8}("tagger $(tag.tagger)\n"))
    SHA.update!(ctx, Vector{UInt8}("\n"))
    SHA.update!(ctx, Vector{UInt8}(tag.message))
    return SHA1(SHA.digest!(ctx))
end
