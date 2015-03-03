include("utils.lua")
re = require 'aegisub.re'

script_name = "Pos to Margin"
script_description = "Transform pos tag to a Margin L/R Vertical settings"
script_author = "xdead"
script_version = "3.0"

function get_anchor_point(align, width, height)
    
    aligns = {[1] = (function () return 0, 0 end),
              [2] = (function () return width/2, 0  end),
              [3] = (function () return width, 0 end),
              [4] = (function () return 0, height/2 end),
              [5] = (function () return width/2, height/2 end),
              [6] = (function () return width, height/2 end),
              [7] = (function () return 0, height end),
              [8] = (function () return width/2, height end),
              [9] = (function () return width, height end)}
    
    return aligns[align]()
end

function get_new_align(align, xpos, ypos, xres, yres)
    text_centred = false
    text_left = false
    text_right = false
    
    if align == 2 or align == 5 or align == 8 then
        text_centred = true
    end
    
    if align == 1 or align == 4 or align == 7 then
        text_left = true
    end
    
    if align == 3 or align == 6 or align == 9 then
        text_right = true
    end
    
    align_map = {{7, 8, 9},
                 {4, 5, 6},
                 {1, 2, 3}}
    
    possible = {{true, true, true},
                {false, false, false},
                {true, true, true}}
    
    if ypos < yres/2 then
        possible[3][1] = false
        possible[3][2] = false
        possible[3][3] = false
    else
        possible[1][1] = false
        possible[1][2] = false
        possible[1][3] = false
    end
    
    if not text_centred then
        possible[1][2] = false
        possible[2][2] = false
        possible[3][2] = false
        
        if text_left then
            possible[1][3] = false
            possible[2][3] = false
            possible[3][3] = false
        end
        
        if text_right then
            possible[1][1] = false
            possible[2][1] = false
            possible[3][1] = false
        end
    else
        possible[1][1] = false
        possible[1][3] = false
        possible[2][1] = false
        possible[2][3] = false
        possible[3][1] = false
        possible[3][3] = false
    end
    
    new_align = 0
    
    for i = 1, 3 do
        for j = 1, 3 do
            if possible[i][j] then
                new_align = align_map[i][j]
            end
        end
    end
    
    return new_align
end

function pos_to_margin(style, xpos, ypos, width, height, xres, yres)
    new_align = get_new_align(style.align, xpos, ypos, xres, yres)
    --aegisub.log('New align: ' .. new_align .. '\n')
    
    if new_align == 4 or new_align == 5 or new_align == 6 then
        aegisub.log('Not implemented\n')
        return nil
    end
    
    anchor_x, anchor_y = get_anchor_point(style.align, width, height)
    new_anchor_x, new_anchor_y = get_anchor_point(new_align, width, height)
    
    anchor_diff_x = anchor_x - new_anchor_x
    anchor_diff_y = anchor_y - new_anchor_y
    
    --aegisub.log('Anchor X: '.. anchor_x ..' Y: '.. anchor_y ..'\n')
    --aegisub.log('New Anchor X: '.. new_anchor_x ..' Y: '.. new_anchor_y ..'\n')
    --aegisub.log('Diff Anchor X: '.. anchor_diff_x ..' Y: '.. anchor_diff_y ..'\n')
    
    xpos = xpos + anchor_diff_x
    ypos = ypos + anchor_diff_y
    
    --aegisub.log('RES X: '.. xres ..' Y: '.. yres ..'\n')
    --aegisub.log('New pos X: '.. xpos ..' Y: '.. ypos ..'\n')
    
    convert = {[1] = (function () return xpos, 0, yres-ypos, 0 end),
               [2] = (function () 
                        if xpos > xres/2 then
                            return (xpos*2)-xres, 0, yres-ypos, 0
                        else
                            return 0, xres-(xpos*2), yres-ypos, 0
                        end
                      end),
               [3] = (function () return 0, xres-xpos, yres-ypos, 0 end),
               
               [7] = (function () return xpos, 0, ypos, 0 end),
               [8] = (function () 
                        if xpos > xres/2 then
                            return (xpos*2)-xres, 0, ypos, 0
                        else
                            return 0, xres-(xpos*2), ypos, 0
                        end
                      end),
               [9] = (function () return 0, xres-xpos, ypos, 0 end)}
    
    margin_l, margin_r, margin_t, margin_b = convert[new_align]()
    return margin_l, margin_r, margin_t, margin_b, new_align
