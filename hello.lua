--[[ ============================================================
     testclaude  -  Neverlose CS:GO Lua  (sandbox / working file)

     Notifications  -  "Hit <name>'s <chest> for <70>!" hit popups
                       (cleaned + extracted from exaples/expalce.lua)

     Colored text uses Neverlose's inline codes:
       \aRRGGBBAA  sets color    \aDEFAULT  resets to the base color
============================================================ ]]--

ui.sidebar('Xify Utils', 'fill-drip')

-- Seed the RNG once so anti-brute [o:..:d:..] values differ between sessions.
math.randomseed(globals.realtime * 1000 + globals.tickcount)

local function lerp(a, b, t) return a + (b - a) * t end

local hitgroups = {
    [0] = "generic", [1] = "head",      [2] = "chest",     [3] = "stomach",
    [4] = "left arm",[5] = "right arm", [6] = "left leg",  [7] = "right leg",
    [8] = "neck",    [10] = "gear",
}

-- Optional flavor verbs; anything unknown just says "Hit".
local wpn2act = {
    knife = "Knifed", bayonet = "Knifed",
    hegrenade = "Naded", inferno = "Burned", molotov = "Burned",
}

-- The popup manager: a stacked, fading list drawn bottom-center.
local notify = {
    list        = {},
    base_offset = 100,  -- distance of the first popup from the bottom
    per_offset  = 35,   -- vertical gap between stacked popups
    max_visible = 3,    -- popups beyond this fade out
    anim_speed  = 12,   -- higher = snappier fade/slide
    rounding    = 6,    -- box corner rounding (driven by the slider below)
    glow        = true, -- colored glow under the box (driven by the switch below)
    style       = 1,    -- 1 = current look, 2 = alternate (built later)
    scheduled   = {},   -- delayed pushes waiting on realtime (no sleep in Neverlose)
}

-- `brand` is the style #2 prefix word ("amnesia" by default, "!" for anti-brute).
function notify.push(text, clr, duration, brand)
    table.insert(notify.list, 1, {
        text        = text,
        color       = clr,
        brand       = brand,
        state       = 0,    -- 0..1 fade/scale amount
        offset      = 50,   -- current animated Y offset from bottom
        shows_until = globals.realtime + (duration or 3),
    })
end

-- Queue a push to fire `delay` seconds from now (driven from the render loop).
function notify.schedule(delay, text, clr, duration, brand)
    table.insert(notify.scheduled, {
        at       = globals.realtime + delay,
        text     = text,
        color    = clr,
        duration = duration,
        brand    = brand,
    })
end

-- Fire any scheduled pushes whose time has come. Call once per frame.
function notify.tick_scheduled()
    local now = globals.realtime
    for i = #notify.scheduled, 1, -1 do
        local s = notify.scheduled[i]
        if now >= s.at then
            notify.push(s.text, s.color, s.duration, s.brand)
            table.remove(notify.scheduled, i)
        end
    end
end

-- Prepend the configured icon glyph (refreshed each frame from the menu) to a
-- message, colored to match. Returns text unchanged when no icon is selected.
function notify.with_icon(text, clr)
    local glyph = notify.icon_glyph or ""
    if glyph == "" then return text end
    return "\a" .. clr:to_hex() .. glyph .. " \aDEFAULT" .. text
end

-- Style #1: the current look (glow + dark rounded box + centered white text).
function notify.draw_style1(text, offset, state, clr)
    local alpha = math.floor(state * 255)
    if alpha <= 0 then return end

    local full   = notify.with_icon(text, clr)  -- icon at the left of the message
    local screen = render.screen_size()
    local tsize  = render.measure_text(1, nil, full)
    local pad    = vector(27, 12)
    local box    = tsize + pad
    local round  = notify.rounding
    local pos    = vector(screen.x / 2 - tsize.x / 2 - pad.x, screen.y - math.floor(offset))

    -- Colored shadow = the glow under the box; dark bg; white-base centered text.
    if notify.glow then
        render.shadow(pos, pos + box, color(clr.r, clr.g, clr.b, alpha), 45, 1, round)
    end
    render.rect(pos, pos + box, color(23, 23, 23, alpha), round)
    render.text(1, pos + box / 2, color(255, 255, 255, alpha), "c", full)
