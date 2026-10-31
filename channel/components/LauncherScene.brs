sub init()
    m.top.setFocus(true)

    m.helper = lhdHelper()
    m.dockSize = 72
    m.dockGap = 18
    m.drawerSize = 96
    m.drawerGap = 24
    m.cols = 5
    m.visibleRows = 4
    m.gridRowH = 130

    m.zone = "dock"
    m.dockIndex = 0
    m.allIndex = 0
    m.gridOffsetRow = 0
    m.organize = false
    m.menuOpen = false
    m.menuIndex = 0
    m.drawerOpen = false
    m.animT = 0.0
    m.animMoving = false
    m.monitorOn = true
    m.statsBusy = false
    m.starHolding = false
    m.starLong = false
    m.restartOpen = false
    m.okHolding = false
    m.movingApp = false
    m.movingZone = ""
    m.appMenuIndex = 0
    m.menuApp = invalid
    m.pickerOpen = false
    m.pickerApp = invalid
    m.pickerIndex = 0
    m.pickerOptions = []
    m.pickerCells = []
    m.customNames = {}
    m.customIcons = {}
    m.renameOpen = false
    m.renameText = ""
    m.renameIndex = 0
    m.renameCells = []
    m.renameChars = []
    m.renameUpper = true
    m.dockRestY = 936.0
    m.dockOpenY = 262.0
    m.panelRestY = 686.0
    m.panelOpenY = 0.0
    m.driftT = 0.0
    m.photoTick = 0
    m.bgActive = 0
    m.bgPending = false
    m.bgFadeRunning = false
    m.bgIncoming = invalid
    m.bgOutgoing = invalid
    m.photoStartSec = nowSec()

    m.favorites = []
    m.allApps = []
    m.drawerOrder = []
    m.appsById = {}
    m.appsOrder = []
    m.favIds = []
    m.dockTiles = []
    m.drawerTiles = []

    m.iconIds = {}
    m.iconIds["837"] = true
    m.iconIds["12"] = true
    m.iconIds["592369"] = true
    m.iconIds["22297"] = true
    m.iconIds["13"] = true
    m.iconIds["61322"] = true
    m.iconIds["291097"] = true
    m.iconIds["151908"] = true
    m.iconIds["2595"] = true
    m.iconIds["34376"] = true
    m.iconIds["31440"] = true
    m.iconIds["593099"] = true
    m.iconIds["41468"] = true
    m.iconIds["773622"] = true
    m.iconIds["551012"] = true

    m.clock = find("clock")
    m.date = find("date")
    m.weather = find("weather")
    m.cog = find("cog")
    m.cogRing = find("cogRing")
    m.bg = find("bg")
    m.bg2 = find("bg2")
    m.bgGroup = find("bgGroup")
    m.content = find("content")
    m.barFill = find("barFill")
    m.dim = find("dim")
    m.shelfGroup = find("shelfGroup")
    m.shelfGlow = find("shelfGlow")
    m.shelfCat = find("shelfCat")
    m.shelfName = find("shelfName")
    m.monitorGroup = find("monitorGroup")
    m.monitorText = find("monitorText")
    m.drawerHint = find("drawerHint")
    m.organizeLabel = find("organizeLabel")
    m.restartGroup = find("restartGroup")
    m.restartTitle = find("restartTitle")
    m.restartBody = find("restartBody")
    m.restartHint = find("restartHint")
    m.appMenuLabels = [find("appMenu0"), find("appMenu1"), find("appMenu2"), find("appMenu3")]
    m.iconPickerGroup = find("iconPickerGroup")
    m.iconGrid = find("iconGrid")
    m.iconTitle = find("iconTitle")
    m.iconAppName = find("iconAppName")
    m.iconHint = find("iconHint")
    m.renameGroup = find("renameGroup")
    m.renameTitle = find("renameTitle")
    m.renameValue = find("renameValue")
    m.renameGrid = find("renameGrid")
    m.renameHint = find("renameHint")
    m.dockGroup = find("dockGroup")
    m.dockBg = find("dockBg")
    m.dockGlow = find("dockGlow")
    m.dockTilesGroup = find("dockTiles")
    m.drawerGroup = find("drawerGroup")
    m.drawerGlow = find("drawerGlow")
    m.drawerTitle = find("drawerTitle")
    m.drawerTilesGroup = find("drawerTiles")
    m.toastGroup = find("toastGroup")
    m.toastLabel = find("toastLabel")
    m.menuGroup = find("menuGroup")

    m.dockRing = makeRing("pkg:/images/ring-dock.png", 80)
    m.drawerRing = makeRing("pkg:/images/ring-drawer.png", 104)

    fontNodes()
    styleLabels()
    setupMenu()

    m.dockGroup.translation = [0, m.dockRestY]
    m.drawerGroup.translation = [0, m.panelRestY]
    m.drawerGroup.scale = [0.37, 1.0]
    m.drawerGroup.scaleRotateCenter = [960, 600]
    m.drawerGroup.visible = false
    m.shelfGlow.blendColor = "0x8A8A8AFF"
    m.dockGlow.visible = false
    m.drawerGlow.visible = false

    m.bg.uri = m.helper + "/photo"
    m.bg.observeField("loadStatus", "onBgLoaded")
    m.bg2.observeField("loadStatus", "onBgLoaded")

    loadFavorites()
    loadInterval()
    loadMonitor()
    loadDrawerOrder()
    loadApps()
    updateClock()
    fetchWeather()
    updateHint()

    tickTimer = find("tick")
    tickTimer.observeField("fire", "onTick")
    tickTimer.control = "start"

    driftTimer = find("drift")
    driftTimer.observeField("fire", "onDrift")
    driftTimer.control = "start"

    weatherTimer = find("weatherTimer")
    weatherTimer.observeField("fire", "fetchWeather")
    weatherTimer.control = "start"

    photoTimer = find("photoTimer")
    photoTimer.duration = m.bgInterval
    photoTimer.observeField("fire", "nextBgPhoto")
    photoTimer.control = "start"
    m.photoTimer = photoTimer

    fadeTimer = find("fadeTimer")
    fadeTimer.observeField("fire", "onBgFade")
    m.bgFadeTimer = fadeTimer

    drawerTimer = find("drawerTimer")
    drawerTimer.observeField("fire", "onDrawerTick")
    m.drawerTimer = drawerTimer

    toastTimer = find("toastTimer")
    toastTimer.observeField("fire", "onToast")
    m.toastTimer = toastTimer

    statsTimer = find("statsTimer")
    statsTimer.observeField("fire", "fetchStats")
    m.statsTimer = statsTimer
    if m.monitorOn then
        statsTimer.control = "start"
        fetchStats()
    end if

    starTimer = find("starTimer")
    starTimer.observeField("fire", "onStarHold")
    m.starTimer = starTimer

    okHoldTimer = find("okHoldTimer")
    okHoldTimer.observeField("fire", "onOkHold")
    m.okHoldTimer = okHoldTimer
end sub

function find(id as String) as Object
    return m.top.findNode(id)
end function

function makeRing(uri as String, size as Integer) as Object
    r = CreateObject("roSGNode", "Poster")
    r.uri = uri
    r.width = size
    r.height = size
    r.visible = false
    return r
end function

function fontNode(uri as String, size as Integer) as Object
    f = CreateObject("roSGNode", "Font")
    f.uri = uri
    f.size = size
    return f
end function

