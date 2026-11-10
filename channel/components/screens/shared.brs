' Screens: pieces shared by several screens.

' --- shared pieces ----------------------------------------------------------------

' The Sky card's sentence and tip for a moon phase name from moonPhase().
function moonWords(name as string) as object
    if name = "Full moon" then return {line: "The moon is full", tip: "Bright enough for an evening walk, too bright for faint stars."}
    if name = "New moon" then return {line: "It's a new moon", tip: "The darkest skies of the month: the best night for stars and the Milky Way."}
    if Right(name, 7) = "quarter" then return {line: "The moon is at " + LCase(name), tip: "Half lit. Binoculars show craters along the shadow line."}
    tip = "A thin moon leaves the sky dark for stars."
    if Right(name, 7) = "gibbous" then tip = "A bright moon washes out faint stars; planets still shine through."
    return {line: "The moon is a " + LCase(name), tip: tip}
end function

function greeting(d as object) as string
    h = tHour(d.now)
    part = "evening"
    if h >= 4 and h < 12
        part = "morning"
    else if h >= 12 and h < 17
        part = "afternoon"
    end if
    return "Good " + part + ", " + d.household
end function

sub header(g as object, eyebrow as string, title as string, accent = "#FFD166" as string, withClock = true as boolean)
    uiLabel(g, 112, 62, eyebrow, 24, accent)
    w = 1696
    if withClock then w = 1200
    uiText(g, 112, 100, title, 76, 500, "Outfit", "#F4F3F0", w)
    if withClock then addClock(g, 1808, 82, 104, 300, "right")
end sub

sub addClock(g as object, x as integer, y as integer, size as integer, weight as integer, align as string, color = "#F4F3F0" as string)
    clock = uiText(g, x, y, "", size, weight, "Outfit", color)
    ampm = uiText(g, x, y, "", Int(size * 0.33), 300, "Outfit", "#F4F3F0CC")
    if color <> "#F4F3F0" then ampm.color = hexc(color)
    m.clockNodes = {clock: clock, ampm: ampm, x: x, y: y, size: size, align: align}
end sub

sub updateClock()
    c = m.clockNodes
    if c = invalid then return
    now = tNowWall()
    h = tHour(now)
    suffix = "AM"
    if h >= 12 then suffix = "PM"
    h12 = h mod 12
    if h12 = 0 then h12 = 12
    c.clock.text = h12.ToStr() + ":" + tPad((now mod 3600) \ 60, 2)
    c.ampm.text = suffix
    cw = uiWidth(c.clock, c.size)
    aw = uiWidth(c.ampm, Int(c.size * 0.33))
    drop = Int(c.size * 0.6)
    if c.align = "right"
        c.ampm.translation = [c.x - aw, c.y + drop]
        c.clock.translation = [c.x - aw - 16 - cw, c.y]
    else
        c.clock.translation = [c.x, c.y]
        c.ampm.translation = [c.x + cw + 20, c.y + drop]
    end if
end sub

'
' Full-screen photo, or a plain fill when memory is low (a decoded 1080p photo is 8 MB).
' Four ways for the wallpaper itself to move, chosen by config/family.json "wallpaper":
'   static    - the photo, still. What Daybreak shipped.
'   kenburns  - the photo drifts in and out of a slow zoom for the whole 42 s.
'   grade     - a tinted layer over the photo, colour and strength from weather and hour.
'   slideshow - a second photo crossfades in after 8 s.
'   skies     - no photo: a generated sky picked by weather code and hour.
' Sets m.wallpaperCredit to the photo, which buildScreen credits in the corner.
sub uiWallpaper(g as object, d as object, id as string, fill as string, packaged = "" as string)
    w = invalid
    if d.wallpapers <> invalid then w = d.wallpapers[id]
    mode = wallMode(d)
    m.wallpaperCredit = invalid  ' a sky or a plain fill has no photo to credit
    if m.lowMemory = true
        uiRect(g, 0, 0, 1920, 1080, fill)
    else if mode = "skies"
        uiImage(g, "pkg:/images/sky_" + skyKind(d) + ".png", 0, 0, 1920, 1080)
        uiRect(g, 0, 0, 1920, 1080, fill, wallpaperDim(id) * 0.62)
    else if w <> invalid
        p = uiImage(g, w.uri, 0, 0, 1920, 1080)
        if mode = "kenburns" then kenBurns(p)
        if mode = "slideshow" then slideshow(g, d, id)
        uiRect(g, 0, 0, 1920, 1080, fill, wallpaperDim(id))
        if mode = "grade" then weatherGrade(g, d)
        m.wallpaperCredit = w
    else if packaged <> ""
        uiImage(g, packaged, 0, 0, 1920, 1080)
    else
        uiRect(g, 0, 0, 1920, 1080, fill)
    end if