end

-- Style #2: based on style #1, with a vertically thinner box.
function notify.draw_style2(text, offset, state, clr, brand)
    local alpha = math.floor(state * 255)
    if alpha <= 0 then return end

    -- brand prefix in the real bold font (preset 4); message in normal (1).
    local word   = brand or "amnesia"
    local pfx    = string.format("\a%s%s\aDEFAULT ", clr:to_hex(), word)
    local pfx_s  = render.measure_text(4, nil, pfx)
    local msg_s  = render.measure_text(1, nil, text)
    local tw     = pfx_s.x + msg_s.x
    local th     = math.max(pfx_s.y, msg_s.y)

    local screen = render.screen_size()
    local pad    = vector(27, 8)   -- pad.y controls box height
    local box    = vector(tw + pad.x, th + pad.y)
    local round  = notify.rounding
    local pos    = vector(screen.x / 2 - box.x / 2, screen.y - math.floor(offset))

    -- Style #2 glow is permanent (not tied to the style #1 glow switch).
    -- Keep the spread wide (soft, no cut); shrink the glow by lowering its opacity %.
    -- Shorter (narrower) popups get a smaller %, but floored so the glow stays visible.
    local glow_pct   = math.max(0.42, 0.5 * math.min(1, box.x / 380))
    local glow_alpha = math.floor(alpha * glow_pct)
    render.shadow(pos, pos + box, color(clr.r, clr.g, clr.b, glow_alpha), 45, 1, round)
    render.rect(pos, pos + box, color(23, 23, 23, alpha), round)

    local white = color(255, 255, 255, alpha)
    local leftX = pos.x + pad.x / 2
    local cy    = pos.y + box.y / 2
    local pfx_y = cy - pfx_s.y / 2

    -- brand (bold preset 4) then the message (normal preset 1), both centered.
    -- nudge the "!" brand a little to the left; "amnesia" stays put.
    local pfx_x_off = -3
    render.text(4, vector(leftX + pfx_x_off, pfx_y), white, nil, pfx)
    render.text(1, vector(leftX + pfx_s.x, cy - msg_s.y / 2), white, nil, text)
end

function notify.draw(text, offset, state, clr, brand)
    if notify.style == 2 then
        return notify.draw_style2(text, offset, state, clr, brand)
    end
    return notify.draw_style1(text, offset, state, clr)
end

function notify.handle()
    local list = notify.list
    if #list == 0 then return end

    local now  = globals.realtime
    local t    = math.min((globals.frametime or 0.016) * notify.anim_speed, 1)
    local base = notify.base_offset

    for i = 1, #list do
        local n       = list[i]
        base          = base + notify.per_offset
        local visible = (n.shows_until > now) and (i <= notify.max_visible)
        n.state  = lerp(n.state, visible and 1 or 0, t)
        n.offset = lerp(n.offset, base, t)
        notify.draw(n.text, n.offset, n.state, n.color, n.brand)
    end

    -- Drop popups that have fully faded out (iterate backwards for safe removal).
    for i = #list, 1, -1 do
        local n = list[i]
        if n.state < 0.01 and n.shows_until <= now then
            table.remove(list, i)
        end
    end
end

-- Information panel: static text via group:label(). Labels accept FontAwesome
-- glyphs (ui.get_icon) and inline \a color codes, just like render text.
local accent = "96C83CFF"  -- green accent (\aRRGGBBAA), matches the notify color
local function get_user()
    local ok, name = pcall(common.get_username)
    if ok and type(name) == "string" and name ~= "" then return name end
    return "player"
end

-- Brand prefix shown before each style #2 popup (like "amnesia" in the reference).
notify.brand = get_user()

local info_grp = ui.create("A", "Information")
info_grp:label(string.format("\a%s%s\aDEFAULT Welcome back, \a%s%s\aDEFAULT!",
    accent, ui.get_icon("bell"), accent, get_user()))
info_grp:label(string.format("\a%s%s\aDEFAULT Last Update: 07.05.26",
    accent, ui.get_icon("clock")))
info_grp:label(string.format("\a%s%s\aDEFAULT Current Build: \a%sLive\aDEFAULT",
    accent, ui.get_icon("tag"), accent))

