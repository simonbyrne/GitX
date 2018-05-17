struct GitCommit <: GitObject
    tree::SHA1
    parents::Vector{SHA1}
    author::String
    committer::String
    message::String
end

function GitCommit(data::Vector{UInt8})
    io = IOBuffer(data)
    fieldname = readuntil(io, ' ')
    @assert fieldname == "tree "
    tree = SHA1(readline(io))

    parents = SHA1[]
    fieldname = readuntil(io, ' ')
    while fieldname == "parent "
        push!(parents, SHA1(readline(io)))
        fieldname = readuntil(io, ' ')
    end

    @assert fieldname == "author "
    author = readline(io)

    fieldname = readuntil(io, ' ')
    @assert fieldname == "committer "
    committer = readline(io)

    empty = readline(io)
    @assert empty == ""

    message = String(read(io))
    GitCommit(tree, parents, author, committer, message)
end

function Base.sizeof(commit::GitCommit)
    4 + 1 + 2*20 + 1 +
    length(commit.parents) * (6 + 1 + 2*20 + 1) +
    6 + 1 + sizeof(commit.author) + 1 +
    9 + 1 + sizeof(commit.committer) + 1 +
    1 +
    sizeof(commit.message)
end

function oid(commit::GitCommit)
    ctx = SHA.SHA1_CTX()
    SHA.update!(ctx, Vector{UInt8}("commit $(sizeof(commit))\0"))
    SHA.update!(ctx, Vector{UInt8}("tree $(commit.tree)\n"))
    for parent in commit.parents
        SHA.update!(ctx, Vector{UInt8}("parent $(parent)\n"))
    end
    SHA.update!(ctx, Vector{UInt8}("author $(commit.author)\n"))
    SHA.update!(ctx, Vector{UInt8}("committer $(commit.committer)\n"))
    SHA.update!(ctx, Vector{UInt8}("\n"))
    SHA.update!(ctx, Vector{UInt8}(commit.message))
    return SHA1(SHA.digest!(ctx))
end
