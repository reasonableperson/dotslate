slate.log "Running dotslate.coffee."

# # # # # # # # # # # # # # # # # # # #
#          Resize + Throw             #
# # # # # # # # # # # # # # # # # # # #

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
modulo = (n, m) -> ((n % m) + m) % m
throwPreservingFrac = (increment) ->
    (win) ->
        scr = win.screen().rect()
        wrc = win.rect()
        widescreen = scr.width > scr.height
        dim = if widescreen then 'width' else 'height'
        proportion = wrc[dim] / scr[dim]
        numScreens = slate.screenCount()
        screenId = modulo slate.screen().id()+increment, numScreens
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
#              App-switcher           #
# # # # # # # # # # # # # # # # # # # #

# These keys will preferentially take you to the given app,
# even though it doesn't start with that letter.
priorityBindings =
    x: 'Microsoft Excel'
    d: 'Microsoft Word'
    o: 'Microsoft Outlook'
    r: 'Microsoft Remote Desktop'
    t: 'iTerm'
    w: 'VMware Fusion'
    v: 'Cisco AnyConnect Secure Mobility Client'

# Find apps that could be selected using the given key.
filterApps = (key) ->
    result = []
    priorityApp = null
    slate.eachApp (a) ->
        if not a
            return false
        if priorityBindings[key] == a.name()
            priorityApp = a
            result.push(a)
        if a.name()[0].toLowerCase() == key
            result.push(a)
    return [result, priorityApp]

# Collect all windows in a list.
getWins = (app) ->
    w = []
    app.eachWindow (me) -> w.push(me)
    return w

# If we're in the same letter group as the priority app, cycle
# through all apps with visible windows (to avoid getting stuck
# on the priority app). Otherwise, choose the priority app. If
# there is no priority app, choose the first app with windows,
# or just the first app, or nothing.
chooseApp = (apps, priorityApp, curWin) ->
    appsWithWindows = (a for a in apps when getWins(a).length > 0)
    if curWin and curWin.app().pid() in (a.pid() for a in apps)
        return appsWithWindows.slice(-1)[0]
    else if priorityApp
        return priorityApp
    else if appsWithWindows.length > 0
        return appsWithWindows[0]
    else if apps.length > 0
        return apps[0]
    else
        return null

# Command handler.
focusApp = (key, win) ->
    winName = win ? win.app().name() or "(none)"
    slate.log "keypress: #{key}, sourceWindow: #{win}"

    [apps, priorityApp] = filterApps key
    slate.log "Possible apps:", (a.name() for a in apps)

    app = chooseApp apps, priorityApp, win
    if not app
        slate.log "Tried to switch to an app with no binding."
    else
        slate.log "Target app", app.name()
        (slate.operation "focus", {app: app}).run()

# Bind all letters of the alphabet to focusApp
bindKey = (key, app) ->
    bindStr = "#{key}:e;ctrl"
    slate.bind bindStr, (win) -> focusApp key, win
ex = ['r', 'j', 'k'] # except these keys
chr = (int) -> String.fromCharCode(x)
letters = (chr x for x in [97..122] when chr x not in ex)
numbers = (x.toString() for x in [0..9])
bindKey k for k in letters.concat numbers
