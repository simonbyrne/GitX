"""
    read_idxhead(io::IO)

Read and verify the header of a git packfile index. Only supports v2 indices.
"""
function read_idxhead(io::IO)
    magic = ntoh(read(io, UInt32))
    @assert magic == 0xff_74_4f_63
    version = ntoh(read(io, UInt32))
    @assert version == 2
end

"""
    lookup_idx(filename, hash::SHA1Hash)

Lookup the id `hash` is in the packfile index file `filename`. If contained in the index,
return the absolute offset in the packfile, otherwise return -1.
"""
function lookup_idx(filename, hash::SHA1Hash)
    byte1 = hash.bytes[1]
    open(filename) do io
        # 1. Header
        read_idxhead(io)

        # 2. Fan
        if byte1 == 0
            i = zero(UInt32)
        else
            skip(io, 4*(byte1-1))
            i = ntoh(read(io, UInt32))
        end
        skip(io, 4*(255-byte1))
        i_max = ntoh(read(io, UInt32)) # final element of fan

        # 3. SHA1
        skip(io, 20*i) # start point
        while true
            if i >= i_max
                # hash is not in index
                return Int64(-1)
            end
            i_hash = read(io, SHA1Hash)
            if i_hash == hash
                break
            elseif i_hash > hash
                # hash is not in index
                return Int64(-1)
            end
            i += 1
        end
        skip(io, 20*(i_max - i - 1))

        # 4. CRC
        skip(io, 4*i_max)

        # 5. offset
        skip(io, 4*i)
        j = ntoh(read(io, UInt32))
        if j < 0x8000_0000
            # offsets < 2GB
            return Int64(j)
        end
        skip(io, 4*(i_max - i - 1))

        # 6. large files only
        j -= 0x8000_0000
        skip(io, 8*j)
        return Int64(ntoh(read(io, UInt64)))
    end
end


function read_idx(filename)
    byte1 = hash.bytes[1]
    open(filename) do f
        # 1. Header
        read_idxhead(io)

        # 2. Fan
        skip(io, 4*255)
        i_max = ntoh(read(io, UInt32))

        # 3. SHA1
        hashes = read(io, SHA1Hash, i_max)

        # 4. offset
        offsets = Int64.(ntoh.(read(io, UInt32, i_max)))
        m = maximum(offsets)

        if m >= 0x8000_0000
            bigoffsets = ntoh.(read(io, Int64, m - 0x8000_0000 + 1))
            for (i,o) in enumerate(offsets)
                if o >= 0x8000_0000
                    offsets[i] = bigoffsets[o - 0x8000_0000 + 1]
                end
            end
        end

        return Dict(zip(hashes, offsets))
    end
end

"""
    read_packhead(io::IO)

Read and verify the header of a git packfile, returning the number of objects
contained. Only supports v2 format.
"""
function read_packhead(io::IO)
    magic = ntoh(read(io, UInt32))
    @assert magic == 0x50_41_43_4b # "PACK"
    version = ntoh(read(io, UInt32))
    @assert version == 2
    nobjs = ntoh(read(io, UInt32))
    return nobjs
end

"""
    t,n = read_packobjhead(io::IO)

Read and verify the individual object header from a git packfile, returning the object type code `t` and size `n`. `t` is one of
 - `OBJ_COMMIT`
 - `OBJ_TREE`
 - `OBJ_BLOB`
 - `OBJ_TAG`
 - `OBJ_OFS_DELTA`
 - `OBJ_REF_DELTA`
"""
function read_packobjhead(io::IO)
    b = read(io,UInt8)
    ismore = b >= 0b1000_0000       # more to follow
    t = ObjCode((b >> 4) & 0b0111)  # object type
    n = Int64(b & 0b1111)           # lowest order bits
    shft = 4
    while ismore
        b = read(io,UInt8)
        ismore = b >= 0b1000_0000
        n = (Int64(b & 0b0111_1111) << shft) | n
        shft += 7
    end
    return t,n
