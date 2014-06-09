slate.log "Running dotslate.coffee."

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
resizeFrac = (p, q, subsplit = false) ->
    (win) ->
        # which direction to scale in?
        scr = win.screen().rect()
        [w, h] = [scr.width, scr.height]
        widescreen = w > h

        # if a subsplit, retain one dimension - don't scale from full screen
        if subsplit and widescreen then w = win.rect().width
        if subsplit and not(widescreen) then h = win.rect().height
        
        # scale according to the fraction    
        scaleHorizontally = if subsplit then not widescreen else widescreen
        if scaleHorizontally then w = scr.width  * p / q
        else                      h = scr.height * p / q

        # work out if we need to push the window        
        edges = closeEdges(win)
        # slate.log "widescreen?", widescreen, "edges", edges
        if widescreen and 'right' in edges
            push = slate.operation 'push', {direction: 'right'}
        if not widescreen and 'bottom' in edges
            push = slate.operation 'push', {direction: 'bottom'}

        # carry out operations
        win.doOperation slate.operation "move", {x: scr.x, y: scr.y, width: w, height: h}
        slate.log push
        if push then win.doOperation push

# Fractional resize bindings
bindFrac = (p, q) ->
  bindString = "#{q}:#{p};ctrl"
  # slate.log "Binding " + bindString + "."
  slate.bind bindString, resizeFrac(p, q)
  slate.bind bindString + ";cmd", resizeFrac(p, q, true)
bindFrac 1, q for q in [1, 2, 3, 4]
bindFrac p, q for [p, q] in [[2, 3], [3, 4]]

# Throw + fractional resize
throwPreservingFrac = (screenId) ->
    (win) ->
        scr = win.screen().rect()
        wrc = win.rect()
        widescreen = scr.width > scr.height
        dim = if widescreen then 'width' else 'height'
        proportion = wrc[dim] / scr[dim]
        op = slate.operation 'throw', {screen: screenId}
        win.doOperation op
        resizeFrac(proportion, 1) win

slate.bind "9:e;ctrl", throwPreservingFrac 0
slate.bind "0:e;ctrl", throwPreservingFrac 1
