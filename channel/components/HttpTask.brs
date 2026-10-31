sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    url = m.top.url
    if url = "" then
        m.top.responseCode = -1
        return
    end if

    transfer = CreateObject("roUrlTransfer")
    transfer.SetUrl(url)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.RetainBodyOnError(true)

    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)

    ok = false
    if m.top.method = "POST" then
        ok = transfer.AsyncPostFromString(m.top.body)
    else
        ok = transfer.AsyncGetToString()
    end if

    if not ok then
        m.top.responseCode = -1
        return
    end if

    msg = wait(15000, port)
    if type(msg) = "roUrlEvent" then
        m.top.responseBody = msg.GetString()
        m.top.responseCode = msg.GetResponseCode()
    else
        m.top.responseCode = -2
    end if
end sub
