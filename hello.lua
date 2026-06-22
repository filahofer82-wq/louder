---@diagnostic disable: undefined-global
--[[ ============================================================
     Fake AA (test)  -  Neverlose CS:GO Lua
     ------------------------------------------------------------
     Anti-aim DEBUG overlay. Reads the angles your anti-aim is
     actually sending (from createmove) and prints them.

     Drag-to-move: while the menu is open, hold LEFT CLICK on the
     text and drag it anywhere. Position is saved between games.
============================================================ ]]--

ui.sidebar('Fake AA', 'person')

local grp     = ui.create('Anti-aim debug')
local enabled = grp:switch('Enabled', false)

-- small HUD font (falls back to default preset if it can't load)
local hud_font = 1
pcall(function() hud_font = render.load_font('Verdana', 11, 'a') end)

-- latest angles the anti-aim actually sent (captured in createmove)
local sent = { yaw = 0, pitch = 0, roll = 0 }

events.createmove:set(function(cmd)
    pcall(function() sent.pitch = cmd.view_angles.x end)
    pcall(function() sent.yaw   = cmd.view_angles.y end)
    pcall(function() sent.roll  = cmd.view_angles.z end)
end)

-- ------------------------------------------------------------------
-- draggable position (right edge x, top y) - persisted in db
-- ------------------------------------------------------------------
local pos = { x = nil, y = nil }
pcall(function()
    pos.x = db.fakeaa_dbg_x
    pos.y = db.fakeaa_dbg_y
end)

local drag     = { active = false, off = vector(0, 0) }
local hovering = false   -- updated in render, read by mouse_input

-- block the menu from reacting to the click while we grab the text
events.mouse_input:set(function()
    if not enabled:get() then return end
    local alpha = 0
    pcall(function() alpha = ui.get_alpha() or 0 end)
    if alpha > 0 and (hovering or drag.active) then
        return false
    end
end)

events.render:set(function()
    if not enabled:get() then return end

    local lp = entity.get_local_player()
    local eye_y, choked
    if lp then
        pcall(function() eye_y = lp.m_angEyeAngles.y end)
    end
    pcall(function() choked = globals.choked_commands end)

    local function f(v) return v and string.format('%.1f', v) or 'nil' end

    -- number on the left, label text on the right
    local rows = {
        { f(sent.yaw),   'sent yaw' },
        { f(sent.pitch), 'sent pitch' },
        { f(sent.roll),  'sent roll' },
        { f(eye_y),      'eye yaw' },
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
        pcall(function() tw = render.measure_text(hud_font, nil, txt).x end)
        items[i] = { txt = txt, w = tw }
        if tw > maxw then maxw = tw end
    end
    local block_h = #rows * line_h

    local screen = render.screen_size()
    -- first-run default: right edge, vertically centered
    if pos.x == nil then pos.x = screen.x - 4 end
    if pos.y == nil then pos.y = screen.y / 2 - block_h / 2 end

    -- ---- drag handling (only while menu is open) ----
    local alpha = 0
    pcall(function() alpha = ui.get_alpha() or 0 end)

    hovering = false
    if alpha > 0 then
        local mouse
        pcall(function() mouse = ui.get_mouse_position() end)
        local btn = false
        pcall(function() btn = common.is_button_down(1) end)

        if mouse then
            local left = pos.x - maxw
            if mouse.x >= left and mouse.x <= pos.x
            and mouse.y >= pos.y and mouse.y <= pos.y + block_h then
                hovering = true
            end

            if hovering and btn and not drag.active then
                drag.active = true
                drag.off = vector(pos.x - mouse.x, pos.y - mouse.y)
            end
            if not btn then drag.active = false end

            if drag.active then
                -- vertical movement only (X stays locked to the edge)
                pos.y = math.clamp(mouse.y + drag.off.y, 0, screen.y - block_h)
                db.fakeaa_dbg_y = pos.y
            end
        end
    else
        drag.active = false
    end

    -- ---- draw ----
    local y = pos.y
    for _, it in ipairs(items) do
        render.text(hud_font, vector(pos.x - it.w, y),
            color(255, 255, 255, 255), nil, it.txt)
        y = y + line_h
    end

    -- grab outline when the menu is open and you're on the text
    if alpha > 0 and (hovering or drag.active) then
        pcall(function()
            render.rect_outline(
                vector(pos.x - maxw - 4, pos.y - 4),
                vector(pos.x + 4, pos.y + block_h + 4),
                color(255, 255, 255, 120), 1, 4)
        end)
    end
end)
