include("utils.lua")

script_name = "Automatic Lines Breaks"
script_description = "Automatically inserts hard line breaks."
script_author = "xdead"
script_version = "4.0"

conf = {}
other_punct = "[%.%?!,:;\"-]"

function splitwords(text)
    local words = {}
    local word = ""
    local last_c = ""
    local tag = false
    
    for i = 1, string.len(text) do
        local c = string.sub(text, i, i)
        
        if tag then
            word = word .. c
            if c == "}" then
                tag = false
                table.insert(words, word)
                word = ""
            end
        elseif not tag and c == "{" then
            if word ~= "" then
                table.insert(words, word)
            end
            tag = true
            word = c
        else
            if c == " " then
                if last_c == " " then
                    word = word .. c
                else
                    if word ~= "" then
                        table.insert(words, word)
                    end
                    word = c
                end
            else
                if last_c == " " then
                    table.insert(words, word)
                    word = ""
                end
                
                word = word .. c
            end
        end
        
        last_c = c
    end
    
    if word ~= "" then
        table.insert(words, word)
    end
    
    return words
end

function words_width(style, words)
    if not words then
        return 0
    end
    
    return aegisub.text_extents(style, words_str(words, false))
end

function words_str(words, include_tags)
    if not include_tags then
        return table.concat(words, ""):gsub("{[^}]*}", "")
    end
    
    return table.concat(words, "")
end