end

function Main(subtitles, selected_lines, active_line)
    local styles_name = {}
    
    aegisub.progress.task("Collecting defined styles.")
    for i = 1, #subtitles do
        aegisub.progress.set(i * 100 / #subtitles)
        if subtitles[i].class == "style" then
            styles_name[subtitles[i].name] = i
        end
    end
    
    xres, yres, ar, artype = aegisub.video_size()
    
    if xres == nil then
		aegisub.log('Please, open the video first\n')
		return
	end
    
    for k = 1, #selected_lines do
        line = subtitles[selected_lines[k]]
        if line.class == "dialogue" and string.find(line.text, "\\pos") then
            xpos = nil
            ypos = nil
            
            for x, y in string.gmatch(line.text, "\\pos%((%d*%.?%d*),%s*(%d*%.?%d*)%)") do
                xpos = tonumber(x)
                ypos = tonumber(y)
            end
            
            newtext = string.gsub(line.text, "\\pos%(%d*%.?%d*,%s*%d*%.?%d*%)", "")
            newtext = string.gsub(newtext, "{}", "")
            
            style = subtitles[styles_name[line.style]]
            if style and xpos ~= nil and ypos ~= nil then
                tmp_style = table.copy(style)
                tmp_style.align = 2
                tmp_style.margin_l = 0
                tmp_style.margin_r = 0
                tmp_style.margin_t = 0
                tmp_style.margin_b = 0
                
                lines = re.split(newtext, "\\\\N")
                
                w = 0
                h = 0
                for l = 1, #lines do
                    nw, nh, descent, ext_lead = aegisub.text_extents(tmp_style, lines[l])
                    if nw > w then
                        w = nw
                    end
                    h = h + nh
                end
                
                w = math.floor(w)
                h = math.floor(h)
                
                --aegisub.log('Line W: '.. w ..' H: ' .. h .. '\n')
                --aegisub.log('pos(' .. xpos .. ', ' .. ypos .. ')\n')
                
                margin_l, margin_r, margin_t, margin_b, new_align = pos_to_margin(style, xpos, ypos, w, h, xres, yres)
                
                if margin_l > 0 then
                    line.margin_l = margin_l
                    --aegisub.log('margin_l '.. margin_l ..'\n')
                end
                
                if margin_r > 0 then
                    line.margin_r = margin_r
                    --aegisub.log('margin_r '.. margin_r ..'\n')
                end
                
                if margin_t > 0 then
                    line.margin_t = margin_t
                    --aegisub.log('margin_t '.. margin_t ..'\n')
                end
                
                if margin_b > 0 then
                    line.margin_b = margin_b
                    --aegisub.log('margin_b '.. margin_b ..'\n')
                end
                
                if style.margin_l ~= 0 and margin_l == 0 then
                    line.margin_l = 1
                end
                
                if style.margin_r ~= 0 and margin_r == 0 then
                    line.margin_r = 1
                end
                
                if style.margin_t ~= 0 and margin_t == 0 and margin_b == 0 then
                    line.margin_t = 1
                end
                
                if style.margin_b ~= 0 and margin_b == 0 and margin_t == 0 then
                    line.margin_b = 1
                end
                
                if new_align ~= style.align then
                    line.text = "{\\an" .. new_align .. "}" .. newtext
                else
                    line.text = newtext
                end
                
                subtitles[selected_lines[k]] = line
            end
        end
    end
    
    aegisub.set_undo_point(script_name)
end

aegisub.register_macro(script_name, script_description, Main)