sub fontNodes()
    m.fontClock = fontNode("pkg:/fonts/Outfit-Light.ttf", 72)
    m.fontDate = fontNode("pkg:/fonts/Outfit-Regular.ttf", 30)
    m.fontWeather = fontNode("pkg:/fonts/Outfit-Regular.ttf", 26)
    m.fontShelfCat = fontNode("pkg:/fonts/Outfit-Regular.ttf", 14)
    m.fontMonitor = fontNode("pkg:/fonts/Outfit-Regular.ttf", 16)
    m.fontDrawerHint = fontNode("pkg:/fonts/Outfit-Regular.ttf", 14)
    m.fontOrganize = fontNode("pkg:/fonts/Outfit-Regular.ttf", 16)
    m.fontRestartTitle = fontNode("pkg:/fonts/Outfit-Regular.ttf", 16)
    m.fontRestartBody = fontNode("pkg:/fonts/Outfit-Light.ttf", 26)
    m.fontRestartHint = fontNode("pkg:/fonts/Outfit-Regular.ttf", 14)
    m.fontAppMenu = fontNode("pkg:/fonts/Outfit-Regular.ttf", 26)
    m.fontIconTitle = fontNode("pkg:/fonts/Outfit-Regular.ttf", 16)
    m.fontIconAppName = fontNode("pkg:/fonts/Outfit-Light.ttf", 26)
    m.fontIconHint = fontNode("pkg:/fonts/Outfit-Regular.ttf", 14)
    m.fontShelfName = fontNode("pkg:/fonts/Outfit-Light.ttf", 64)
    m.fontDockLabel = fontNode("pkg:/fonts/Outfit-Regular.ttf", 14)
    m.fontDrawerLabel = fontNode("pkg:/fonts/Outfit-Regular.ttf", 16)
    m.fontDrawerTitle = fontNode("pkg:/fonts/Outfit-Regular.ttf", 16)
    m.fontToast = fontNode("pkg:/fonts/Outfit-Regular.ttf", 18)
    m.fontMenu = fontNode("pkg:/fonts/Outfit-Regular.ttf", 26)
    m.fontMenuTitle = fontNode("pkg:/fonts/Outfit-Regular.ttf", 18)
end sub

sub styleLabels()
    m.clock.font = m.fontClock
    m.clock.color = "0xF4F3F0FF"
    m.date.font = m.fontDate
    m.date.color = "0xF4F3F0A8"
    m.weather.font = m.fontWeather
    m.weather.color = "0xF4F3F066"
    m.shelfCat.font = m.fontShelfCat
    m.shelfCat.color = "0xF4F3F099"
    m.shelfName.font = m.fontShelfName
    m.shelfName.color = "0xF4F3F0FF"
    m.monitorText.font = m.fontMonitor
    m.monitorText.color = "0xF4F3F066"
    m.drawerHint.font = m.fontDrawerHint
    m.drawerHint.color = "0xF4F3F055"
    m.organizeLabel.font = m.fontOrganize
    m.organizeLabel.color = "0xFFFFD166"
    m.organizeLabel.text = "ORGANIZING   ·   * DONE"
    m.restartTitle.font = m.fontRestartTitle
    m.restartTitle.color = "0xF4F3F066"
    m.restartTitle.text = "APP OPTIONS"
    m.restartBody.font = m.fontRestartBody
    m.restartBody.color = "0xF4F3F0FF"
    m.restartHint.font = m.fontRestartHint
    m.restartHint.color = "0xF4F3F066"
    m.restartHint.text = "OK select    ·    Back close"
    for each lbl in m.appMenuLabels
        lbl.font = m.fontAppMenu
        lbl.vertAlign = "center"
        lbl.color = "0xF4F3F0A0"
    end for
    m.iconTitle.font = m.fontIconTitle
    m.iconTitle.color = "0xF4F3F066"
    m.iconTitle.text = "CHANGE ICON"
    m.iconAppName.font = m.fontIconAppName
    m.iconAppName.color = "0xF4F3F0FF"
    m.iconHint.font = m.fontIconHint
    m.iconHint.color = "0xF4F3F066"
    m.iconHint.text = "Arrows move    ·    OK choose    ·    Back cancel"
    m.renameTitle.font = m.fontIconTitle
    m.renameTitle.color = "0xF4F3F066"
    m.renameTitle.text = "RENAME"
    m.renameValue.font = m.fontIconAppName
    m.renameValue.color = "0xF4F3F0FF"
    m.renameHint.font = m.fontIconHint
    m.renameHint.color = "0xF4F3F066"
    m.renameHint.text = "Arrows move    ·    OK type    ·    SHIFT changes case    ·    DONE saves    ·    Back cancels"
    updateAppMenu()
    m.drawerTitle.font = m.fontDrawerTitle
    m.drawerTitle.color = "0xF4F3F099"
    m.drawerTitle.text = "ALL APPS & INPUTS"
    m.toastLabel.font = m.fontToast
    m.toastLabel.color = "0xF4F3F0FF"
end sub

sub setupMenu()
    m.menuTitle = find("menuTitle")
    m.menuLabels = []
    m.menuLabels.Push(find("menu0"))
    m.menuLabels.Push(find("menu1"))
    m.menuLabels.Push(find("menu2"))
    m.menuLabels.Push(find("menu3"))
    m.menuLabels.Push(find("menu4"))
    m.menuLabels.Push(find("menu5"))
    m.menuLabels.Push(find("menu6"))
    m.menuLabels.Push(find("menu7"))

    m.menuItems = [
        "Organize favorites",
        "System monitor: On",
        "Photo interval: 60s",
        "Roku Home (10 min)",
        "Store (10 min)",
        "Settings (10 min)",
        "Disable auto-start",
        "Close"
    ]
    m.menuIndex = 0
    m.menuOpen = false

    m.menuTitle.font = m.fontMenuTitle
    m.menuTitle.color = "0xF4F3F066"
    m.menuTitle.text = "SETTINGS"

    for each lbl in m.menuLabels
        lbl.font = m.fontMenu
        lbl.color = "0xF4F3F0A0"
        lbl.vertAlign = "center"
    end for
    m.menuGroup.visible = false
end sub

sub loadFavorites()
    sec = CreateObject("roRegistrySection", "launcher")
    raw = sec.Read("favorites")
    if raw = "-" then
        m.favIds = []
    else
        if raw <> "" then
            m.favIds = []
            parts = raw.Split(",")
            for each p in parts
                if p <> "" then m.favIds.Push(p)
            end for
        else
            m.favIds = ["837", "12", "592369", "22297", "13", "61322"]
        end if
    end if
end sub

sub saveFavorites()
    m.favIds = []
    for each app in m.favorites
        m.favIds.Push(app.id)
    end for
    val = m.favIds.Join(",")
    if val = "" then val = "-"
    sec = CreateObject("roRegistrySection", "launcher")
    sec.Write("favorites", val)
    sec.Flush()
end sub

sub loadDrawerOrder()
    sec = CreateObject("roRegistrySection", "launcher")
    raw = sec.Read("drawer_order")
    m.drawerOrder = []
    if raw = "" or raw = "-" then return
    for each p in raw.Split(",")
        if p <> "" then m.drawerOrder.Push(p)
    end for
end sub

sub saveDrawerOrder()
    ids = []
    for each app in m.allApps
        ids.Push(app.id)
    end for
    val = ids.Join(",")
    if val = "" then val = "-"
    sec = CreateObject("roRegistrySection", "launcher")
    sec.Write("drawer_order", val)
    sec.Flush()
end sub

sub loadInterval()
    sec = CreateObject("roRegistrySection", "launcher")
    raw = sec.Read("photo_interval")
    m.bgInterval = 60
    if raw <> "" then
        v = Val(raw)
        if v >= 10 then m.bgInterval = Int(v)
    end if
end sub

sub loadMonitor()
    sec = CreateObject("roRegistrySection", "launcher")
    raw = sec.Read("monitor")
    m.monitorOn = true
    if raw = "0" then m.monitorOn = false
    m.monitorGroup.visible = m.monitorOn
    if m.monitorOn then
        m.monitorText.text = "CPU —    RAM —"
        m.menuItems[1] = "System monitor: On"
    else
        m.monitorText.text = ""
        m.menuItems[1] = "System monitor: Off"
    end if
    updateMenu()
end sub

sub loadApps()
    task = CreateObject("roSGNode", "HttpTask")
    task.url = m.helper + "/apps"
    task.method = "GET"
    task.observeField("responseCode", "onApps")
    task.control = "RUN"
    m.appsTask = task
