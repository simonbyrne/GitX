using GitX
using Base.Test

# 1. Set up a git repository

## set env vars to ensure commit hashes are constant
ENV["GIT_AUTHOR_NAME"]  = "Test Name"
ENV["GIT_AUTHOR_EMAIL"] = "test@example.com"
ENV["GIT_AUTHOR_DATE"]  = "2017-09-30T17:18:19+0000"

ENV["GIT_COMMITTER_NAME"]  = "Test Name"
ENV["GIT_COMMITTER_EMAIL"] = "test@example.com"
ENV["GIT_COMMITTER_DATE"]  = "2017-09-30T17:18:19+0000"

@show dir = mktempdir()
cd(dir) do
    run(`git init --quiet`)
    write("a.txt", "aaaa")
    run(`git add a.txt`)
    run(`git commit --quiet -m "add a.txt"`)
    mkdir("sub")
    write("sub/b.txt", "bbbb")
    run(`git add sub/b.txt`)
    run(`git commit --quiet -m "add b.txt"`)
    run(`git tag -a tagA -m "create tagA"`)
end

cmt1_id = sha1"c1f9bdd7026000b90c7d8d22ec850861d7d44c7e"
cmt2_id = sha1"61e8feeb89ce70760d9c59480f0d22f972ff04c8"

bloba_id = sha1"7284ab4d2836271d66b988ae7d037bd6ef0d5d15"
blobb_id = sha1"6484fb6f9cea3887578def1ba0aa96fcce279f5b"

tree1_id = sha1"37ec9e1621eef35a1590a2f0cf101cb522b95269"
tree2_id = sha1"4391a88722ea68cf673478f54f5c670c8f03e6e0"
tree2sub_id = sha1"57961903709ed4eb0a5359704c951f9e1f7cad3e"

tag_id = sha1"fa4891b4d2ea7b3d79cb37e38ac6391a98aff2cb"



repo = GitRepo(joinpath(dir,".git"))

# commits
cmt1 = GitCommit(repo, cmt1_id)
@test isempty(cmt1.parents)
@test cmt1.tree == tree1_id
@test cmt1.message == "add a.txt\n"

cmt2 = GitCommit(repo, cmt2_id)
@test cmt2.parents == [cmt1_id]
@test cmt2.tree == tree2_id

# trees
tree1 = GitTree(repo, tree1_id)
@test tree1.entries[1].name == "a.txt"
@test tree1.entries[1].hash == bloba_id

# blobs
bloba = GitBlob(repo, bloba_id)
@test String(bloba.data) == "aaaa"

# tags
tag = GitTag(repo, tag_id)
@test tag.object == cmt2_id
@test tag.tag == "tagA"
@test tag.message == "create tagA\n"


# 2. Pack files
# run GC to pack all the objects
cd(dir) do
    run(`git gc --quiet`)
end
# verify objects are packed
@test length(readdir(joinpath(dir,".git","objects"))) <= 2


cmt1 = GitCommit(repo, cmt1_id)
@test isempty(cmt1.parents)
@test cmt1.tree == tree1_id
@test cmt1.message == "add a.txt\n"

cmt2 = GitCommit(repo, cmt2_id)
@test cmt2.parents == [cmt1_id]
@test cmt2.tree == tree2_id

# trees
tree1 = GitTree(repo, tree1_id)
@test tree1.entries[1].name == "a.txt"
@test tree1.entries[1].hash == bloba_id

# blobs
bloba = GitBlob(repo, bloba_id)
@test String(bloba.data) == "aaaa"

# tags
tag = GitTag(repo, tag_id)
@test tag.object == cmt2_id
@test tag.tag == "tagA"
@test tag.message == "create tagA\n"


# 3. Clean up
rm(dir, recursive=true)