end sub

function wallMode(d as object) as string
    if d <> invalid and d.wallMode <> invalid then return d.wallMode
    return "static"
end function

' Local hour, honouring the preview harness's fixed clock.
function wallHour() as integer
    dt = CreateObject("roDateTime")
    if m.testNowWall <> invalid
        dt.FromSeconds(m.testNowWall)
        return dt.GetHours()
    end if
    dt.ToLocalTime()
    return dt.GetHours()
end function

' Slow zoom that returns to where it started, so a 30 s screen never ends mid-move.
sub kenBurns(p as object)
    p.scaleRotateCenter = [960.0, 540.0]
    p.scale = [1.0, 1.0]
    if m.testNowWall <> invalid
        ' preview: mid-zoom, the frame the animation would pass through
        p.scale = [1.03, 1.03]
        return
    end if
    an = p.createChild("Animation")
    an.duration = 42
    an.repeat = true
    fi = an.createChild("Vector2DFieldInterpolator")
    fi.field = "scale"
    fi.key = [0.0, 0.5, 1.0]
    fi.keyValue = [[1.0, 1.0], [1.065, 1.065], [1.0, 1.0]]
    fi.repeat = true
end sub

' A second photo, crossfaded in after 8 s and left there for the rest of the screen.
sub slideshow(g as object, d as object, id as string)
    other = invalid
    if d.wallpapers = invalid then return
    for each k in d.wallpapers
        if k <> id and d.wallpapers[k] <> invalid then other = d.wallpapers[k]
        if other <> invalid then exit for
    end for
    if other = invalid then return
    p = uiImage(g, other.uri, 0, 0, 1920, 1080)
    p.opacity = 0.0
    if m.testNowWall <> invalid
        ' preview: the halfway point of the crossfade
        p.opacity = 0.55
        return
    end if
    an = p.createChild("Animation")
    an.duration = 2.4
    an.delay = 8.0
    op = an.createChild("FloatFieldInterpolator")
    op.field = "opacity"
    op.key = [0.0, 1.0]
    op.keyValue = [0.0, 1.0]
end sub

' Weather grade: a warm wash in sun, cool in rain, violet at night or in a storm.
sub weatherGrade(g as object, d as object)
    c = uiColors()
    hour = wallHour()
    code = 0
    if d.weather <> invalid then code = d.weather.code
    kind = wxKind(code)
    col = c.blue
    op = 0.16
    if kind = "sun" then
        col = c.amber
        op = 0.16
    else if kind = "storm"
        col = c.violet
        op = 0.24
    else if kind = "snow" or kind = "cloud"
        col = c.text
        op = 0.10
    end if
    if hour >= 20 or hour < 6 then
        col = c.violet
        op = 0.22
    else if hour >= 17 then
        col = c.amber
        op = 0.14
    end if
    uiRect(g, 0, 0, 1920, 1080, col, op)
end sub

' Which generated sky fits right now: hour first, then the weather code.
function skyKind(d as object) as string
    hour = wallHour()
    if hour < 6 or hour >= 20 then return "night"
    if hour >= 17 then return "dusk"
    code = 0
    if d.weather <> invalid then code = d.weather.code
    kind = wxKind(code)
    if kind = "sun" then return "clear"
    if kind = "snow" then return "cloud"
    if kind = "moon" then return "night"
    return kind
end function

' How much of the screen's fill covers a wallpaper: the photo screens show
' more of it, card screens keep it a quiet texture behind the cards.
function wallpaperDim(id as string) as float
    dims = {ambient: 0.55, briefing: 0.78, season: 0.7}
    if dims.DoesExist(id) then return dims[id]
    return 0.82