function autobreak(style, text)
    local words = splitwords(text)
    local total_width = words_width(style, words)
    
    if total_width <= conf["ideal_lines_width"] then
        return table.concat(words, "")
    end
    
    if total_width/conf["max_lines_width"] > 2 then -- more than two lines
        return table.concat(words, "") .. "{max_line}"
    end
    
    local t_line = {}
    local b_line = {}
    
    for i, word in ipairs(words) do
        table.insert(b_line, word)
        
        while #b_line > 0 and words_width(style, b_line) > words_width(style, t_line) do
            table.insert(t_line, b_line[1])
            table.remove(b_line, 1)
        end
    end
    
    if conf["linebreak_mode"] == "1: Bottom is bigger" then
        while #t_line > 0 and words_width(style, t_line) > words_width(style, b_line) do
            table.insert(b_line, 1, t_line[#t_line])
            table.remove(t_line, #t_line)
        end
    end
    
    if conf["compensation"] then
        local t_width = words_width(style, t_line)
        local b_width = words_width(style, b_line)
        
        local last_top = words_width(style, {t_line[#t_line]})
        local first_bottom = words_width(style, {b_line[1]})
        
        if t_width > b_width+last_top then
            table.insert(b_line, 1, t_line[#t_line])
            table.remove(t_line, #t_line)
        elseif t_width+first_bottom < b_width then
            table.insert(t_line, b_line[1])
            table.remove(b_line, 1)
        end
    end
    
    if conf["consider_punct"] then
        local t_tmp = table.copy(t_line)
        local b_tmp = table.copy(b_line)
        local t_punct = {}
        local b_punct = {}
        
        while #t_tmp > 0 and not words_str(t_punct, false):find(other_punct) do
            table.insert(t_punct, 1, t_tmp[#t_tmp])
            table.remove(t_tmp, #t_tmp)
        end
        
        if t_punct[1]:find(other_punct) then
            if t_punct[1]:find(other_punct) ~= 1 then
                table.remove(t_punct, 1)
            end
        end
        
        while #b_tmp > 0 and not words_str(b_punct, false):find(other_punct) do
            table.insert(b_punct, b_tmp[1])
            table.remove(b_tmp, 1)
        end

        if #t_line ~= #t_punct or #b_punct ~= b_line then
            local t_len = string.len(words_str(t_punct, false))
            local b_len = string.len(words_str(b_punct, false))
            
            if t_len <= 5 or b_len <= 5 then
                if t_len < b_len then
                    while #t_punct > 0 do
                        table.insert(b_line, 1, t_punct[#t_punct])
                        table.remove(t_line, #t_line)
                        table.remove(t_punct, #t_punct)
                    end
                else
                    while #b_punct > 0 do
                        table.insert(t_line, b_punct[1])
                        table.remove(b_line, 1)
                        table.remove(b_punct, 1)
                    end
                end
            end
        end
    end
    
    return words_str(t_line, true) .. "\\N" .. words_str(b_line, true)
end

function main(subtitles, selected_lines, active_line)
    local xres, yres, ar, artype = aegisub.video_size()
    if xres == nil then
		aegisub.log("Please, open the video first.\n")
		return
	end
    
    local styles = {}
    local used_styles = {}
    local styles_ord = {}
    local s1 = 0
    local s2 = 0
    
    for i = 1, #subtitles do
        if subtitles[i].class == "style" then
            styles[subtitles[i].name] = subtitles[i]
            table.insert(styles_ord, subtitles[i].name)
            if s1 == 0 then
                s1 = i
            end
            s2 = i
        end
        
        if subtitles[i].class == "dialogue" then
            if styles[subtitles[i].style] then
                used_styles[subtitles[i].style] = true
            else
                aegisub.log("Style \"" .. subtitles[i].style .. "\" not found.\n")
            end
            
            local ovrStyle = string.match(subtitles[i].text,"^.-%{.-\\r([^}\\]-)%s-[}\\].*$")
            if ovrStyle then
                if styles[ovrStyle] then
                    used_styles[ovrStyle] = true
                else
                    aegisub.log("Style \"" .. ovrStyle .. "\" not found.\n")
                end
            end
        end
    end
    
    local hasUnusedStyles = false
    for sname, _ in pairs(styles) do
        if not used_styles[sname] then
            hasUnusedStyles = true
            break
        end
    end
    
    local removeUnusedStyles = false
    if hasUnusedStyles then
        removeUnusedStyles = aegisub.dialog.display({{class="label", x = 3, y = 0, width = 3, label="Remove unused style?"}})
    end
    
    if removeUnusedStyles then
        for i=s2, s1, -1 do
            style = subtitles[i].name
            if not used_styles[style] then
                --aegisub.log("Deleted style \"" .. style .. "\"\n")
                subtitles.delete(i)
            end
        end
    end
    
    conf["ideal_lines_width"] = math.floor(xres*0.5)
    conf["max_lines_width"] = math.floor(xres*0.8)
    conf["replace_linebreaks"] = true
    conf["linebreak_mode"] = "0: Top is bigger"
    conf["compensation"] = true
    conf["consider_punct"] = true
    
    form = {
        {class="label", x = 0, y = 0, height = 1, width = 1, label="Max Line Width"},
        {class="intedit", x = 0, y = 1, height = 1, width = 1, name="max_lines_width", value=conf["max_lines_width"], min=0, max=xres},
        {class="label", x = 0, y = 2, height = 1, width = 1, label="Ideal Line Width"},
        {class="intedit", x = 0, y = 3, height = 1, width = 1, name="ideal_lines_width", value=conf["ideal_lines_width"], min=0, max=xres},
        {class="label", x = 0, y = 4, height = 1, width = 1, label="Mode: "},
        {class="dropdown", x = 0, y = 5, height = 1, width = 1, name="linebreak_mode", items={"0: Top is bigger", "1: Bottom is bigger"}, value=conf["linebreak_mode"]},
        {class="checkbox", x = 0, y = 6, height = 1, width = 1, name="compensation", label="Compesate?", value=conf["compensation"]},
        {class="checkbox", x = 0, y = 7, height = 1, width = 1, name="replace_linebreaks", label="Replace Line Breaks?", value=conf["replace_linebreaks"]},
        {class="checkbox", x = 0, y = 8, height = 1, width = 1, name="consider_punct", label="Consider punctuation?", value=conf["consider_punct"]},
        {class="label", x = 0, y = 10, height = 1, width = 1, label="Select the styles it should be applied"}
    }
    
    local last_y = form[#form].y
    for _, sname in pairs(styles_ord) do
        if used_styles[sname] then
            local checked = true
            if sname:lower():find("type") then
                checked = false
            end
            
            table.insert(form, {class="checkbox", x = 0, y = last_y+1, height = 1, width = 1, name=sname.."_checkbox", label=sname, value=checked})
            last_y = last_y+1
        end
    end
    
    local button, _conf = aegisub.dialog.display(form)
    if not button then
        return
    end
    
    conf = _conf
    
    for lidx, line in ipairs(subtitles) do
        if line.class == "dialogue" and not line.comment and conf[line.style .. "_checkbox"] then
            local style = styles[line.style]
            local text = line.text
            
            if conf["replace_linebreaks"] then
                text = text:gsub(" \\N", " "):gsub("\\N ", " "):gsub("\\N", " ")
            end
            
            if not text:find("\\N") then
                line.text = autobreak(style, text)
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
