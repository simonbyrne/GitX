module GitX

import SHA
import CodecZlib: ZlibDecompressorStream
using Glob

export @sha1_str, GitRepo, GitBlob, GitTree, GitCommit, GitTag

include("hash.jl")
include("repo.jl")
include("objects/object.jl")
include("pack.jl")

include("refs.jl")

end # module
