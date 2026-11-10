sub Main()
    runScene("LauncherScene")
end sub

sub RunScreenSaver()
    ' Merged build: LHD is the app; Daybreak's screens are the screensaver.
    RunDaybreak("screensaver")
end sub

sub runScene(name as String)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene(name)
    screen.Show()
    while true
        msg = wait(0, port)
    end while
end sub

' From Daybreak (MIT, roberjo/tv-check): its scene runs both the app and the
' screensaver, and fetches every feed on the TV itself.
sub RunDaybreak(mode as string)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("DaybreakScene")
    screen.Show()
    syslog = CreateObject("roSystemLog")
    if syslog <> invalid
        syslog.SetMessagePort(port)
        syslog.EnableType("bandwidth.minute")
    end if
    scene.mode = mode
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.IsScreenClosed() then return
        if type(msg) = "roSystemLogEvent"
            info = msg.GetInfo()
            if info.LogType = "bandwidth.minute" then scene.bandwidthKbps = info.bandwidth
        end if
    end while
end sub
