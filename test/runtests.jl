using GitX
using Base.Test

# 1. Set up a git repository

## set env vars to ensure commit hashes are constant
gitenv = Dict(
"GIT_AUTHOR_NAME"  => "Test Name",
"GIT_AUTHOR_EMAIL" => "test@example.com",
"GIT_AUTHOR_DATE"  => "2017-09-30T17:18:19+0000",
"GIT_COMMITTER_NAME"  => "Test Name",
"GIT_COMMITTER_EMAIL" => "test@example.com",
"GIT_COMMITTER_DATE"  => "2017-09-30T17:18:19+0000")

dir = mktempdir()
cd(dir) do
    withenv(gitenv...) do
        run(`git init --quiet`)
        write("a.txt", "aaaa")
        run(`git add a.txt`)
        run(`git commit --quiet -m "add a.txt"`)

        mkdir("sub")
        write("sub/b.txt", "bbbb")
        run(`git add sub/b.txt`)
        run(`git commit --quiet -m "add b.txt"`)
        run(`git tag -a tagA -m "create tagA"`)

        write("sub.foo", "sub")
        run(`git add sub.foo`)
        run(`git commit --quiet -m "add sub.foo"`)
    end
end

cmt1_id = sha1"c1f9bdd7026000b90c7d8d22ec850861d7d44c7e"
cmt2_id = sha1"61e8feeb89ce70760d9c59480f0d22f972ff04c8"
cmt3_id = sha1"9c9d920b41639bef062c06dcde56c7a2afd6d0dd"

bloba_id = sha1"7284ab4d2836271d66b988ae7d037bd6ef0d5d15"
blobb_id = sha1"6484fb6f9cea3887578def1ba0aa96fcce279f5b"

tree1_id = sha1"37ec9e1621eef35a1590a2f0cf101cb522b95269"
tree2_id = sha1"4391a88722ea68cf673478f54f5c670c8f03e6e0"
tree2sub_id = sha1"57961903709ed4eb0a5359704c951f9e1f7cad3e"
tree3_id = sha1"aa060605cdcac40584a0d61b48ce31ca8ac4a105"

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

# refs
@test GitX.getref(repo, "heads/master") == cmt3_id
@test GitX.getref(repo, "tags/tagA") == tag_id


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

# refs
@test GitX.getref(repo, "heads/master") == cmt3_id
@test GitX.getref(repo, "tags/tagA") == tag_id

# 3. Directory
cd(dir) do
    @test treehash(["a.txt"]) == tree1_id
    @test treehash(["a.txt","sub/b.txt"]) == tree2_id
    @test treehash(["a.txt","sub/b.txt","sub.foo"]) == tree3_id
end

@test GitX.oid(dir) == tree3_id

# 4. Remotes
remotedir = mktempdir()
cd(remotedir) do
    run(`git init --quiet --bare`)
end

buf = IOBuffer(read(`git-upload-pack --advertise-refs $remotedir`))
refs, caps = GitX.fetch_refs(buf)
@test isempty(refs)

cd(dir) do
    withenv(gitenv...) do
        run(`git remote add r1 $remotedir`)
        run(`git push --quiet r1 master`)
    end
end

buf = IOBuffer(read(`git-upload-pack --advertise-refs $remotedir`))
refs, caps = GitX.fetch_refs(buf)

@test length(refs) == 2
@test refs[1] == ("HEAD" => cmt3_id)
@test refs[2] == ("refs/heads/master" => cmt3_id)
@test !isempty(caps)


# 5. Cleanup
rm(dir, recursive=true)
rm(remotedir, recursive=true)
