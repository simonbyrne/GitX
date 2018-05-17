const zeroid = "0"^40

function readpktline(io)
    len = parse(Int, String(read(io,4)), 16)
    len == 0 && return nothing
    chomp(String(read(io, len-4)))
end

function fetch_refs(io::IO)
    reflist = Pair{String, SHA1}[]
    capabilities = String[]

    refpkt1 = readpktline(io)
    if refpkt1 == "version=1"
        refpkt1 = readpktline(io)
    end    
    if refpkt1 isa Void
        return reflist, capabilities
    end

    refpkt, capstr = split(refpkt1, '\0', limit=2)
    capabilities = split(capstr, ' ')

    if refpkt == "$zeroid capabilities^{}"
        refpkt = readpktline(io)
	@assert refpkt isa Void
        return reflist, capabilities
    end

    while !isa(refpkt, Void)
	hashstr, ref = split(refpkt,' ',limit=2)
	push!(reflist, ref => SHA1(hashstr))
	refpkt = readpktline(io)
    end
    return reflist, capabilities
end

