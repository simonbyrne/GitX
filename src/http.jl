using HTTP

const zeroid = "0"^40

function readpktline(io)
    len = parse(Int, String(read(io,4)), 16)
    len == 0 && return nothing
    chomp(String(read(io, len-4)))
end


function fetch_cap(url)
    servicename = "git-upload-pack"
    r1 = HTTP.get("$url/info/refs?service=$servicename",["Git-Protocol" => "version=1"]; verbose=2)
    @assert r1.status in (200, 304)

    h1 = Dict(r1.headers)
    @assert h1["Content-Type"] == "application/x-$servicename-advertisement"

    b1 = IOBuffer(r1.body)
    pkt1 = readpktline(b1)
    @assert pkt1 == "# service=$servicename"

    pkt2 = readpktline(b1)
    @assert pkt2 isa Void

    refpkt1 = readpktline(b1)
    if refpkt1 == "version=1"
        refpkt1 = readpktline(b1)
    end
    refpkt, capstr = split(refpkt1, '\0', limit=2)
    capabilities = split(capstr, ' ')
    reflist = Pair{String, SHA1Hash}[]

    if refpkt == "$zeroid capabilities^{}"
        refpkt = readpktline(b1)
	@assert refpkt isa Void
    else
	while !isa(refpkt, Void)
	    hashstr, ref = split(refpkt,' ',limit=2)
	    push!(reflist, ref => SHA1Hash(hashstr))
	    refpkt = readpktline(b1)
	end
    end
    
    return reflist, capabilities
end