end sub

sub onApps()
    task = m.appsTask
    if task = invalid then return
    if task.responseCode <> 200 then
        showToast("Launcher helper unreachable")
        return
    end if
    data = ParseJson(task.responseBody)
    if data = invalid then return
    if data.apps = invalid then return

    m.appsOrder = data.apps
    m.appsById = {}
    for each app in m.appsOrder
        m.appsById[app.id] = app
    end for

    loadCustomizations()
    buildLists()
    renderDock()
    renderDrawer()
    updateFocus()
    m.menuItems[2] = "Photo interval: " + intervalLabel(m.bgInterval)
    updateMenu()
end sub

sub buildLists()
    m.favorites = []
    for each id in m.favIds
        app = m.appsById[id]
        if app <> invalid then m.favorites.Push(app)
    end for

    m.allApps = []
    for each id in m.drawerOrder
        app = m.appsById[id]
        if app <> invalid then
            if not isFavorite(app) then m.allApps.Push(app)
        end if
    end for
    for each app in m.appsOrder
        if not isFavorite(app) then
            if not inAllApps(app.id) then m.allApps.Push(app)
        end if
    end for
end sub

function isFavorite(app as Object) as Boolean
    for each fav in m.favorites
        if fav.id = app.id then return true
    end for
    return false
end function

function inAllApps(id as String) as Boolean
    for each a in m.allApps
        if a.id = id then return true
    end for
    return false
end function

sub clearGroup(g as Object)
    while g.getChildCount() > 0
        g.removeChild(g.getChild(0))
    end while
end sub

sub renderDock()
    clearGroup(m.dockTilesGroup)
    m.dockTiles = []

    n = m.favorites.Count() + 1
    total = n * m.dockSize + (n - 1) * m.dockGap + 32
    startX = (1920 - total) / 2
    m.dockBg.translation = [startX, 0]
    m.dockBg.width = total
    m.dockTilesGroup.translation = [startX + 16, 20]

    for i = 0 to m.favorites.Count() - 1
        x = i * (m.dockSize + m.dockGap)
        tile = makeTile(m.favorites[i], x, 0, m.dockSize, true)
        m.dockTiles.Push(tile)
    end for

    allApp = { id: "allapps", name: "All apps", type: "allapps" }
    x = m.favorites.Count() * (m.dockSize + m.dockGap)
    tile = makeTile(allApp, x, 0, m.dockSize, true)
    m.dockTiles.Push(tile)

    m.dockTilesGroup.appendChild(m.dockRing)
end sub

sub renderDrawer()
    clearGroup(m.drawerTilesGroup)
    m.drawerTiles = []

    total = m.allApps.Count()
    if total > 0 then
        rowWidth = m.cols * m.drawerSize + (m.cols - 1) * m.drawerGap
        startX = (1920 - rowWidth) / 2
        for i = 0 to total - 1
            row = i \ m.cols
            col = i mod m.cols
            x = startX + col * (m.drawerSize + m.drawerGap)
            y = row * m.gridRowH
            tile = makeTile(m.allApps[i], x, y, m.drawerSize, false)
            m.drawerTiles.Push(tile)
        end for
    end if

    m.drawerTilesGroup.appendChild(m.drawerRing)
    updateDrawerScroll()
end sub

function makeTile(app as Object, x as Float, y as Float, size as Integer, isDock as Boolean) as Object
    g = CreateObject("roSGNode", "Group")
    g.translation = [x, y]

    bg = CreateObject("roSGNode", "Poster")
    if isDock then
        bg.uri = "pkg:/images/tile-dock.png"
    else
        bg.uri = "pkg:/images/tile-drawer.png"
    end if
    bg.width = size
    bg.height = size
    g.appendChild(bg)

    uri = iconFor(app)

    if app.type = "appl" then
        if uri <> "" then
            p = CreateObject("roSGNode", "Poster")
            p.uri = uri
            p.width = size
            p.height = size
            p.loadDisplayMode = "scaleToFill"
            g.appendChild(p)
        else
            fb = CreateObject("roSGNode", "Label")
            fb.text = displayName(app)
            if isDock then
                fb.font = m.fontDockLabel
            else
                fb.font = m.fontDrawerLabel
            end if
            fb.color = "0xF4F3F0CC"
            fb.width = size
            fb.height = size
            fb.horizAlign = "center"
            fb.vertAlign = "center"
            fb.wrap = true
            g.appendChild(fb)
        end if
    else
        pad = 6
        p = CreateObject("roSGNode", "Poster")
        p.uri = uri
        p.width = size - pad * 2
        p.height = size - pad * 2
        p.translation = [pad, pad]
        p.loadDisplayMode = "scaleToFit"
        g.appendChild(p)
    end if

    lbl = invalid
    if not isDock then
        lbl = CreateObject("roSGNode", "Label")
        lbl.text = displayName(app)
        lbl.font = m.fontDrawerLabel
        lbl.color = "0xF4F3F0A0"
        lbl.width = size + 30
        lbl.height = 24
        lbl.translation = [-15, size + 6]
        lbl.horizAlign = "center"
        lbl.vertAlign = "center"
        g.appendChild(lbl)
    end if

    if isDock then
        m.dockTilesGroup.appendChild(g)
    else
        m.drawerTilesGroup.appendChild(g)
    end if

    tile = { group: g, label: lbl, app: app, x: x, y: y, size: size, isDock: isDock }
    return tile
end function

function displayName(app as Object) as String
    if app = invalid then return ""
    if m.customNames[app.id] <> invalid then return m.customNames[app.id]
    return app.name
end function

sub loadCustomizations()
    m.customNames = {}
    m.customIcons = {}
    sec = CreateObject("roRegistrySection", "launcher")
    for each app in m.appsOrder
        n = sec.Read("name_" + app.id)
        if n <> "" then m.customNames[app.id] = n
        ic = sec.Read("icon_" + app.id)
        if ic <> "" then m.customIcons[app.id] = ic
    end for
end sub

function iconFor(app as Object) as String
    if app = invalid then return ""
    key = m.customIcons[app.id]
    if key <> invalid then
        uri = iconPath(key)
        if uri <> "" then return uri
    end if
    return defaultIconFor(app)
end function

function iconPath(key as String) as String
    if key = "switch" then return "pkg:/images/input-switch.png"
    if key = "gamepad" then return "pkg:/images/input-gamepad.png"
    if key = "playstation" then return "pkg:/images/input-playstation.png"
    if key = "raspberrypi" then return "pkg:/images/input-raspberrypi.png"
    if key = "speaker" then return "pkg:/images/input-speaker.png"
    if key = "hdmi" then return "pkg:/images/input-hdmi.png"
    if key = "av" then return "pkg:/images/input-av.png"
    if key = "livetv" then return "pkg:/images/input-livetv.png"
    if key = "generic" then return "pkg:/images/stock-generic.png"
    return ""
end function

function defaultIconFor(app as Object) as String
    if app.type = "allapps" then return "pkg:/images/stock-allapps.png"

    if app.type = "appl" then
        if m.iconIds[app.id] <> invalid then return "pkg:/images/app-" + app.id + ".png"
        return ""
    end if

    n = LCase(app.name)
    if Instr(1, n, "playstation") > 0 then return "pkg:/images/input-playstation.png"
    if Instr(1, n, "retropi") > 0 then return "pkg:/images/input-raspberrypi.png"
    if Instr(1, n, "raspberry") > 0 then return "pkg:/images/input-raspberrypi.png"
    if Instr(1, n, "vizio") > 0 then return "pkg:/images/input-speaker.png"
    if Instr(1, n, "soundbar") > 0 then return "pkg:/images/input-speaker.png"
    if Instr(1, n, "gaming") > 0 then return "pkg:/images/input-gamepad.png"
    if Instr(1, n, "console") > 0 then return "pkg:/images/input-gamepad.png"
    if Instr(1, app.id, "tvinput.hdmi") = 1 then return "pkg:/images/input-hdmi.png"
    if app.id = "tvinput.cvbs" then return "pkg:/images/input-av.png"
    if app.id = "tvinput.dtv" then return "pkg:/images/input-livetv.png"
    return "pkg:/images/stock-generic.png"
