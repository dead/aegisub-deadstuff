script_name = "Pos to Margin"
script_description = "Transform pos tag to a Left/Right/Top Line Margin"
script_author = "xdead"
script_version = "4.0"

re = require "aegisub.re"

function get_anchor_point(align, width, height)
    if align == 1 then
        return 0, 0
    elseif align == 2 then
        return width/2, 0
    elseif align == 3 then
        return width, 0
    elseif align == 4 then
        return 0, height/2
    elseif align == 5 then
        return width/2, height/2
    elseif align == 6 then
        return width, height/2
    elseif align == 7 then
        return 0, height
    elseif align == 8 then
        return width/2, height
    elseif align == 9 then
        return width, height
    end
    
    return 0, 0
end

function get_new_align(align, xpos, ypos, xres, yres)
    if align == 2 or align == 5 or align == 8 then
        if ypos < yres/2 then
            return 8
        else
            return 2
        end
    end
    
    if align == 1 or align == 4 or align == 7 then
        if ypos < yres/2 then
            return 7
        else
            return 1
        end
    end
    
    if align == 3 or align == 6 or align == 9 then
        if ypos < yres/2 then
            return 9
        else
            return 3
        end
    end
    
    return 1
end

function pos_to_margin(style, xpos, ypos, width, height, xres, yres)
    local new_align = get_new_align(style.align, xpos, ypos, xres, yres)
    
    local anchor_x, anchor_y = get_anchor_point(style.align, width, height)
    local new_anchor_x, new_anchor_y = get_anchor_point(new_align, width, height)
    
    local anchor_diff_x = anchor_x - new_anchor_x
    local anchor_diff_y = anchor_y - new_anchor_y
    
    local xpos = xpos + anchor_diff_x
    local ypos = ypos + anchor_diff_y
    
    local margin_l = 1
    local margin_r = 1
    local margin_t = ypos
    
    if new_align == 1 or new_align == 2 or new_align == 3 then
        margin_t = yres-ypos
    end
    
    if new_align == 1 or new_align == 7 then
        margin_l = xpos
    end
    
    if new_align == 3 or new_align == 9 then
        margin_r = xres-xpos
    end
    
    if new_align == 2 or new_align == 8 then
        if xpos > xres/2 then
            margin_l = (xpos*2)-xres
        else
            margin_r = xres-(xpos*2)
        end
    end
    
    return margin_l, margin_r, margin_t, new_align
end

function main(subtitles, selected_lines, active_line)
    local styles = {}
    
    for i = 1, #subtitles do
        if subtitles[i].class == "style" then
            styles[subtitles[i].name] = i
        end
    end
    
    local xres, yres, ar, artype = aegisub.video_size()
    
    if xres == nil then
		aegisub.log("Please, open the video first.\n")
		return
	end
    
    for sidx, lidx in ipairs(selected_lines) do
        local line = subtitles[lidx]
        
        if line.class == "dialogue" and line.text:find("\\pos") then
            local xpos = nil
            local ypos = nil
            
            for x, y in line.text:gmatch("\\pos%((%d*%.?%d*),%s*(%d*%.?%d*)%)") do
                xpos = tonumber(x)
                ypos = tonumber(y)
            end
            
            local newtext = line.text:gsub("\\pos%(%d*%.?%d*,%s*%d*%.?%d*%)", ""):gsub("{}", "")
            
            local style = subtitles[styles[line.style]]
            if style and xpos ~= nil and ypos ~= nil then
                lines = re.split(newtext, "\\\\N")
                
                local w = 0
                local h = 0
                for l = 1, #lines do
                    nw, nh, descent, ext_lead = aegisub.text_extents(style, lines[l]:gsub("{[^}]*}", ""))
                    if nw > w then
                        w = nw
                    end
                    h = h + nh
                end
                
                w = math.floor(w)
                h = math.floor(h)
                
                line.margin_l, line.margin_r, line.margin_t, new_align = pos_to_margin(style, xpos, ypos, w, h, xres, yres)
                
                if new_align ~= style.align then
                    line.text = "{\\an" .. new_align .. "}" .. newtext
                else
                    line.text = newtext
                end
                
                subtitles[lidx] = line
            end
        end
    end
    
    aegisub.set_undo_point(script_name)
end

aegisub.register_macro(
    script_name,
    script_description,
    main
)