-- UI
local nf_grp     = ui.create("B", "Notifications")
local nf_enabled = nf_grp:switch("Enabled", true)
local nf_color   = nf_enabled:color_picker(color(150, 200, 60, 255)) -- 96C83C green
local nf_cfg     = nf_enabled:create()
-- Style picker (top of the group). Style #1 = current look; Style #2 = built later.
local nf_style   = nf_grp:combo("Style", "Style #1", "Style #2")
-- Prefix icon options. Values come from ui.get_icon("<FontAwesome name>");
-- add any FA name you want here and it shows up in the dropdown.
local icon_map = {
    ["Star"]      = ui.get_icon("stars"),
    ["L"]         = "L",
    ["Triangle"]  = ui.get_icon("triangle-exclamation"),
    ["Skull"]     = ui.get_icon("skull"),
    ["Crosshair"] = ui.get_icon("crosshairs"),
    ["Lightning"] = ui.get_icon("bolt"),
    ["Fire"]      = ui.get_icon("fire"),
    ["None"]      = "",
}
local nf_icon    = nf_cfg:combo("Icon", "Star", "L", "Triangle", "Skull", "Crosshair", "Lightning", "Fire", "None")
local nf_time    = nf_cfg:slider("Show time (sec)", 1, 8, 3)
local nf_round   = nf_cfg:slider("Rounding", 0, 16, 6)
local nf_brute   = nf_cfg:switch("Anti-bruteforce notify", true)
-- One shared notify checklist (replaces the per-style Hit/Reset switches).
-- Items carry FontAwesome icons; match against the LBL_ consts below.
local LBL_HIT   = ui.get_icon("crosshairs")    .. " Hit notify"
local LBL_RESET = ui.get_icon("arrows-rotate") .. " Reset notify"
local LBL_GLOW  = ui.get_icon("sun")           .. " Glow"
-- Glow is only a list item in Style #1; Style #2 has permanent glow.
local STYLE1_ITEMS = { LBL_HIT, LBL_RESET, LBL_GLOW }
local STYLE2_ITEMS = { LBL_HIT, LBL_RESET }
local function nf_is_style1()
    local s = nf_style:get()
    return not (s == "Style #2" or s == 2)
end
-- Build with the set matching the saved style, so no load-time :update is
-- needed (a redundant update could wipe the saved ticks).
local nf_types  = nf_grp:listable("",
    nf_is_style1() and STYLE1_ITEMS or STYLE2_ITEMS)

-- listable:get() returns an array of the checked items' 1-based indices,
-- e.g. {1} = Hit, {2} = Reset, {3} = Glow, {} = none.
local IDX_HIT, IDX_RESET, IDX_GLOW = 1, 2, 3
local function list_has(t, idx)
    if type(t) ~= "table" then return false end
    for _, v in pairs(t) do if v == idx then return true end end
    return false
end

-- Each style shows its own controls and hides the other's.
-- force_call (true) applies it on load too. Only re-feed the list when the
-- item set actually changes, so a redundant :update can't wipe saved ticks.
local last_style1 = nf_is_style1()  -- list was created with this set already
nf_style:set_callback(function()
    local style1 = nf_is_style1()
    if style1 ~= last_style1 then
        last_style1 = style1
        nf_types:update(style1 and STYLE1_ITEMS or STYLE2_ITEMS)
    end
end, true)

-- Shared across both styles now: read straight from the notify checklist.
local function hit_on()   return list_has(nf_types:get(), IDX_HIT)   end
local function reset_on() return list_has(nf_types:get(), IDX_RESET) end

-- Builds the colored "Hit <name>'s <group> for <dmg>!" string.
local function format_hit(name, hitgroup_idx, dmg, weapon)
    local clr   = nf_color:get()
    local hex   = clr:to_hex()
    local group = hitgroups[hitgroup_idx] or "?"
    local verb  = wpn2act[weapon] or "Hit"

    local body = string.format(
        "%s \a%s%s\aDEFAULT's \a%s%s \aDEFAULTfor \a%s%s\aDEFAULT!",
        verb, hex, name, hex, group, hex, dmg
    )
    return body, clr