end function

sub updateDrawerScroll()
    total = m.allApps.Count()
    if total = 0 then
        m.drawerTilesGroup.translation = [0, 430]
        return
    end if

    rows = (total + m.cols - 1) \ m.cols
    row = m.allIndex \ m.cols
    if row < m.gridOffsetRow then m.gridOffsetRow = row
    if row > m.gridOffsetRow + m.visibleRows - 1 then m.gridOffsetRow = row - m.visibleRows + 1

    maxOffset = rows - m.visibleRows
    if maxOffset < 0 then maxOffset = 0
    if m.gridOffsetRow > maxOffset then m.gridOffsetRow = maxOffset
    if m.gridOffsetRow < 0 then m.gridOffsetRow = 0

    m.drawerTilesGroup.translation = [0, 430 - m.gridOffsetRow * m.gridRowH]
end sub

sub updateFocus()
    if m.dockTiles.Count() > 0 then
        for i = 0 to m.dockTiles.Count() - 1
            t = m.dockTiles[i]
            t.group.scale = [1.0, 1.0]
            t.group.scaleRotateCenter = [m.dockSize / 2, m.dockSize / 2]
            t.group.translation = [t.x, t.y]
        end for
    end if
    if m.drawerTiles.Count() > 0 then
        for i = 0 to m.drawerTiles.Count() - 1
            t = m.drawerTiles[i]
            t.group.scale = [1.0, 1.0]
            t.group.translation = [t.x, t.y]
            if t.label <> invalid then t.label.color = "0xF4F3F0A0"
        end for
    end if

    m.dockRing.visible = false
    m.drawerRing.visible = false
    m.cogRing.visible = false
    m.dockGlow.visible = false
    m.drawerGlow.visible = false
    m.dockGlow.blendColor = "0xFFFFFFFF"
    m.drawerGlow.blendColor = "0xFFFFFFFF"

    ringColor = "0xFFFFFFFF"
    if m.organize then ringColor = "0xFFFFD166"
    m.dockRing.blendColor = ringColor
    m.drawerRing.blendColor = ringColor

    m.shelfGroup.visible = not m.drawerOpen

    if m.zone = "dock" then
        m.cog.opacity = 0.55
        if m.dockTiles.Count() = 0 then return
        if m.dockIndex > m.dockTiles.Count() - 1 then m.dockIndex = m.dockTiles.Count() - 1
        if m.dockIndex < 0 then m.dockIndex = 0
        t = m.dockTiles[m.dockIndex]
        lift = 0
        if m.movingApp and m.movingZone = "dock" then
            t.group.scale = [1.12, 1.12]
            t.group.translation = [t.x, t.y - 10]
            lift = 10
            m.dockRing.translation = [t.x - 4, t.y - 4]
            m.dockRing.blendColor = "0xFFFFD166"
            m.dockRing.visible = true
            m.dockGlow.blendColor = "0xFFFFD166"
        else
            m.dockGlow.blendColor = appColor(t.app)
        end if
        gx = m.dockTilesGroup.translation[0] + t.x + m.dockSize / 2 - 90
        gy = m.dockTilesGroup.translation[1] + t.y - lift + m.dockSize / 2 - 90
        m.dockGlow.translation = [gx, gy]
        m.dockGlow.visible = true
        updateShelf(t.app)
    else
        if m.zone = "drawer" then
            m.cog.opacity = 0.55
            if m.drawerTiles.Count() = 0 then return
            if m.allIndex > m.drawerTiles.Count() - 1 then m.allIndex = m.drawerTiles.Count() - 1
            if m.allIndex < 0 then m.allIndex = 0
            updateDrawerScroll()
            t = m.drawerTiles[m.allIndex]
            lift = 0
            if m.movingApp and m.movingZone = "drawer" then
                t.group.scale = [1.1, 1.1]
                t.group.scaleRotateCenter = [m.drawerSize / 2, m.drawerSize / 2]
                t.group.translation = [t.x, t.y - 6]
                lift = 6
                m.drawerRing.translation = [t.x - 4, t.y - 4]
                m.drawerRing.blendColor = "0xFFFFD166"
                m.drawerRing.visible = true
                m.drawerGlow.blendColor = "0xFFFFD166"
            else
                m.drawerGlow.blendColor = appColor(t.app)
            end if
            gx = m.drawerTilesGroup.translation[0] + t.x + m.drawerSize / 2 - 110
            gy = m.drawerTilesGroup.translation[1] + t.y - lift + m.drawerSize / 2 - 110
            m.drawerGlow.translation = [gx, gy]
            m.drawerGlow.visible = true
            if t.label <> invalid then t.label.color = "0xF4F3F0FF"
        else
            if m.zone = "cog" then
                m.cog.opacity = 1.0
                m.cogRing.visible = true
                m.shelfGroup.visible = not m.drawerOpen
                m.shelfCat.text = "LAUNCHER"
                m.shelfName.text = "Settings"
                m.shelfGlow.blendColor = "0xF4F3F0FF"
            end if
        end if
    end if
end sub

sub updateHint()
    if m.movingApp then
        m.drawerHint.text = "MOVING APP   ·   ARROWS PLACE IT   ·   OK DROP   ·   BACK CANCEL"
    else
        if m.organize then
            m.drawerHint.text = "ORGANIZING   ·   HOLD OK to move app   ·   OK adds/removes   ·   * done"
        else
            m.drawerHint.text = "ORGANIZE: *   ·   OK adds in drawer   ·   OK removes on dock   ·   HOLD * for app menu"
        end if
    end if
end sub

sub setOrganize(enabled as Boolean)
    m.organize = enabled
    if not enabled then
        m.movingApp = false
        m.movingZone = ""
    end if
    m.organizeLabel.text = "ORGANIZING   ·   * DONE"
    m.organizeLabel.visible = enabled
    updateHint()
    if enabled then
        showToast("Organizing: OK removes on dock, adds in drawer")
    else
        showToast("Organizing done")
    end if
    updateHint()
    updateFocus()
end sub

sub toggleOrganize()
    setOrganize(not m.organize)
end sub

function focusedApp() as Object
    if m.zone = "dock" then
        if m.dockIndex < m.favorites.Count() then return m.favorites[m.dockIndex]
    end if
    if m.zone = "drawer" then
        if m.allIndex < m.allApps.Count() then return m.allApps[m.allIndex]
    end if
    return invalid
end function

sub openAppMenu()
    m.menuApp = focusedApp()
    if m.menuApp <> invalid then
        m.restartBody.text = displayName(m.menuApp)
    else
        m.restartBody.text = "LHD Launcher"
    end if
    m.appMenuIndex = 0
    updateAppMenu()
    m.restartOpen = true
    m.restartGroup.visible = true
end sub

sub closeAppMenu()
    m.restartOpen = false
    m.restartGroup.visible = false
end sub

sub updateAppMenu()
    items = ["Rename", "Change icon", "Restart launcher", "Cancel"]
    for i = 0 to m.appMenuLabels.Count() - 1
        lbl = m.appMenuLabels[i]
        if i = m.appMenuIndex then
            lbl.text = "> " + items[i]
            lbl.color = "0xF4F3F0FF"
        else
            lbl.text = "  " + items[i]
            lbl.color = "0xF4F3F0A0"
        end if
        if m.menuApp = invalid and i < 2 then lbl.color = "0xF4F3F040"
    end for
end sub

sub appMenuAction()
    if m.appMenuIndex = 0 then
        if m.menuApp <> invalid then
            openRename()
        else
            showToast("Focus an app first")
        end if
        return
    end if
    if m.appMenuIndex = 1 then
        if m.menuApp <> invalid then
            openIconPicker()
        else
            showToast("Focus an app first")
        end if
        return
    end if
    if m.appMenuIndex = 2 then
        doRestart()
        return
    end if
    closeAppMenu()
