module GitX

import SHA
import CodecZlib: ZlibDecompressorStream
import DataStructures: SortedDict

using Glob

export @sha1_str, GitRepo, GitBlob, GitTree, GitCommit, GitTag, treehash

include("hash.jl")
include("repo.jl")
include("objects/object.jl")
include("pack.jl")

include("directory.jl")

include("refs.jl")

include("http.jl")

end # module
