--- GUI ---
conf = {}

function RunForm(subtitles, selected_lines, active_line)
    xres, yres, ar, artype = aegisub.video_size()
    
	if xres == nil then
		aegisub.log('Please, open the video first\n')
		return
	end
	
    aegisub.progress.task('Collecting defined styles.')
    styles = {}
    styles_ord = {}
    
    for i = 1, #subtitles do
        aegisub.progress.set(i * 100 / #subtitles)
        
        if subtitles[i].class == 'style' then
            styles[subtitles[i].name] = {}
            styles[subtitles[i].name].index = i
            styles[subtitles[i].name].used = false
            table.insert(styles_ord, subtitles[i].name)
        elseif subtitles[i].class == 'dialogue' then
            if styles[subtitles[i].style] then
                styles[subtitles[i].style].used = true
            else
                aegisub.log('Style ' .. subtitles[i].style .. ' not found\n')
            end
        end
    end
    
	hasUnusedStyle = false
	for i = #styles_ord, 1, -1 do
		name = styles_ord[i]
		if not styles[name].used then
			hasUnusedStyle = true
			break
		end
	end
	
	if hasUnusedStyle then
		button, _ = aegisub.dialog.display({{class='label', x = 3, y = 0, width = 3, label='Remove unused style?'}})
    end
	
    if button then
        aegisub.progress.task('Removing not used styles.')
        for i = #styles_ord, 1, -1 do
            name = styles_ord[i]
            if not styles[name].used then
                subtitles.delete(styles[name].index)
                aegisub.log('Style ' .. name .. ' removed\n')
                table.remove(styles_ord, i)
                
                for j = i, #styles_ord do
                    styles[styles_ord[j]].index = styles[styles_ord[j]].index - 1
                end
            end
        end
    end
    
    form = {
        {class='checkbox', x = 0, y = 0, height = 1, width = 1, name='respect_styles_margins', label='Respect Styles Margin? (This will overwrite Max Line Width)', value=false},
        
        {class='label', x = 0, y = 1, height = 1, width = 1, label='Max Lines'},
        {class='intedit', x = 0, y = 2, height = 1, width = 1, name='max_lines', value=2},
        
        {class='label', x = 0, y = 3, height = 1, width = 1, label='Max Line Width'},
        {class='intedit', x = 0, y = 4, height = 1, width = 1, name='max_line_width', value=xres, min=0, max=xres-(95*2)},
        
        {class='label', x = 0, y = 5, height = 1, width = 1, label='Mode: '},
        {class='dropdown', x = 0, y = 6, height = 1, width = 1, name='breakline_mode', items={'0: Top is bigger', '1: Bottom is bigger'}, value='0: Top is bigger'},
        
        {class='checkbox', x = 0, y = 7, height = 1, width = 1, name='compesate_mode', label='Compesate?', value=true},
        
        {class='checkbox', x = 0, y = 8, height = 1, width = 1, name='replace_breaklines', label='Replace Breaklines?', value=true},
        
        {class='label', x = 0, y = 10, height = 1, width = 1, label='Select the styles it should be applied'}
    }
    
    last_y = form[#form].y
    for i = 1, #styles_ord do
        sname = styles_ord[i]
        checked = true
        
        if sname:lower():find('type') then
            checked = false
        end
        
        table.insert(form, {class='checkbox', x = 0, y = last_y+1, height = 1, width = 1, name=sname..'_checkbox', label=sname, value=checked})
        last_y = last_y+1
    end
    
    button, conf = aegisub.dialog.display(form)
    
    if not button then
        return
    end
    
    aegisub.progress.task("Executing script.")
    for i = 1, #subtitles do
        aegisub.progress.set(i * 100 / #subtitles)
        
        line = subtitles[i]
        
        if line.class == "dialogue" and not line.comment then
            if styles[line.style] and conf[line.style .. '_checkbox'] then
                style = subtitles[styles[line.style].index]
                text = line.text
                
                if style.class == "style" then
                    if conf['replace_breaklines'] then
                        text = text:gsub(' \\N', ' '):gsub('\\N ', ' '):gsub('\\N', ' ')
                    end
                    
                    if not text:find('\\N') and style then
                        tokens = tokenize(text, style)
                        lines = split(tokens, xres, style)
                        
                        if #lines > 0 then
                            new_text = table_join(lines, (function (l) return table_join(l, (function (t) return t.text end),'') end), '\\N')
                            line.text = new_text
                            subtitles[i] = line
                        end
                    end
                else
                    aegisub.log('Style ' .. line.style .. ' not found\n')
                end
            end
        end
    end
end
--- END ---

function createToken(text, istag)
    t = {}
    t.text = text
    t.width = 0
    t.tag = istag
    return t
end

function tokenize(text, style)
    tokens = {}
    is_tag = false
    last_char = ''
    current_token = createToken('', false)
    table.insert(tokens, current_token)
    
    for i = 1, string.len(text) do
        current_char = string.sub(text, i, i)
        
        if is_tag then
            current_token.text = current_token.text .. current_char
            if current_char == '}' then
                is_tag = false
                current_token = createToken('', false)
                table.insert(tokens, current_token)
            end
        elseif not is_tag and current_char == '{' then
            if current_token.text ~= '' then
                current_token = createToken('', true)
                table.insert(tokens, current_token)
            end
            current_token.tag = true
            current_token.text = current_token.text .. current_char
            is_tag = true
        elseif not is_tag then
            if current_char == ' ' then
                if last_char == ' ' then
                    current_token.text = current_token.text .. current_char
                else
                    if current_token.text ~= '' then
                        current_token = createToken('', false)
                        table.insert(tokens, current_token)
                    end
                    current_token.text = current_token.text .. current_char
                end
            else
                if last_char == ' ' then
                    current_token = createToken('', false)
                    table.insert(tokens, current_token)
                end
                
                current_token.text = current_token.text .. current_char
            end
        end
        
        last_char = current_char
    end
    
    for i,token in ipairs(tokens) do
        if not token.tag then
            width, height, descent, ext_lead = aegisub.text_extents(style, token.text)
            token.width = width
        end
    end
    
    return tokens
end

function tokens_width_sum(tokens, start)
    sum = 0
    for i = start, #tokens do
        sum = sum + tokens[i].width
    end
    return sum
end

function table_join(t, func, join_string)
    if #t == 0 then
        return ''
    end
    
    ret = ''
    
    for i = 1, #t-1 do
        ret = ret .. func(t[i]) .. join_string
    end
    
    return ret .. func(t[#t])
end

function split(tokens, xres, style)
    max_lines = conf['max_lines']
    max_line_width = conf['max_line_width']
    respect_styles_margins = conf['respect_styles_margins']
    breakline_mode = conf['breakline_mode']
    -- 0: top is bigger
    -- 1: bottom is bigger
    
    compesate_mode = conf['compesate_mode']
    consider_punctuation = true
    punctuation = '[%.,%?!…]'
    
    if respect_styles_margins then
        max_line_width = xres - style.margin_l - style.margin_r
    end
    
    total_width = tokens_width_sum(tokens, 1)
    
    if total_width <= max_line_width then
        return {tokens}
    end
    
    if max_lines > 0 then
        if total_width/max_line_width > max_lines then
            aegisub.log('Line have more than max_lines.\n')
			table.insert(tokens, createToken('{max_line}', true))
            return {tokens}
        end
    end
    
    number_lines = total_width/max_line_width
    lines = {}
    
    for i = 1, number_lines+1, 1 do
        lines[i] = {}
    end
    
    current_line = 1
    current_line_width = 0
    
    for i,t in ipairs(tokens) do
        table.insert(lines[#lines], t)
        
        for j = #lines-1, 1, -1 do
            while #lines[j+1] > 0 and tokens_width_sum(lines[j+1], 1) > tokens_width_sum(lines[j], 1) do
                table.insert(lines[j], lines[j+1][1])
                table.remove(lines[j+1], 1)
            end
        end
    end
    
    if breakline_mode == 1 then
        for i = 1, #lines-1 do
            while #lines[i] > 0 and tokens_width_sum(lines[i], 1) > tokens_width_sum(lines[i+1], 1) do
                table.insert(lines[i+1], 1, lines[i][#lines[i]])
                table.remove(lines[i], #lines[i])
            end
        end
    end
    
    if compesate_mode then
        for i = 1, #lines-1 do
            last = lines[i][#lines[i]]
            next_start = lines[i+1][1]
            
            line_width = tokens_width_sum(lines[i], 1)
            nextline_width = tokens_width_sum(lines[i+1], 1)
            
            if line_width > nextline_width+last.width then
                table.insert(lines[i+1], 1, last)
                table.remove(lines[i], #lines[i])
            elseif line_width+next_start.width < nextline_width then
                table.insert(lines[i], next_start)
                table.remove(lines[i+1], 1)
            end
        end
    end
    
    return lines
end

aegisub.register_macro(
    'Automatic Break Line 2', 
    'Automatic insert breaklines in script',
    RunForm
)