end sub

sub doRestart()
    closeAppMenu()
    showToast("Restarting LHD Launcher")
    task = CreateObject("roSGNode", "HttpTask")
    task.url = m.helper + "/restart"
    task.method = "GET"
    task.control = "RUN"
    m.restartTask = task
end sub

sub onStarHold()
    if not m.starHolding then return
    m.starLong = true
    openAppMenu()
end sub

sub openRename()
    closeAppMenu()
    app = m.menuApp
    if app = invalid then return
    m.renameChars = renameChars()
    m.renameText = displayName(app)
    m.renameUpper = true
    m.renameIndex = 0
    buildRenameGrid()
    updateRenameGrid()
    m.renameOpen = true
    m.renameGroup.visible = true
end sub

sub closeRename()
    m.renameOpen = false
    m.renameGroup.visible = false
end sub

function renameChars() as Object
    chars = []
    for c = 65 to 90
        chars.Push(Chr(c))
    end for
    for c = 48 to 57
        chars.Push(Chr(c))
    end for
    chars.Push(" ")
    chars.Push("-")
    chars.Push(".")
    chars.Push("_")
    chars.Push("SHIFT")
    chars.Push("DEL")
    chars.Push("DONE")
    chars.Push("CANCEL")
    return chars
end function

sub buildRenameGrid()
    clearGroup(m.renameGrid)
    m.renameCells = []
    for i = 0 to m.renameChars.Count() - 1
        row = i \ 7
        col = i mod 7
        g = CreateObject("roSGNode", "Group")
        g.translation = [col * 120, row * 60]
        bg = CreateObject("roSGNode", "Rectangle")
        bg.width = 116
        bg.height = 54
        bg.translation = [2, 3]
        bg.color = "0xFFFFFF1A"
        bg.visible = false
        g.appendChild(bg)
        lbl = CreateObject("roSGNode", "Label")
        ch = m.renameChars[i]
        if ch = " " then
            lbl.text = "SPACE"
        else
            lbl.text = ch
        end if
        lbl.font = m.fontAppMenu
        lbl.color = "0xF4F3F0A0"
        lbl.width = 120
        lbl.height = 60
        lbl.horizAlign = "center"
        lbl.vertAlign = "center"
        g.appendChild(lbl)
        m.renameGrid.appendChild(g)
        m.renameCells.Push({bg: bg, label: lbl, char: ch})
    end for
end sub

sub updateRenameGrid()
    for i = 0 to m.renameCells.Count() - 1
        c = m.renameCells[i]
        if c.char >= "A" and c.char <= "Z" then
            if m.renameUpper then
                c.label.text = c.char
            else
                c.label.text = LCase(c.char)
            end if
        end if
        c.bg.visible = (i = m.renameIndex)
        if i = m.renameIndex then
            c.label.color = "0xF4F3F0FF"
        else
            c.label.color = "0xF4F3F0A0"
        end if
    end for
    if m.renameText = "" then
        m.renameValue.text = "_"
    else
        m.renameValue.text = m.renameText
    end if
end sub

sub renameKey()
    if m.renameCells.Count() = 0 then return
    ch = m.renameCells[m.renameIndex].char
    if ch = "CANCEL" then
        closeRename()
        return
    end if
    if ch = "SHIFT" then
        m.renameUpper = not m.renameUpper
        updateRenameGrid()
        return
    end if
    if ch = "DONE" then
        if Len(m.renameText) > 0 then
            sec = CreateObject("roRegistrySection", "launcher")
            sec.Write("name_" + m.menuApp.id, m.renameText)
            sec.Flush()
            m.customNames[m.menuApp.id] = m.renameText
            closeRename()
            refreshAppTiles()
        end if
        return
    end if
    if ch = "DEL" then
        if Len(m.renameText) > 0 then
            m.renameText = Left(m.renameText, Len(m.renameText) - 1)
        end if
    else
        if Len(m.renameText) < 28 then
            out = ch
            if ch >= "A" and ch <= "Z" then
                if m.renameUpper then
                    out = UCase(ch)
                else
                    out = LCase(ch)
                end if
            end if
            m.renameText = m.renameText + out
        end if
    end if
    updateRenameGrid()
end sub

sub openIconPicker()
    closeAppMenu()
    app = m.menuApp
    if app = invalid then return
    m.pickerApp = app
    m.pickerOptions = iconOptions(app)
    m.pickerIndex = 0
    cur = m.customIcons[app.id]
    if cur <> invalid then
        for i = 0 to m.pickerOptions.Count() - 1
            if m.pickerOptions[i].key = cur then m.pickerIndex = i
        end for
    end if
    buildIconPicker()
    updateIconPicker()
    m.iconAppName.text = displayName(app)
    m.pickerOpen = true
    m.iconPickerGroup.visible = true
end sub

function iconOptions(app as Object) as Object
    opts = []
    defaultUri = defaultIconFor(app)
    if defaultUri = "" then defaultUri = "pkg:/images/stock-generic.png"
    opts.Push({key: "auto", label: "Default", uri: defaultUri})
    opts.Push({key: "switch", label: "Switch", uri: "pkg:/images/input-switch.png"})
    opts.Push({key: "gamepad", label: "Gamepad", uri: "pkg:/images/input-gamepad.png"})
    opts.Push({key: "playstation", label: "PlayStation", uri: "pkg:/images/input-playstation.png"})
    opts.Push({key: "raspberrypi", label: "Raspberry Pi", uri: "pkg:/images/input-raspberrypi.png"})
    opts.Push({key: "speaker", label: "Speaker", uri: "pkg:/images/input-speaker.png"})
    opts.Push({key: "hdmi", label: "HDMI", uri: "pkg:/images/input-hdmi.png"})
    opts.Push({key: "av", label: "AV", uri: "pkg:/images/input-av.png"})
    opts.Push({key: "livetv", label: "Live TV", uri: "pkg:/images/input-livetv.png"})
    opts.Push({key: "generic", label: "Generic", uri: "pkg:/images/stock-generic.png"})
    return opts
end function

sub buildIconPicker()
    clearGroup(m.iconGrid)
    m.pickerCells = []
    for i = 0 to m.pickerOptions.Count() - 1
        opt = m.pickerOptions[i]
        col = i mod 5
        row = i \ 5
        g = CreateObject("roSGNode", "Group")
        g.translation = [col * 220, row * 210]
        ring = CreateObject("roSGNode", "Poster")
        ring.uri = "pkg:/images/ring-drawer.png"
        ring.width = 104
        ring.height = 104
        ring.translation = [48, -4]
        ring.blendColor = "0xFFFFD166"
        ring.visible = false
        g.appendChild(ring)
        p = CreateObject("roSGNode", "Poster")
        p.uri = opt.uri
        p.width = 96
        p.height = 96
        p.translation = [52, 0]
        p.loadDisplayMode = "scaleToFit"
        g.appendChild(p)
        lbl = CreateObject("roSGNode", "Label")
        lbl.text = opt.label
        lbl.font = m.fontDrawerHint
        lbl.color = "0xF4F3F0A0"
        lbl.width = 220
        lbl.height = 24
        lbl.translation = [0, 102]
        lbl.horizAlign = "center"
        lbl.vertAlign = "center"
        g.appendChild(lbl)
        m.iconGrid.appendChild(g)
        m.pickerCells.Push({group: g, ring: ring, label: lbl, key: opt.key})
    end for
end sub

sub updateIconPicker()
    for i = 0 to m.pickerCells.Count() - 1
        c = m.pickerCells[i]
        c.ring.visible = (i = m.pickerIndex)
        if i = m.pickerIndex then
            c.label.color = "0xF4F3F0FF"
        else
            c.label.color = "0xF4F3F0A0"
        end if
    end for
end sub

