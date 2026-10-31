sub init()
    m.helper = lhdHelper()
    m.photoTick = 0
    loadInterval()
    m.photoStartSec = nowSec()
    m.active = 0
    m.pending = false
    m.fadeRunning = false
    m.driftT = 0
    m.incoming = invalid
    m.outgoing = invalid

    m.photoA = m.top.findNode("photoA")
    m.photoB = m.top.findNode("photoB")
    m.photoGroup = m.top.findNode("photoGroup")
    m.barFill = m.top.findNode("barFill")
    m.content = m.top.findNode("content")
    m.clock = m.top.findNode("clock")
    m.date = m.top.findNode("date")
    m.weather = m.top.findNode("weather")

    fontNodes()
    styleLabels()

    m.photoA.observeField("loadStatus", "onLoaded")
    m.photoB.observeField("loadStatus", "onLoaded")

    tickTimer = m.top.findNode("tick")
    tickTimer.observeField("fire", "onTick")
    tickTimer.control = "start"

    driftTimer = m.top.findNode("drift")
    driftTimer.observeField("fire", "onDrift")
    driftTimer.control = "start"

    photoTimer = m.top.findNode("photoTimer")
    photoTimer.duration = m.photoInterval
    photoTimer.observeField("fire", "nextPhoto")
    photoTimer.control = "start"

    fadeTimer = m.top.findNode("fadeTimer")
    fadeTimer.observeField("fire", "onFade")
    m.fadeTimer = fadeTimer

    weatherTimer = m.top.findNode("weatherTimer")
    weatherTimer.observeField("fire", "fetchWeather")
    weatherTimer.control = "start"

    updateClock()
    fetchWeather()
    nextPhoto()
end sub

sub loadInterval()
    sec = CreateObject("roRegistrySection", "launcher")
    raw = sec.Read("photo_interval")
    m.photoInterval = 60
    if raw <> "" then
        v = Val(raw)
        if v >= 10 then m.photoInterval = Int(v)
    end if
end sub

sub fontNodes()
    m.fontClock = fontNode("pkg:/fonts/Outfit-Light.ttf", 72)
    m.fontDate = fontNode("pkg:/fonts/Outfit-Regular.ttf", 30)
    m.fontWeather = fontNode("pkg:/fonts/Outfit-Regular.ttf", 26)
end sub

function fontNode(uri as String, size as Integer) as Object
    f = CreateObject("roSGNode", "Font")
    f.uri = uri
    f.size = size
    return f
end function

sub styleLabels()
    m.clock.font = m.fontClock
    m.clock.color = "0xF4F3F0FF"
    m.date.font = m.fontDate
    m.date.color = "0xF4F3F0A8"
    m.weather.font = m.fontWeather
    m.weather.color = "0xF4F3F066"
end sub

sub onTick()
    updateClock()
end sub

sub updateClock()
    dt = CreateObject("roDateTime")
    dt.Mark()
    dt.ToLocalTime()

    h = dt.GetHours()
    mi = dt.GetMinutes()
    suffix = "AM"
    if h >= 12 then suffix = "PM"
    h12 = h mod 12
    if h12 = 0 then h12 = 12
    minute = StrI(mi)
    if mi < 10 then minute = "0" + StrI(mi)
    m.clock.text = StrI(h12) + ":" + minute + " " + suffix

    days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
    wd = dt.GetDayOfWeek()
    day = dt.GetDayOfMonth()
    mo = dt.GetMonth()
    m.date.text = days[wd] + ", " + StrI(day) + " " + months[mo - 1]
end sub

sub onDrift()
    m.driftT = m.driftT + 0.1
    angle = m.driftT * 6.283185 / 120.0
    m.content.translation = [4.0 * Sin(angle), 2.0 * Cos(angle)]

    frac = 1.0 - (nowSec() - m.photoStartSec) / m.photoInterval
    if frac < 0 then frac = 0
    if frac > 1 then frac = 1
    m.barFill.width = 260 * frac
end sub

function nowSec() as Integer
    d = CreateObject("roDateTime")
    d.Mark()
    return d.AsSeconds()
end function

sub nextPhoto()
    m.photoTick = m.photoTick + 1
    m.photoStartSec = nowSec()
    url = m.helper + "/photo?t=" + StrI(m.photoTick)
    if m.active = 0 then
        m.photoB.uri = url
        m.photoB.opacity = 0
        m.incoming = m.photoB
        m.outgoing = m.photoA
    else
        m.photoA.uri = url
        m.photoA.opacity = 0
        m.incoming = m.photoA
        m.outgoing = m.photoB
    end if
    m.photoGroup.removeChild(m.incoming)
    m.photoGroup.appendChild(m.incoming)
    m.pending = true
end sub

sub onLoaded()
    if not m.pending then return
    if m.incoming = invalid then return
    if m.incoming.loadStatus = "loaded" then
        m.pending = false
        m.fadeRunning = true
        m.fadeTimer.control = "start"
    end if
end sub

sub onFade()
    if not m.fadeRunning then return
    if m.incoming = invalid or m.outgoing = invalid then return
    op = m.incoming.opacity + 0.1
    if op >= 1.0 then
        m.incoming.opacity = 1.0
        m.outgoing.opacity = 0.0
        m.active = 1 - m.active
        m.fadeRunning = false
        m.fadeTimer.control = "stop"
    else
        m.incoming.opacity = op
    end if
end sub

sub fetchWeather()
    url = "https://api.open-meteo.com/v1/forecast?latitude=39.7285&longitude=-121.8375&current=temperature_2m,weather_code&temperature_unit=fahrenheit&timezone=auto"
    task = CreateObject("roSGNode", "HttpTask")
    task.url = url
    task.method = "GET"
    task.observeField("responseCode", "onWeather")
    task.control = "RUN"
    m.weatherTask = task
end sub

sub onWeather()
    task = m.weatherTask
    if task = invalid then return
    if task.responseCode = 200 then
        data = ParseJson(task.responseBody)
        if data <> invalid then
            if data.current <> invalid then
                temp = data.current["temperature_2m"]
                code = data.current["weather_code"]
                if temp <> invalid and code <> invalid then
                    m.weather.text = StrI(Int(temp + 0.5)) + Chr(176) + "  " + weatherText(Int(code))
                end if
            end if
        end if
    end if
end sub

function weatherText(code as Integer) as String
    if code = 0 then return "Clear"
    if code >= 1 and code <= 3 then return "Partly cloudy"
    if code = 45 or code = 48 then return "Fog"
    if code >= 51 and code <= 57 then return "Drizzle"
    if code >= 61 and code <= 67 then return "Rain"
    if code >= 71 and code <= 77 then return "Snow"
    if code >= 80 and code <= 82 then return "Showers"
    if code >= 95 then return "Storm"
    return "Clear"
end function
