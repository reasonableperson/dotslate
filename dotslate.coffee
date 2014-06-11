slate.log "Running dotslate.coffee."

# # # # # # # # # # # # # # # # # # # #
#          Resize + Throw             #
# # # # # # # # # # # # # # # # # # # #

# Fix JS's buggy modulo function.
mod = (n, m) -> ((n % m) + m) % m

# What edges is this window close to? 
closeEdges = (win) ->
    scr = win.screen().rect()
    wrc = win.rect()
    proximity =
        left:   wrc.x - scr.x
        right:  wrc.x + wrc.width - scr.x - scr.width
        top:    wrc.y - scr.y - 22 # menu bar
        bottom: wrc.y + wrc.height - scr.y - scr.height
    # slate.log "Proximity object: #{JSON.stringify(proximity)}"
    (edge for edge, prox of proximity when Math.abs(prox) < 10)

# Factory for functions that resize a window as a proportion of
# its current screen's dimensions.
resizeFrac = (p, q, screenId = null, subsplit = false) ->
    (win) ->
        # which direction to scale in?
        screen = if screenId? then slate.screenr(screenId) else win.screen()
        slate.log 'screenID', screenId, 'screen', screen
        scr = screen.rect()
        [w, h] = [scr.width, scr.height]
        widescreen = w > h

        # if a subsplit, retain one dimension - don't scale from full screen
        if subsplit and widescreen then w = win.rect().width
        if subsplit and not(widescreen) then h = win.rect().height
        
        # scale according to the fraction    
        scaleHorizontally = if subsplit then not widescreen else widescreen
        if scaleHorizontally then w = scr.width  * p / q
        else                      h = scr.height * p / q

        # Stick to edges
        edges = closeEdges(win)
        [vAnchor, hAnchor] = ['top', 'left']
        if 'right' in edges and 'left' not in edges then hAnchor = 'right'
        if 'bottom' in edges and 'top' not in edges then vAnchor = 'bottom'
        anchor = "#{vAnchor}-#{hAnchor}"

        # carry out operations
        win.doOperation slate.operation "corner", {direction: anchor, width: w, height: h, screen: screen}

# Fractional resize bindings
bindFrac = (p, q) ->
  bindString = "#{q}:#{p};ctrl"
  # slate.log "Binding " + bindString + "."
  slate.bind bindString, resizeFrac(p, q)
  slate.bind bindString + ";cmd", resizeFrac(p, q, null, true)
bindFrac 1, q for q in [1, 2, 3, 4]
bindFrac p, q for [p, q] in [[2, 3], [3, 4]]

# Throw + fractional resize
throwPreservingFrac = (increment) ->
    (win) ->
        scr = win.screen().rect()
        wrc = win.rect()
        widescreen = scr.width > scr.height
        dim = if widescreen then 'width' else 'height'
        proportion = wrc[dim] / scr[dim]
        screenId = mod(slate.screen().id() + increment, slate.screenCount())
        slate.log 'throwing', screenId
        resizeFrac(proportion, 1, screenId) win

slate.bind "9:e;ctrl", throwPreservingFrac -1
slate.bind "0:e;ctrl", throwPreservingFrac 1

# # # # # # # # # # # # # # # # # # # #
#              Layouts                #
# # # # # # # # # # # # # # # # # # # #

focus = (win) -> win.focus()
work = slate.layout 'work',
    'Google Chrome': {operations: [resizeFrac(2, 3, 0), focus]}
    'iTerm': {operations: [resizeFrac(1, 3, 0), resizeFrac(2, 3, 0, true), focus]}
    'Adium': {operations: [resizeFrac(1, 3, 0), resizeFrac(1, 3, 0, true), focus]}
    'Microsoft Outlook': {operations: [resizeFrac(2, 3, 1), focus]}
    'Calendar': {operations: [resizeFrac(1, 3, 1), focus]}
slate.bind "8:e;ctrl", slate.operation('layout', {name: 'work'})

# # # # # # # # # # # # # # # # # # # #
#        Application-specific         #
# # # # # # # # # # # # # # # # # # # #

customBindingMap =
    c: 'Google Chrome'
    x: 'Microsoft Excel'
    d: 'Microsoft Word'
    o: 'Microsoft Outlook'
    i: 'iTunes'
    t: 'iTerm'
    w: 'VMware Fusion'
    w: 'Microsoft Remote Desktop'
    v: 'Cisco AnyConnect Secure Mobility Client'

# Find apps beginning with the given letter.
filterApps = (key) ->
    result = []
    priorityApp = null
    slate.eachApp (a) ->
        if not a
            return false
        if customBindingMap[key] == a.name()
            priorityApp = a
            result.push(a)
        if a.name()[0].toLowerCase() == key
            result.push(a)
    slate.log "Possible apps:", (a.name() for a in result)
    return [result, priorityApp]

chooseApp = (apps, priorityApp, currentWin, key) ->
    if not currentWin
        return priorityApp
    if not currentWin.app().pid() in (a.pid() for a in apps)
        return priorityApp
    else
        apps = (a for a in apps when getWins(a).length > 0)
        return apps.slice(-1)[0]

getWins = (app) ->
    windows = []
    app.eachWindow (w) -> windows.push(w)
    return windows

chooseWin = (app, currentWin) ->
    wins = getWins app
    slate.log 'windows:', (w.title() for w in wins)
    if wins[0].app().pid() is currentWin.app().pid()
        slate.log 'returning last window'
        return wins.slice(-1)[0]
    else
        slate.log 'returning first window'
        return wins[0]

# Choose an app window and focus it.
focusWindow = (key, win) ->
    if win then winName = win.app().name()
    else        winName = "(none)"

    slate.log "keypress: #{key}, sourceWindow: #{winName}"
    [apps, priorityApp] = filterApps key

    if apps.length == 0
        slate.log "Tried to switch to an app with no binding."
        return

    app = chooseApp apps, priorityApp, win, key
    slate.log "Target app", app.name()
    win = chooseWin app, win
    if win
        slate.log "Target window", win.title()
        win.focus()
    else
        slate.log "No window to target"
        op = slate.operation "focus", {app: app}
        op.run()


# func to bind a key in command mode
bindKey = (key, app) ->
    bindStr = "#{key}:e;ctrl"
    slate.bind bindStr, (win) -> focusWindow key, win

# bind all letters of the alphabet
ex = ['r', 'j', 'k'] # don't bind these keys
chr = (int) -> String.fromCharCode(x)
bindKey k for k in (chr x for x in [97..122] when chr x not in ex)
