resizeFrac = (p, q, contrary = false) ->
    # Returns a function that resizes the window to the given
    # proportions.
    (win) ->
        scr = win.screen().rect()
        [w, h] = [scr.width, scr.height]
        widescreen = w > h
        if widescreen or (not widescreen) and contrary
            w = scr.width * p / q
        else if (not widescreen) or widescreen and contrary
            h = scr.height * p / q
        slate.log "frac", p, q, "dim", w, h
        win.doOperation slate.operation "move",
            x: scr.x
            y: scr.y
            width: w
            height: h

bindFrac = (p, q) ->
  bindString = "#{q}:#{p};ctrl"
  slate.log "Binding " + bindString + "."
  slate.bind bindString, resizeFrac(p, q)
  slate.bind bindString + ";cmd", resizeFrac(p, q, true)

bindFrac 1, q for q in [1, 2, 3, 4]
bindFrac p, q for [p, q] in [[2, 3], [3, 4]]