end

-- "<verb> [jitter] <reason>"  (the state word is colored in the hit color; same popup style).
local brute_state = "jitter"  -- the anti-aim condition shown inside the brackets
local function format_state(verb, reason)
    local clr  = nf_color:get()
    local hex  = clr:to_hex()
    local body = string.format("%s [\a%s%s\aDEFAULT] %s", verb, hex, brute_state, reason)
    return body, clr
end
-- Anti-brute text differs per style:
--   Style #1: original "changed [jitter] due to hit"
--   Style #2: "<name> anti-bruteforce to enable [o:13:d:34] [stage 1]" (name colored).
local function format_brute(name, o, d, stage)
    if notify.style ~= 2 then
        return format_state("changed", "due to hit")
    end
    local clr = nf_color:get()
    name  = name  or "alexmrr1029"
    o     = o     or math.random(11, 89)  -- random each push
    d     = d     or math.random(11, 89)  -- random each push
    stage = stage or 1
    -- name left uncolored so it matches the normal (white) message text.
    local body = string.format(
        "%s anti-bruteforce to enable [o:%s:d:%s] [stage %s]",
        name, o, d, stage
    )
    return body, clr
end
local function format_round()
    return "anti-bruteforce reseted", nf_color:get()
end

-- Push the anti-brute popup. In style #2 only, queue the "reseted" popup ~4.5s later.
local BRUTE_RESET_DELAY = 4.5
local function push_brute(name, o, d, stage)
    local text, clr = format_brute(name, o, d, stage)
    local dur = nf_time:get()
    notify.push(text, clr, dur, "!")
    if notify.style == 2 then
        notify.schedule(BRUTE_RESET_DELAY, "anti-bruteforce reseted", clr, dur, "!")
    end
end

-- Real trigger: only when the local player damages someone else.
events.player_hurt:set(function(e)
    if not nf_enabled:get() or not hit_on() then return end

    local me = entity.get_local_player()
    if not me then return end

    local victim   = entity.get(e.userid, true)
    local attacker = entity.get(e.attacker, true)
    if not victim or not attacker then return end
    if victim == me or attacker ~= me then return end

    local text, clr = format_hit(victim:get_name(), e.hitgroup, e.dmg_health, e.weapon)
    notify.push(text, clr, nf_time:get())
end)

-- Anti-bruteforce: there is no "console output" event in Neverlose, so we detect
-- the same condition the console line reacts to -- an enemy firing a bullet that
-- passes near you -- via the bullet_impact event (same approach the gazolina script uses).
local ab_last_tick = 0
local ab_next_time = 0
events.bullet_impact:set(function(e)
    if not nf_enabled:get() or not nf_brute:get() then return end

    local me = entity.get_local_player()
    if not me or not me:is_alive() then return end

    local shooter = entity.get(e.userid, true)
    if not shooter or not shooter:is_alive() or not shooter:is_enemy() then return end

    -- one trigger per tick + a short cooldown so rapid fire doesn't spam popups
    local tick = globals.tickcount
    if tick == ab_last_tick or globals.realtime < ab_next_time then return end

    -- was the shot actually aimed at you? measure the bullet ray's distance to your chest.
    local me_pos = me:get_origin() + vector(0, 0, 46)
    local eye    = shooter:get_eye_position()
    local impact = vector(e.x, e.y, e.z)
    local dir    = (impact - eye):normalized()
    if me_pos:dist_to_ray(eye, dir) > 50 then return end

    ab_last_tick = tick
    ab_next_time = globals.realtime + 0.25

    push_brute(shooter:get_name())
end)

-- New round: push the "Changed [jitter] due to new round" popup.
events.round_start:set(function()
    if not nf_enabled:get() or not reset_on() then return end
    local text, clr = format_round()
    notify.push(text, clr, nf_time:get(), "!")
end)

-- On-load greeting: show a "loading" popup now, then a "loaded" welcome ~3.5s later.
-- (Neverlose has no sleep, so the delay is driven by realtime in the render loop.)
local LOAD_DELAY    = 3.5
local load_time     = globals.realtime
local welcome_shown = false

