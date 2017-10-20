function getref(repo::GitRepo, ref::AbstractString)
    refpath = joinpath(repo.path, "refs", ref)
    if isfile(refpath)
        # look in refs subdirectory
        return SHA1Hash(readline(refpath))
    else
        packedref = joinpath(repo.path, "packed-refs")
        if isfile(packedref)
            for str in eachline(packedref)
                # '#' are comments
                # '^' are peeled refs of the preceding lines
                if !startswith(str, ('#','^')) && ref == str[47:end]
                    return SHA1Hash(str[1:40])
                end
            end
        end
    end
    error("Could not find $ref")
end
