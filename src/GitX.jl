module GitX

using SHA
import Base: SHA1
import CodecZlib: ZlibDecompressorStream
import DataStructures: SortedDict

using Glob

export @sha1_str, GitRepo, GitBlob, GitTree, GitCommit, GitTag, treehash, SHA1

include("hash.jl")
include("repo.jl")
include("objects/object.jl")
include("pack.jl")

include("directory.jl")

include("refs.jl")

include("fetch-pack.jl")

end # module