end

"""
    read_offset_varint(io::IO)

Read the variable-length integer format used to encode the offset of `OBJ_OFS_DELTA`
objects.
"""
function read_offset_varint(io::IO)
    b = read(io,UInt8)
    ismore = b >= 0b1000_0000
    n = Int64(b & 0b0111_1111)
    while ismore
        b = read(io,UInt8)
        ismore = b >= 0b1000_0000
        n = ((n+1) << 7) | (b & 0b0111_1111)
    end
    return n
end

"""
    read_delta_varint(io::IO)

Read the variable-length integer format used _inside_ the delta objects to store length of
source and target.
"""
function read_delta_varint(io::IO)
    b = read(io,UInt8)
    ismore = b >= 0b1000_0000
    shft = 7
    n = Int64(b & 0b0111_1111)
    while ismore
        b = read(io,UInt8)
        ismore = b >= 0b1000_0000
        n |= (Int64(b & 0b0111_1111) << shft)
        shft += 7
    end
    return n
end

"""
    getobjdata_pack(repo::GitRepo, packfile::String, offset::Integer)

Return the type code `t` and contents `data` of the object located at `offset` in
`packfile`. `repo` is required to lookup the source for objects stored as `OBJ_REF_DELTA`.
"""
function getobjdata_pack(repo::GitRepo, packfile::String, offset::Integer)
    open(packfile) do io
        read_packhead(io)
        seek(io, offset)
        getobjdata_pack(repo, packfile, offset, io)
    end
end

function getobjdata_pack(repo::GitRepo, packfile::String, offset::Integer, io::IO)
    t, len = read_packobjhead(io)
    if 0x01 <= UInt8(t) <= 0x04
        zio = ZlibDecompressorStream(io, stop_on_end=true)
        return GitRawObject(t, read(zio, len))
    else
        if t == Obj.offset_delta
            reloffset = read_offset_varint(io)
            rawsrc = getobjdata_pack(repo, packfile, offset - reloffset)
        elseif t == Obj.ref_delta
            srchash = read(io, SHA1Hash)
            rawsrc = getobjdata(repo, refhash)
        else
            error("Invalid tag $t")
        end

        src = IOBuffer(rawsrc.data)
        delta = ZlibDecompressorStream(io, stop_on_end=true)
        sourcelen = read_delta_varint(delta)
        targetlen = read_delta_varint(delta)

        out = IOBuffer(targetlen)
        while position(out) < targetlen
            op = read(delta, UInt8)
            if op >= 0b1000_0000
                # copy operation
                u = UInt32(0) # position
                for i = 0:3
                    if op & (0b0000_0001 << i) != 0
                        u |= UInt32(read(delta, UInt8)) << (8*i)
                    end
                end

                k = UInt32(0) # number of bytes to copy
                for i = 0:2
                    if op & (0b0001_0000 << i) != 0
                        k |= UInt32(read(delta, UInt8)) << (8*i)
                    end
                end

                seek(src, Int(u))
                write(out, read(src, Int(k)))
            else
                # insert operation
                write(out, read(delta, Int(op)))
            end
        end
        return GitRawObject(tt, take!(out))
    end
end


function idxname(packfile::String)
    endswith(packfile, ".pack") || error("invalid packfile name $packfile")
    packfile[1:end-4]*"idx"
end


function buildindex(repo, packfile, idxfile=idxname(packfile))
    open(packfile) do pack
        open(idxfile,"w") do idx
            d = SortedDict{SHA1Hash, Tuple{Int64, UInt32}}()

            nobjs = read_packhead(pack)
            for i = 1:nobjs
                raw = getobjdata_pack(repo, packfile, position(pack), pack)
                hash = oid(raw)
                crc  = crc32c(raw.data)
                d[hash] => (length(data), crc)
            end
        end
    end
end