local function format_welcome()
    local clr  = nf_color:get()
    -- name colored with the color picker value.
    local body = string.format("successfully loaded lua script Welcome back \a%s%s\aDEFAULT!", clr:to_hex(), get_user())
    return body, clr
end

-- Push the "loading" popup immediately on load.
if nf_enabled:get() then
    notify.push("thinking.....wait please", nf_color:get(), LOAD_DELAY)
end

-- combo:get() returns the selected option string. Map it to a style index.
local function current_style()
    local sel = nf_style:get()
    if type(sel) == "number" then return sel end  -- in case it returns an index
    return sel == "Style #2" and 2 or 1
end

events.render:set(function()
    notify.rounding   = nf_round:get()
    notify.glow       = list_has(nf_types:get(), IDX_GLOW)
    notify.style      = current_style()
    notify.icon_glyph = icon_map[nf_icon:get()] or ""

    if not welcome_shown and globals.realtime >= load_time + LOAD_DELAY then
        welcome_shown = true
        if nf_enabled:get() then
            local text, clr = format_welcome()
            notify.push(text, clr, nf_time:get())
        end
    end

    notify.tick_scheduled()
    notify.handle()
end)

-- ============================================================
-- Tab B (group 2): Fake AA debug overlay (ported from fakeaa test).
-- Reads the angles the anti-aim actually sends (createmove) and draws
-- them as a draggable HUD. Drag with LEFT CLICK while the menu is open.
-- ============================================================
local aa_grp     = ui.create('B', 'Anti-aim debug')
local aa_enabled = aa_grp:switch('Enabled', false)

