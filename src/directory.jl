
# store directory with trailing slash to ensure correct order
# https://github.com/mirage/irmin/issues/352


struct GitMutableTree
    entries::SortedDict{String,Tuple{GitMode,Any},Base.Order.ForwardOrdering}
    GitMutableTree() = new(SortedDict{String,Tuple{GitMode,Any}}(Base.Order.Forward))
end

function Base.setindex!(mtree::GitMutableTree, value, path::String)
    n = findfirst(path, '/')
    if n == 0
        # file
        mtree.entries[path] = value
    else
        base = path[1:n]
        rpath = path[n+1:end]
        # waiting on:
        #   https://github.com/JuliaCollections/DataStructures.jl/pull/336
        # rmode, rtree = get!(() -> (mode_dir, GitMutableTree()), mtree.entries, base)
        if !haskey(mtree.entries, base)
            mtree.entries[base] = (mode_dir, GitMutableTree())
        end
        rmode, rtree = mtree.entries[base]
        rtree[rpath] = value
    end
end

function Base.convert(::Type{GitTree}, mtree::GitMutableTree)
    entries = GitTreeEntry[]
    for (name, (mode, obj)) in mtree.entries
        if endswith(name, '/')
            name = chop(name)
        end
        if obj isa SHA1Hash
            hash = obj
        else
            hash = oid(convert(GitTree, obj))
        end
        push!(entries,GitTreeEntry(mode, name, hash))
    end
    GitTree(entries)
end

oid(mtree::GitMutableTree) = oid(convert(GitTree, mtree))

function treehash(filelist)
    mtree = GitMutableTree()
    for filename in filelist
        # TODO: deal with executable & symlinks
        hash = oid(filename)
        mtree[filename] = (mode_normal, hash)
    end
    return oid(mtree)
end
