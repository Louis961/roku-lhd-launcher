sub Main()
    runScene("LauncherScene")
end sub

sub RunScreenSaver()
    runScene("ScreensaverScene")
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
