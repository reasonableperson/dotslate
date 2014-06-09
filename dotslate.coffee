slate.log "Running dotslate.coffee."

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

        # Stick to edges
        anchor = 'top-left'
        edges = closeEdges(win)
        if widescreen and 'right' in edges and 'left' not in edges
            anchor = 'top-right'
        if not widescreen and 'bottom' in edges and 'top' not in edges
            anchor = 'bottom-left'

        # carry out operations
        win.doOperation slate.operation "corner", {direction: anchor, width: w, height: h}

# Fractional resize bindings
bindFrac = (p, q) ->
  bindString = "#{q}:#{p};ctrl"
  # slate.log "Binding " + bindString + "."
  slate.bind bindString, resizeFrac(p, q)
  slate.bind bindString + ";cmd", resizeFrac(p, q, true)
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
        win.doOperation slate.operation 'throw', {screen: screenId}
        resizeFrac(proportion, 1) win

slate.bind "[:e;ctrl;cmd", throwPreservingFrac -1
slate.bind "]:e;ctrl;cmd", throwPreservingFrac 1