-- small HUD font (falls back to default preset if it can't load)
local aa_hud_font = 1
pcall(function() aa_hud_font = render.load_font('Verdana', 11, 'a') end)

-- latest angles the anti-aim actually sent (captured in createmove)
local aa_sent = { yaw = 0, pitch = 0, roll = 0 }

events.createmove:set(function(cmd)
    pcall(function() aa_sent.pitch = cmd.view_angles.x end)
    pcall(function() aa_sent.yaw   = cmd.view_angles.y end)
    pcall(function() aa_sent.roll  = cmd.view_angles.z end)
end)

-- draggable position (right edge x, top y) - persisted in db
local aa_pos = { x = nil, y = nil }
pcall(function()
    aa_pos.x = db.fakeaa_dbg_x
    aa_pos.y = db.fakeaa_dbg_y
end)

local aa_drag     = { active = false, off = vector(0, 0) }
local aa_hovering = false   -- updated in render, read by mouse_input

-- block the menu from reacting to the click while we grab the text
events.mouse_input:set(function()
    if not aa_enabled:get() then return end
    local alpha = 0
    pcall(function() alpha = ui.get_alpha() or 0 end)
    if alpha > 0 and (aa_hovering or aa_drag.active) then
        return false
    end
end)

events.render:set(function()
    if not aa_enabled:get() then return end

    -- only while alive: hide when dead / spectating / in the main menu.
    local lp = entity.get_local_player()
    if not lp then return end
    local alive = false
    pcall(function() alive = lp:is_alive() end)
    if not alive then return end

    local eye_y, choked
    pcall(function() eye_y = lp.m_angEyeAngles.y end)
    pcall(function() choked = globals.choked_commands end)

    local function f(v) return v and string.format('%.1f', v) or 'nil' end

    -- number on the left, label text on the right
    local rows = {
        { f(aa_sent.yaw),   'sent yaw' },
        { f(aa_sent.pitch), 'sent pitch' },
        { f(aa_sent.roll),  'sent roll' },
        { f(eye_y),         'eye yaw' },
    }
    if choked ~= nil and choked > 1 then
        rows[#rows + 1] = { tostring(choked), 'choked cmds' }
    end

    -- pre-measure each line and find the widest
    local line_h = 12
    local maxw   = 0
    local items  = {}
    for i, r in ipairs(rows) do
        local txt = r[1] .. '   ' .. r[2]
        local tw = 0
        pcall(function() tw = render.measure_text(aa_hud_font, nil, txt).x end)
        items[i] = { txt = txt, w = tw }
        if tw > maxw then maxw = tw end
    end
    local block_h = #rows * line_h

    local screen = render.screen_size()
    -- first-run default: right edge, vertically centered
    if aa_pos.x == nil then aa_pos.x = screen.x - 4 end
    if aa_pos.y == nil then aa_pos.y = screen.y / 2 - block_h / 2 end

    -- ---- drag handling (only while menu is open) ----
    local alpha = 0
    pcall(function() alpha = ui.get_alpha() or 0 end)

    aa_hovering = false
    if alpha > 0 then
        local mouse
        pcall(function() mouse = ui.get_mouse_position() end)
        local btn = false
        pcall(function() btn = common.is_button_down(1) end)

        if mouse then
            local left = aa_pos.x - maxw
            if mouse.x >= left and mouse.x <= aa_pos.x
            and mouse.y >= aa_pos.y and mouse.y <= aa_pos.y + block_h then
                aa_hovering = true
            end

            if aa_hovering and btn and not aa_drag.active then
                aa_drag.active = true
                aa_drag.off = vector(aa_pos.x - mouse.x, aa_pos.y - mouse.y)
            end
            if not btn then aa_drag.active = false end

            if aa_drag.active then
                -- vertical movement only (X stays locked to the edge)
                aa_pos.y = math.clamp(mouse.y + aa_drag.off.y, 0, screen.y - block_h)
                db.fakeaa_dbg_y = aa_pos.y
            end
        end
    else
        aa_drag.active = false
    end

    -- ---- draw ----
    local y = aa_pos.y
    for _, it in ipairs(items) do
        render.text(aa_hud_font, vector(aa_pos.x - it.w, y),
            color(255, 255, 255, 255), nil, it.txt)
        y = y + line_h
    end

    -- grab outline when the menu is open and you're on the text
    if alpha > 0 and (aa_hovering or aa_drag.active) then
        pcall(function()
            render.rect_outline(
                vector(aa_pos.x - maxw - 4, aa_pos.y - 4),
                vector(aa_pos.x + 4, aa_pos.y + block_h + 4),
                color(255, 255, 255, 120), 1, 4)
        end)
    end
end)

-- ============================================================
-- Tab C: SSG-08 config manager (ported from 67_6803707.lua).
-- Saves/loads named snapshots of the SSG-08 Ragebot settings.
-- ============================================================
local SCOUT_DB_KEY      = 'scout_ssg08_configs'
local SCOUT_PLACEHOLDER = '— no configs —'

local scout = {
    base64    = require('neverlose/base64'),
    clipboard = require('neverlose/clipboard'),

    -- SSG-08 only: the three Ragebot subgroups for this weapon, plus the
    -- (global) Accuracy toggles stored with each config. Order is fixed
    -- (configs key by index) -- never reorder.
    elements = {
        ui.find("Aimbot", "Ragebot", "Selection", "SSG-08"),
        ui.find("Aimbot", "Ragebot", "Safety", "SSG-08"),
        ui.find("Aimbot", "Ragebot", "Accuracy", "SSG-08"),
        ui.find("Aimbot", "Ragebot", "Accuracy", "Auto scope"),
        ui.find("Aimbot", "Ragebot", "Accuracy", "Auto stop"),
    },

    saved = {},   -- name -> encoded config string
    order = {},   -- ordered names (drives the list)
}

function scout:capture()
    local data = {}
    for j = 1, #self.elements do
        local el = self.elements[j]
        if el and el.export then data[j] = el:export() end
    end
    return self.base64.encode(json.stringify(data))
end

function scout:apply(encoded)
    local ok, data = pcall(function()
        return json.parse(self.base64.decode(encoded))
    end)
    if not ok or type(data) ~= 'table' then
        print_error('This config is broken!')
        return false
    end
    for j = 1, #self.elements do
        local el = self.elements[j]
        if el and el.import and data[j] then el:import(data[j]) end
    end
    return true
end

function scout:refresh_list()
    self.order = {}
    for name in pairs(self.saved) do self.order[#self.order + 1] = name end
    table.sort(self.order)

    local items = self.order
    if #items == 0 then items = { SCOUT_PLACEHOLDER } end
    self.list:update(items)
end

function scout:persist()
    pcall(function() db[SCOUT_DB_KEY] = self.saved end)
end

function scout:load_db()
    local ok, stored = pcall(function() return db[SCOUT_DB_KEY] end)
    if ok and type(stored) == 'table' then
        for name, enc in pairs(stored) do
            if type(name) == 'string' and type(enc) == 'string' then
                self.saved[name] = enc
            end
        end
    end
end

function scout:selected()
    local v = self.list:get()
    local name
    if type(v) == 'number' then
        name = self.order[v]
    elseif type(v) == 'table' then
        local first = v[1]
        name = (type(first) == 'number') and self.order[first] or first
    else
        name = v
    end
    if not name or name == SCOUT_PLACEHOLDER or not self.saved[name] then
        return nil
    end
    return name
end

function scout:add_config()
    local name = self.name_input:get()
    name = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then
        print_error('Type a config name first!')
        return
    end
    self.saved[name] = self:capture()
    self:persist()
    self:refresh_list()
    print_dev('Saved config: ' .. name)
end

function scout:load_config()
    local name = self:selected()
    if not name then print_error('No config selected!') return end
    if self:apply(self.saved[name]) then
        print_dev('Loaded config: ' .. name)
        self._busy = true
        pcall(function() self.list:set({}) end)
        self._busy = false
        self._prev = {}
    end
end

function scout:update_config()
    local name = self:selected()
    if not name then print_error('No config selected!') return end
    self.saved[name] = self:capture()
    self:persist()
    print_dev('Updated config: ' .. name)
end

function scout:delete_config()
    local name = self:selected()
    if not name then print_error('No config selected!') return end
    self.saved[name] = nil
    self:persist()
    self:refresh_list()
    print_dev('Deleted config: ' .. name)
end

function scout:export_config()
    local name = self:selected()
    if not name then print_error('No config selected!') return end
    pcall(function() self.clipboard.set(self.saved[name]) end)
    print_dev('Copied config to clipboard: ' .. name)
end

function scout:import_config()
    local enc = ''
    pcall(function() enc = self.clipboard.get() end)
    enc = tostring(enc or ''):gsub('%s+', '')
    if enc == '' then print_error('Clipboard is empty!') return end

    local ok, data = pcall(function()
        return json.parse(self.base64.decode(enc))
    end)
    if not ok or type(data) ~= 'table' then
        print_error('Clipboard has no valid config!')
        return
    end

    local name = tostring(self.name_input:get() or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then
        name = 'imported'
        local base, n = name, 1
        while self.saved[name] do n = n + 1; name = base .. ' ' .. n end
    end

    self.saved[name] = enc
    self:persist()
    self:refresh_list()
    print_dev('Imported config: ' .. name)
end

function scout:create_menu()
    local TAB = 'C'  -- third tab in this script

    -- Left column: saved configs + actions on the selected one.
    local left = ui.create(TAB, 'scout configs', 1)
    self.list = left:listable('', SCOUT_PLACEHOLDER)
    self._prev = {}
    self._busy = false
    self.list:set_callback(function()
        if self._busy then return end
        local sel = self.list:get()
        if type(sel) ~= 'table' then self._prev = sel; return end
        if #sel > 1 then
            local prevset = {}
            for _, i in ipairs(self._prev or {}) do prevset[i] = true end
            local keep
            for _, i in ipairs(sel) do
                if not prevset[i] then keep = i; break end
            end
            keep = keep or sel[#sel]
            self._busy = true
            self.list:set({ keep })
            self._busy = false
            self._prev = { keep }
        else
            self._prev = sel
        end
    end)
    left:button('Load selected',      function() return self:load_config() end)
    left:button('Overwrite selected', function() return self:update_config() end)
    left:button('Delete selected',    function() return self:delete_config() end)

    -- Right column: name + create/save a config.
    local right = ui.create(TAB, ' ', 2)
    self.name_input = right:input('Config name')
    right:button('Add / Save current', function() return self:add_config() end)

    -- Little share box: export selected / import from clipboard.
    local share = ui.create(TAB, 'Share', 2)
    share:button('Export', function() return self:export_config() end)
    share:button('Import', function() return self:import_config() end)
end

scout:load_db()
scout:create_menu()
scout:refresh_list()

events.shutdown:set(function() scout:persist() end)
