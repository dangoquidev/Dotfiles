hl.config({ animations = { enabled = true } })

local function bezier(name, x1, y1, x2, y2)
    hl.curve(name, { type = "bezier", points = { {x1, y1}, {x2, y2} } })
end

bezier("smoothOut",  0.36, 0,   0.66, -0.56)
bezier("smoothIn",   0.25, 1,   0.5,  1)
bezier("overshot",   0.4,  0.8, 0.2,  1.2)
bezier("softSnap",   0.2,  1,   0.3,  1)
bezier("bounce",     0.6,  1.4, 0.3,  1)
bezier("fadeSmooth", 0.4,  0,   0.2,  1)

local function anim(leaf, speed, curve, style)
    hl.animation({ leaf = leaf, enabled = true, speed = speed, bezier = curve, style = style })
end

anim("windows",     5, "overshot",  "slide")
anim("windowsIn",   5, "overshot",  "popin 80%")
anim("windowsOut",  4, "smoothOut", "popin 80%")
anim("windowsMove", 4, "softSnap")

anim("border", 8, "softSnap")

anim("fade",       4, "fadeSmooth")
anim("fadeIn",     4, "fadeSmooth")
anim("fadeOut",    3, "fadeSmooth")
anim("fadeSwitch", 4, "fadeSmooth")
anim("fadeShadow", 4, "fadeSmooth")
anim("fadeDim",    4, "fadeSmooth")

anim("workspaces",       5, "overshot", "slide")
anim("specialWorkspace", 5, "bounce",   "slidefade -50%")

anim("layers",    4, "softSnap",  "fade")
anim("layersIn",  4, "overshot",  "fade")
anim("layersOut", 3, "smoothOut", "fade")