sub selectIcon()
    if m.pickerApp = invalid then return
    if m.pickerCells.Count() = 0 then return
    key = m.pickerCells[m.pickerIndex].key
    sec = CreateObject("roRegistrySection", "launcher")
    sec.Write("icon_" + m.pickerApp.id, key)
    sec.Flush()
    m.customIcons[m.pickerApp.id] = key
    refreshAppTiles()
    closeIconPicker()
end sub

sub closeIconPicker()
    m.pickerOpen = false
    m.iconPickerGroup.visible = false
end sub

sub refreshAppTiles()
    renderDock()
    renderDrawer()
    updateFocus()
end sub

sub onOkHold()
    if not m.okHolding then return
    if not m.organize then return
    if m.zone = "drawer" then
        m.movingZone = "drawer"
    else
        if m.zone = "dock" then
            if m.dockIndex >= m.favorites.Count() then return
            m.movingZone = "dock"
        else
            return
        end if
    end if
    m.okHolding = false
    m.movingApp = true
    m.organizeLabel.text = "MOVING   ·   ARROWS PLACE IT   ·   OK DROP"
    updateHint()
    updateFocus()
end sub

sub updateShelf(app as Object)
    if app = invalid then
        m.shelfCat.text = ""
        m.shelfName.text = ""
        return
    end if
    m.shelfCat.text = appCategory(app)
    m.shelfName.text = displayName(app)
    m.shelfGlow.blendColor = appColor(app)
end sub

sub openDrawer()
    if m.drawerOpen then return
    m.drawerOpen = true
    m.zone = "drawer"
    m.gridOffsetRow = 0
    m.allIndex = 0
    updateDrawerScroll()
    updateFocus()
    m.dockBg.visible = false
    m.shelfGroup.visible = false
    m.dim.opacity = 0.55
    m.drawerGroup.scale = [0.37, 1.0]
    m.drawerGroup.visible = true
    m.animMoving = true
    m.drawerTimer.control = "start"
end sub

sub closeDrawer()
    if not m.drawerOpen then return
    if m.zone = "drawer" and m.drawerTiles.Count() > 0 then
        t = m.drawerTiles[m.allIndex]
        cx = m.drawerTilesGroup.translation[0] + t.x + m.drawerSize / 2
        m.dockIndex = closestDockIndex(cx)
    end if
    m.drawerOpen = false
    m.zone = "dock"
    m.shelfGroup.visible = false
    m.dockBg.visible = false
    m.animMoving = true
    m.drawerTimer.control = "start"
    updateFocus()
    m.shelfGroup.visible = false
end sub

sub onDrawerTick()
    if not m.animMoving then return
    target = 0.0
    if m.drawerOpen then target = 1.0
    if m.animT < target then
        m.animT = m.animT + 0.07
        if m.animT > target then m.animT = target
    else
        if m.animT > target then
            m.animT = m.animT - 0.07
            if m.animT < target then m.animT = target
        end if
    end if
    t = m.animT
    ease = t * t * (3.0 - 2.0 * t)
    m.dockGroup.translation = [0, m.dockRestY + (m.dockOpenY - m.dockRestY) * ease]
    m.drawerGroup.translation = [0, m.panelRestY + (m.panelOpenY - m.panelRestY) * ease]
    sx = 0.37 + 0.63 * ease
    m.drawerGroup.scale = [sx, 1.0]
    m.dim.opacity = 0.35 + 0.2 * ease
    if m.animT = target then
        m.animMoving = false
        m.drawerTimer.control = "stop"
        if target = 0 then
            m.drawerGroup.visible = false
            m.dockBg.visible = true
            m.shelfGroup.visible = true
            m.dim.opacity = 0.35
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    k = LCase(key)

    if m.renameOpen then
        if press then
            if k = "left" then
                if m.renameIndex > 0 then m.renameIndex = m.renameIndex - 1
                updateRenameGrid()
            end if
            if k = "right" then
                if m.renameIndex < m.renameCells.Count() - 1 then m.renameIndex = m.renameIndex + 1
                updateRenameGrid()
            end if
            if k = "up" then
                if m.renameIndex >= 7 then m.renameIndex = m.renameIndex - 7
                updateRenameGrid()
            end if
            if k = "down" then
                if m.renameIndex + 7 < m.renameCells.Count() then m.renameIndex = m.renameIndex + 7
                updateRenameGrid()
            end if
            if k = "ok" then renameKey()
            if k = "back" or k = "options" then closeRename()
        end if
        return true
    end if

    if m.pickerOpen then
        if press then
            if k = "left" then
                if m.pickerIndex > 0 then m.pickerIndex = m.pickerIndex - 1
                updateIconPicker()
            end if
            if k = "right" then
                if m.pickerIndex < m.pickerOptions.Count() - 1 then m.pickerIndex = m.pickerIndex + 1
                updateIconPicker()
            end if
            if k = "up" then
                if m.pickerIndex >= 5 then m.pickerIndex = m.pickerIndex - 5
                updateIconPicker()
            end if
            if k = "down" then
                if m.pickerIndex + 5 < m.pickerOptions.Count() then m.pickerIndex = m.pickerIndex + 5
                updateIconPicker()
            end if
            if k = "ok" then selectIcon()
            if k = "back" or k = "options" then closeIconPicker()
        end if
        return true
    end if

    if m.restartOpen then
        if press then
            if k = "up" then
                if m.appMenuIndex > 0 then m.appMenuIndex = m.appMenuIndex - 1
                updateAppMenu()
            end if
            if k = "down" then
                if m.appMenuIndex < 3 then m.appMenuIndex = m.appMenuIndex + 1
                updateAppMenu()
            end if
            if k = "ok" then appMenuAction()
            if k = "back" or k = "options" then closeAppMenu()
        end if
        return true
    end if

    if k = "options" then
        if m.menuOpen then
            if press then closeMenu()
            return true
        end if
        if press then
            if not m.starHolding then
                m.starHolding = true
                m.starLong = false
                m.starTimer.control = "stop"
                m.starTimer.control = "start"
            end if
        else
            m.starTimer.control = "stop"
            if m.starHolding and not m.starLong then toggleOrganize()
            m.starHolding = false
            m.starLong = false
        end if
        return true
    end if

    if m.organize and (m.zone = "drawer" or m.zone = "dock") and k = "ok" then
        if m.movingApp then
            if press then
                m.movingApp = false
                m.movingZone = ""
                m.organizeLabel.text = "ORGANIZING   ·   * DONE"
                updateHint()
                updateFocus()
            end if
            return true
        end if
        if press then
            if not m.okHolding then
                m.okHolding = true
                m.okHoldTimer.control = "stop"
                m.okHoldTimer.control = "start"
            end if
        else
            m.okHoldTimer.control = "stop"
            if m.okHolding then
                if m.zone = "drawer" then
                    addFav()
                else
                    if m.dockIndex < m.favorites.Count() then
                        removeDockFav()
                    else
                        openDrawer()
                    end if
                end if
            end if
            m.okHolding = false
        end if
        return true
    end if

    if not press then return false

    if m.menuOpen then
        if k = "up" then
            if m.menuIndex > 0 then m.menuIndex = m.menuIndex - 1
            updateMenu()
            return true
        end if
        if k = "down" then
            if m.menuIndex < m.menuItems.Count() - 1 then m.menuIndex = m.menuIndex + 1
            updateMenu()
            return true
        end if
        if k = "ok" then
            menuAction()
            return true
        end if
        if k = "back" then
            closeMenu()
            return true
        end if
        return true
    end if

    if k = "back" then
        if m.movingApp then
            m.movingApp = false
            m.movingZone = ""
            m.organizeLabel.text = "ORGANIZING   ·   * DONE"
            updateHint()
            updateFocus()
            return true
        end if
        if m.drawerOpen then
            closeDrawer()
            return true
        end if
        if m.organize then
            setOrganize(false)
            return true
        end if
        if m.zone = "cog" then
            m.zone = "dock"
            updateHint()
            updateFocus()
            return true
        end if
        return false
    end if

    if k = "ok" then
        if m.zone = "cog" then
            openMenu()
            return true
        end if
        if m.zone = "drawer" then
            if m.organize then
                addFav()
            else
                if m.allApps.Count() > 0 then launch(m.allApps[m.allIndex])
            end if
            return true
        end if
        if m.zone = "dock" then
            if m.organize and m.dockIndex < m.favorites.Count() then
                removeDockFav()
            else
                if m.dockIndex = m.favorites.Count() then
                    if m.drawerOpen then
                        closeDrawer()
                    else
                        openDrawer()
                    end if
                else
                    if m.favorites.Count() > 0 then launch(m.favorites[m.dockIndex])
                end if
            end if
            return true
        end if
    end if

    if m.zone = "cog" then
        if k = "down" then
            m.zone = "dock"
            updateHint()
            updateFocus()
            return true
        end if
        return true
    end if

    if m.zone = "drawer" then
        if m.movingApp then
            if k = "left" then
                moveDrawerApp(-1)
            else
                if k = "right" then
                    moveDrawerApp(1)
                else
                    if k = "up" then
                        moveDrawerApp(-m.cols)
                    else
                        if k = "down" then
                            moveDrawerApp(m.cols)
                        end if
                    end if
                end if
            end if
            return true
        end if
        if k = "left" then
            if m.allIndex > 0 then m.allIndex = m.allIndex - 1
        else
            if k = "right" then
                if m.allIndex < m.allApps.Count() - 1 then m.allIndex = m.allIndex + 1
            else
                if k = "down" then
                    if m.allIndex + m.cols < m.allApps.Count() then
                        m.allIndex = m.allIndex + m.cols
                    else
                        if m.drawerTiles.Count() > 0 then
                            t = m.drawerTiles[m.allIndex]
                            cx = m.drawerTilesGroup.translation[0] + t.x + m.drawerSize / 2
                            m.dockIndex = closestDockIndex(cx)
                        end if
                        m.zone = "dock"
                        updateFocus()
                        return true
                    end if
                else
                    if k = "up" then
                        if m.allIndex < m.cols then
                            closeDrawer()
                            return true
                        else
                            m.allIndex = m.allIndex - m.cols
                        end if
                    end if
                end if
            end if
        end if
        updateDrawerScroll()
        updateFocus()
        return true
    end if

    if m.zone = "dock" then
        if m.movingApp then
            if k = "left" then
                moveFavorite(-1)
            else
                if k = "right" then moveFavorite(1)
            end if
            return true
        end if
        if k = "left" then
            if m.dockIndex > 0 then m.dockIndex = m.dockIndex - 1
        else
            if k = "right" then
                if m.dockIndex < m.favorites.Count() then m.dockIndex = m.dockIndex + 1
            else
                if k = "up" then
                    if m.drawerOpen then
                        closeDrawer()
                        return true
                    end if
                    m.zone = "cog"
                    updateFocus()
                    return true
                end if
                if k = "down" then
                    if m.drawerOpen then
                        if m.dockTiles.Count() > 0 then
                            t = m.dockTiles[m.dockIndex]
                            cx = m.dockTilesGroup.translation[0] + t.x + m.dockSize / 2
                            cy = m.dockGroup.translation[1] + m.dockTilesGroup.translation[1] + t.y + m.dockSize / 2
                            m.zone = "drawer"
                            m.allIndex = closestDrawerIndex(cx, cy)
                            updateDrawerScroll()
                            updateFocus()
                        end if
                        return true
                    end if
                    openDrawer()
                    return true
                end if
            end if
        end if
        updateFocus()
        return true
    end if

    return false
