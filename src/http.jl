using HTTP

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
    @assert pkt2 === nothing

    fetch_refs(b1)
end