end function

sub uiBackdrop(g as object, uri as string, fallback as string)
    if m.lowMemory = true then uiRect(g, 0, 0, 1920, 1080, fallback) else uiImage(g, uri, 0, 0, 1920, 1080)
end sub

' "as of 9:40 AM" when a source's data is older than twice its refresh interval.
function asOfText(d as object, source as string) as string
    if d.asOf = invalid or d.asOf[source] = invalid then return ""
    return "as of " + tClock(d.asOf[source])
end function

function soonGames(d as object) as object
    out = []
    for each gm in d.games
        if gm.short <> "LC" and not gm.tbd and (gm.state = "in" or (gm.start - d.now) <= 6 * 3600) then out.Push(gm)
    end for
    return out
end function

' "Live · 21–17 · Q3 4:12" for a game in progress.
function liveText(gm as object) as string
    t = "Live · " + gm.my + "–" + gm.their
    if gm.status <> invalid and gm.status <> "" then t = t + " · " + gm.status
    return t
end function

' A team's logo as a faint watermark (drawn before the card's text, so behind
' it). The TV loads it from ESPN's CDN and decodes it at the drawn size; none
' for teams without one (LaGrange College) or in low-memory mode.
sub teamLogo(g as object, uri as dynamic, x as float, y as float, size as integer, opacity = 0.16 as float)
    if not isText(uri) or uri = "" or m.lowMemory = true then return
    p = uiImage(g, uri, x, y, size, size, "", opacity)
    p.loadWidth = size
    p.loadHeight = size
    p.loadDisplayMode = "scaleToFit"
end sub

' A game's team as a small tile: the logo at full strength on a dark tile
' edged in the team color, or the short-name chip when there's no logo
' (LaGrange College) or memory is low.
sub teamBadge(g as object, x as float, y as float, size as integer, gm as object)
    if not isText(gm.logo) or gm.logo = "" or m.lowMemory = true
        teamChip(g, x, y, size, gm.short, gm.color, gm.accent)
        return
    end if
    uiCard(g, x, y, size, size, "#0A0A0F", gm.color, 14)
    teamLogo(g, gm.logo, x + 6, y + 6, size - 12, 1.0)
end sub

' The logo of a tracked team from its games or finals, or "".
function logoOf(d as object, name as string) as string
    for each list in [d.finals, d.games]
        for each x in list
            nm = x.team ' finals name the team in team, games in name
            if nm = invalid then nm = x.name
            if isText(nm) and nm = name and isText(x.logo) and x.logo <> "" then return x.logo
        end for
    end for
    return ""
end function

function gameWhen(gm as object, today as integer) as string
    if gm.state = "in" then return liveText(gm)
    if gm.tbd then return tDayWord(gm.start, today) + " · time TBA"
    return tDayWord(gm.start, today) + " " + tClock(gm.start)
end function

' Like gameWhen with a 3-letter weekday past tomorrow ("Wed 7:30 PM"), for tight rows.
function gameWhenShort(gm as object, today as integer) as string
    if gm.state = "in" then return liveText(gm)
    n = (tDay(gm.start) - today) \ 86400
    day = tDayWord(gm.start, today)
    if n >= 2 then day = Left(tWeekdayNames()[tWeekday(gm.start)], 3)
    if n >= 7 then day = tShortDate(gm.start)
    if gm.tbd then return day + " · TBA"
    return day + " " + tClock(gm.start).Replace(":00", "")
end function

function curbText(c as object) as string
    return "Garbage + " + c.extra
end function

sub sunArc(g as object, x as float, y as float, w as float, h as float, uri as string, d as object, dotR as float)
    uiImage(g, uri, x, y, w, h)
    day = d.weather.days[0]
    frac = (d.now - day.sunrise) / (day.sunset - day.sunrise)
    if frac > 0 and frac < 1
        px = x + w * frac
        py = y + h - 4 - (h - 8) * 4 * frac * (1 - frac)
        uiDot(g, px, py, dotR * 2.1, "#FFD166", 0.16)
        uiDot(g, px, py, dotR, "#FFD166")
    end if
end sub