end function

function appCategory(app as Object) as String
    if app = invalid then return ""
    if app.type = "allapps" then return "LIBRARY"
    if Instr(1, app.id, "tvinput.") = 1 then return "INPUT"
    if app.type <> "appl" then return "INPUT"
    id = app.id
    if id = "837" then return "VIDEO"
    if id = "12" then return "STREAMING"
    if id = "592369" then return "MEDIA SERVER"
    if id = "22297" then return "MUSIC"
    if id = "13" then return "STREAMING"
    if id = "61322" then return "STREAMING"
    if id = "291097" then return "STREAMING"
    if id = "151908" then return "FREE TV"
    if id = "2595" then return "ANIME"
    if id = "34376" then return "SPORTS"
    if id = "31440" then return "STREAMING"
    if id = "593099" then return "STREAMING"
    if id = "41468" then return "FREE TV"
    if id = "773622" then return "PHOTOS"
    if id = "551012" then return "STREAMING"
    return "APP"
end function

function appColor(app as Object) as String
    if app = invalid then return "0x8A8A8AFF"
    if app.type = "allapps" then return "0x8A8A8AFF"
    if Instr(1, app.id, "tvinput.") = 1 then return "0x8A8A8AFF"
    if app.type <> "appl" then return "0x8A8A8AFF"
    id = app.id
    if id = "837" then return "0xFF2D2DFF"
    if id = "12" then return "0xE50914FF"
    if id = "592369" then return "0xAA5CC3FF"
    if id = "22297" then return "0x1DB954FF"
    if id = "13" then return "0x00A8E1FF"
    if id = "61322" then return "0xA970FFFF"
    if id = "291097" then return "0x1F7FFFFF"
    if id = "151908" then return "0x6F1AB1FF"
    if id = "2595" then return "0xF47521FF"
    if id = "34376" then return "0xE50914FF"
    if id = "31440" then return "0x0064FFFF"
    if id = "593099" then return "0xF5C518FF"
    if id = "41468" then return "0x7B2FF7FF"
    if id = "773622" then return "0x2F80EDFF"
    if id = "551012" then return "0xA6A6A6FF"
    return "0x8A8A8AFF"
end function

function closestDockIndex(cx as Float) as Integer
    if m.dockTiles.Count() = 0 then return 0
    best = 0
    bestD = 100000.0
    for i = 0 to m.dockTiles.Count() - 1
        d = Abs(m.dockTilesGroup.translation[0] + m.dockTiles[i].x + m.dockSize / 2 - cx)
        if d < bestD then
            bestD = d
            best = i
        end if
    end for
    return best
end function

function closestDrawerIndex(cx as Float, cy as Float) as Integer
    if m.drawerTiles.Count() = 0 then return 0
    best = 0
    bestD = 1000000.0
    for i = 0 to m.drawerTiles.Count() - 1
        tx = m.drawerTilesGroup.translation[0] + m.drawerTiles[i].x + m.drawerSize / 2
        ty = m.drawerTilesGroup.translation[1] + m.drawerTiles[i].y + m.drawerSize / 2
        d = (tx - cx) * (tx - cx) + (ty - cy) * (ty - cy)
        if d < bestD then
            bestD = d
            best = i
        end if
    end for
    return best
end function

sub openMenu()
    m.menuOpen = true
    m.menuIndex = 0
    m.menuGroup.visible = true
    updateMenu()
end sub

sub closeMenu()
    m.menuOpen = false
    m.menuGroup.visible = false
end sub

sub updateMenu()
    for i = 0 to m.menuItems.Count() - 1
        if i = m.menuIndex then
            m.menuLabels[i].text = "> " + m.menuItems[i]
            m.menuLabels[i].color = "0xF4F3F0FF"
        else
            m.menuLabels[i].text = "  " + m.menuItems[i]
            m.menuLabels[i].color = "0xF4F3F0A0"
        end if
    end for
end sub

sub menuAction()
    if m.menuIndex = 0 then
        m.zone = "dock"
        closeMenu()
        setOrganize(true)
        return
    end if
    if m.menuIndex = 1 then
        toggleMonitor()
        return
    end if
    if m.menuIndex = 2 then
        cycleInterval()
        return
    end if
    if m.menuIndex = 3 or m.menuIndex = 4 or m.menuIndex = 5 then
        closeMenu()
        pauseHome()
        return
    end if
    if m.menuIndex = 6 then
        closeMenu()
        disableAuto()
        return
    end if
    closeMenu()
end sub

sub cycleInterval()
    values = [30, 60, 120, 300]
    nextIndex = 0
    for i = 0 to values.Count() - 1
        if values[i] = m.bgInterval then nextIndex = (i + 1) mod values.Count()
    end for
    m.bgInterval = values[nextIndex]

    sec = CreateObject("roRegistrySection", "launcher")
    sec.Write("photo_interval", StrI(m.bgInterval))
    sec.Flush()

    m.photoTimer.duration = m.bgInterval
    m.photoStartSec = nowSec()
    m.menuItems[2] = "Photo interval: " + intervalLabel(m.bgInterval)
    updateMenu()
end sub

sub toggleMonitor()
    m.monitorOn = not m.monitorOn
    sec = CreateObject("roRegistrySection", "launcher")
    if m.monitorOn then
        sec.Write("monitor", "1")
        m.monitorText.text = "CPU —    RAM —"
        m.menuItems[1] = "System monitor: On"
        m.monitorGroup.visible = true
        m.statsTimer.control = "start"
        fetchStats()
    else
        sec.Write("monitor", "0")
        m.menuItems[1] = "System monitor: Off"
        m.monitorGroup.visible = false
        m.monitorText.text = ""
        m.statsTimer.control = "stop"
    end if
    sec.Flush()
    updateMenu()
end sub

sub fetchStats()
    if not m.monitorOn then return
    if m.statsBusy then return
    m.statsBusy = true
    task = CreateObject("roSGNode", "HttpTask")
    task.url = m.helper + "/tvstats"
    task.method = "GET"
    task.observeField("responseCode", "onStats")
    task.control = "RUN"
    m.statsTask = task
end sub

sub onStats()
    m.statsBusy = false
    task = m.statsTask
    if task = invalid then return
    if task.responseCode <> 200 then
        m.monitorText.text = "CPU —    RAM —"
        return
    end if
    data = ParseJson(task.responseBody)
    if data = invalid then
        m.monitorText.text = "CPU —    RAM —"
        return
    end if
    if data.ok <> true then
        m.monitorText.text = "CPU —    RAM —"
        return
    end if
    m.monitorText.text = "CPU " + fmtTenths(data.cpu) + "%    RAM " + StrI(Int(data.ram_mb)) + " MB"
end sub

function fmtTenths(v) as String
    if v < 0 then v = 0
    whole = Int(v)
    frac = Int((v - whole) * 10)
    return StrI(whole) + "." + StrI(frac)
end function

function intervalLabel(sec as Integer) as String
    if sec = 30 then return "30s"
    if sec = 60 then return "60s"
    if sec = 120 then return "2m"
    if sec = 300 then return "5m"
    return StrI(sec) + "s"
end function

sub pauseHome()
    task = CreateObject("roSGNode", "HttpTask")
    task.url = m.helper + "/auto-launch/pause?seconds=600"
    task.method = "GET"
    task.observeField("responseCode", "onPaused")
    task.control = "RUN"
    m.pauseTask = task
end sub

sub onPaused()
    sendHome()
end sub

sub disableAuto()
    task = CreateObject("roSGNode", "HttpTask")
    task.url = m.helper + "/auto-launch/off"
    task.method = "GET"
    task.observeField("responseCode", "onAutoDisabled")
    task.control = "RUN"
    m.autoTask = task
end sub

sub onAutoDisabled()
    sendHome()
end sub

sub sendHome()
    task = CreateObject("roSGNode", "HttpTask")
    task.url = m.helper + "/home"
    task.method = "GET"
    task.control = "RUN"
    m.homeTask = task
end sub

sub launch(app as Object)
    showToast("Launching " + displayName(app))
    task = CreateObject("roSGNode", "HttpTask")
    task.url = m.helper + "/launch/" + app.id
    task.method = "POST"
    task.control = "RUN"
    m.launchTask = task
end sub

sub showToast(text as String)
    m.toastLabel.text = text
    m.toastGroup.visible = true
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub onToast()
    m.toastGroup.visible = false
end sub

sub addFav()
    if m.allApps.Count() = 0 then return
    app = m.allApps[m.allIndex]
    m.allApps.Delete(m.allIndex)
    m.favorites.Push(app)
    if m.allIndex >= m.allApps.Count() then m.allIndex = m.allApps.Count() - 1
    if m.allIndex < 0 then m.allIndex = 0
    saveFavorites()
    saveDrawerOrder()
    renderDock()
    renderDrawer()
    updateFocus()
    showToast("Added " + displayName(app) + " to dock")
end sub

sub removeDockFav()
    if m.favorites.Count() = 0 then return
    app = m.favorites[m.dockIndex]
    m.favorites.Delete(m.dockIndex)
    m.allApps.Push(app)
    if m.dockIndex >= m.favorites.Count() then m.dockIndex = m.favorites.Count() - 1
    if m.dockIndex < 0 then m.dockIndex = 0
    saveFavorites()
    saveDrawerOrder()
    renderDock()
    renderDrawer()
    updateFocus()
    showToast("Removed " + displayName(app) + " from dock")
end sub

sub moveDrawerApp(delta as Integer)
    j = m.allIndex + delta
    if j < 0 or j >= m.allApps.Count() then return
    tmp = m.allApps[m.allIndex]
    m.allApps[m.allIndex] = m.allApps[j]
    m.allApps[j] = tmp
    m.allIndex = j
    saveDrawerOrder()
    renderDrawer()
    updateFocus()
end sub

sub moveFavorite(dir as Integer)
    j = m.dockIndex + dir
    if j < 0 or j >= m.favorites.Count() then return
    tmp = m.favorites[m.dockIndex]
    m.favorites[m.dockIndex] = m.favorites[j]
    m.favorites[j] = tmp
    m.dockIndex = j
    saveFavorites()
    renderDock()
    updateFocus()
end sub

sub nextBgPhoto()
    m.photoTick = m.photoTick + 1
    m.photoStartSec = nowSec()
    url = m.helper + "/photo?t=" + StrI(m.photoTick)
    if m.bgActive = 0 then
        m.bg2.uri = url
        m.bg2.opacity = 0
        m.bgIncoming = m.bg2
        m.bgOutgoing = m.bg
    else
        m.bg.uri = url
        m.bg.opacity = 0
        m.bgIncoming = m.bg
        m.bgOutgoing = m.bg2
    end if
    m.bgGroup.removeChild(m.bgIncoming)
    m.bgGroup.appendChild(m.bgIncoming)
    m.bgPending = true
end sub

sub onBgLoaded()
    if not m.bgPending then return
    if m.bgIncoming = invalid then return
    if m.bgIncoming.loadStatus = "loaded" then
        m.bgPending = false
        m.bgFadeRunning = true
        m.bgFadeTimer.control = "start"
    end if
end sub

sub onBgFade()
    if not m.bgFadeRunning then return
    if m.bgIncoming = invalid or m.bgOutgoing = invalid then return
    op = m.bgIncoming.opacity + 0.1
    if op >= 1.0 then
        m.bgIncoming.opacity = 1.0
        m.bgOutgoing.opacity = 0.0
        m.bgActive = 1 - m.bgActive
        m.bgFadeRunning = false
        m.bgFadeTimer.control = "stop"
    else
        m.bgIncoming.opacity = op
    end if
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

    days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    wd = dt.GetDayOfWeek()
    day = dt.GetDayOfMonth()
    mo = dt.GetMonth()
    m.date.text = days[wd] + ", " + StrI(day) + " " + months[mo - 1]
end sub

sub onDrift()
    m.driftT = m.driftT + 0.1
    angle = m.driftT * 6.283185 / 120.0
    m.content.translation = [4.0 * Sin(angle), 2.0 * Cos(angle)]

    frac = 1.0 - (nowSec() - m.photoStartSec) / m.bgInterval
    if frac < 0 then frac = 0
    if frac > 1 then frac = 1
    m.barFill.width = 260 * frac
end sub

function nowSec() as Integer
    d = CreateObject("roDateTime")
    d.Mark()
    return d.AsSeconds()
end function

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
