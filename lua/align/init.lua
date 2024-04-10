---@class Marks
---@field sr number
---@field sc number
---@field er number
---@field ec number

---@class AlignOptions
---@field reverse boolean?
---@field preview boolean?
---@field regex boolean?
---@field marks Marks?
---@field callback (fun(): any)?

---@class AlignToCharOptions: AlignOptions
---@field length integer?

---@class AlignWrapperOptions: AlignOptions
---@field pattern string?

---@class AlignInnerOptions: AlignOptions
---@field pattern string?


---@param sr integer
---@param sc integer
---@param er integer
---@param ec integer
local function highlight(sr, sc, er, ec)
    local mode = vim.fn.mode()
    local mode_V = mode == 'V'
    local mode_vb = mode == ''

    if sr > ec then
        sr, sc, er, ec = er, ec, sr, sc
    end

    if mode_vb then
        for i = sr, er do
            vim.api.nvim_buf_add_highlight(0, -1, 'Visual', i - 1, sc, ec)
        end
    else
        vim.api.nvim_buf_add_highlight(0, -1, 'Visual', sr, mode_V and 0 or sc, -1)
        for i = sr + 1, er - 1 do
            vim.api.nvim_buf_add_highlight(0, -1, 'Visual', i - 1, 0, -1)
        end
        vim.api.nvim_buf_add_highlight(0, -1, 'Visual', er - 1, 0, mode_V and -1 or ec)
    end
end


---@param marks Marks?
---@return function
local function tmpbuf(marks)
    local real = vim.api.nvim_get_current_buf()
    local ft = vim.bo.filetype
    local real_lines = vim.api.nvim_buf_get_lines(real, 0, -1, false)
    local curpos = vim.api.nvim_win_get_cursor(0)
    local mode = vim.fn.mode()
    local commands = {
        ['v'] = 'normal! v',
        ['V'] = 'normal! V',
        [''] = 'normal! ',
    }
    local command = function() vim.cmd(commands[mode]) end
    local sr, sc, er, ec

    if marks then
        sr, sc, er, ec = marks.sr, marks.sc, marks.er, marks.ec
    else
        _, sr, sc, _ = unpack(vim.fn.getpos('v') or {0, 0, 0, 0})
        _, er, ec, _ = unpack(vim.fn.getcurpos())

        -- if sr > er or (sr == er and sc > ec) then
        --     sr, sc, er, ec = er, ec, sr, sc
        -- end
        vim.fn.setpos(".", { real, sr, sc })
        command()
        vim.fn.setpos(".", { real, er, ec })
    end

    local tmp = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(tmp, 0, -1, false, real_lines)
    vim.api.nvim_set_current_buf(tmp)
    vim.bo.filetype = ft

    if marks then
        vim.api.nvim_buf_set_mark(tmp, '[', sr, sc, {})
        vim.api.nvim_buf_set_mark(tmp, ']', er, ec, {})
    else
        vim.api.nvim_buf_set_mark(tmp, '<', sr, sc, {})
        vim.api.nvim_buf_set_mark(tmp, '>', er, ec, {})
    end
    vim.fn.setpos(".", { tmp, sr, sc })
    command()
    vim.fn.setpos(".", { tmp, er, ec })
    vim.api.nvim_win_set_cursor(0, curpos)
    vim.cmd('normal! zz')

    highlight(sr, sc, er, ec)

    return function()
        vim.api.nvim_set_current_buf(real)
        vim.api.nvim_buf_delete(tmp, { force = true, unload = false })

        if marks then
            vim.api.nvim_buf_set_mark(real, '[', sr, sc, {})
            vim.api.nvim_buf_set_mark(real, ']', er, ec, {})
        else
            vim.api.nvim_buf_set_mark(real, '<', sr, sc, {})
            vim.api.nvim_buf_set_mark(real, '>', er, ec, {})
            vim.fn.setpos(".", { real, sr, sc })
            command()
            vim.fn.setpos(".", { real, er, ec })
        end
    end
end

---By @Chromosore
---Inserts a string `src` into `dst` at `pos`
---@param dst string
---@param pos integer
---@param src string
---@return string
local function str_insert(dst, pos, src)
    return dst:sub(1, pos-1) .. src .. dst:sub(pos)
end

---@param pattern string
---@param opts AlignOptions?
local function align(pattern, opts)
    opts = opts or {}
    local sr, sc, er, ec
    if opts.marks then
        sr, sc, er, ec = opts.marks.sr, opts.marks.sc, opts.marks.er, opts.marks.ec
    else
        _, sr, sc, _ = unpack(vim.fn.getpos('v') or {0, 0, 0, 0})
        _, er, ec, _ = unpack(vim.fn.getcurpos())
        if sr > er or (sr == er and sc > ec) then
            sr, sc, er, ec = er, ec, sr, sc
        end
    end

    local mode = vim.fn.mode()
    local mode_v = mode == 'v'
    local mode_vb = mode == ''

    if opts.preview and opts.marks then
        highlight(sr, sc, er, ec)
    end

    if sr == ec then
        return
    end

    if not pattern or pattern == '' then
        return
    end
    opts.reverse = not not opts.reverse
    opts.preview = not not opts.preview

    if er < sr then
        er, sr = sr, er
    end

    local target = 0
    local positions = {}

    local lines = vim.api.nvim_buf_get_lines(0, sr - 1, er, true)

    if not lines then
        return
    end

    local loc = math.min(sc, ec)
    local hic = math.max(sc, ec)

    if opts.regex then
        local noerr, re = pcall(vim.regex, pattern)
        if not noerr or re == nil then
            if not opts.preview then
                error('Failed to compile "' .. pattern .. '" as a Vim regex.')
            end
            return
        end

        for i = sr, er do
            local line = lines[i - sr + 1]
            if not line then
                break
            end

            local s, e
            if (mode_vb or (i == sr and mode_v)) then
                local offset = (mode_vb and loc or sc) - 1
                local match
                noerr, match = pcall(function() return { re:match_line(0, i - 1, offset) } --[[@as (integer?)[] ]] end)
                if not noerr then
                    goto continue
                end
                s, e = unpack(match)
                if s ~= nil and e ~= nil then
                    s = s + offset
                    e = e + offset
                end
            else
                s, e = re:match_str(line) --[[@as integer?, integer?]]
            end

            if s == nil or e == nil then
                goto continue
            end

            s = s + 1
            if mode_v and ((i == er and ec < e) or (i == sr and sc > s)) then
                goto continue
            end

            if mode_vb and (hic < e or loc > s) then
                goto continue
            end

            local visual_start = vim.fn.strdisplaywidth(line:sub(0, s))
            table.insert(positions, { i, visual_start })
            if opts.reverse then
                for j = s - 1, 1, -1 do
                    if line:sub(j, j) == " " then
                        s = j
                        visual_start = vim.fn.strdisplaywidth(line:sub(0, s))
                    else
                        break
                    end
                end
            end
            target = math.max(target, visual_start --[[@as integer]])

            ::continue::
        end
    else
        for i = sr, er do
            local line = lines[i - sr + 1]
            if not line then
                break
            end

            local start = (mode_vb or (i == sr and mode_v)) and line:find(pattern, mode_vb and loc or sc, true) or line:find(pattern, nil, true)
            local visual_start = vim.fn.strdisplaywidth(line:sub(0, start))

            if start then
                if i == er and ec < visual_start + #pattern - 1 and mode_v then
                    goto continue
                end
                if mode_vb and (hic < visual_start + #pattern -1 or loc > visual_start) then
                    goto continue
                end
                table.insert(positions, { i, visual_start })
                if opts.reverse then
                    for j = start - 1, 1, -1 do
                        if line:sub(j, j) == " " then
                            start = j
                            visual_start = vim.fn.strdisplaywidth(line:sub(0, start))
                        else
                            break
                        end
                    end
                end
                target = math.max(target, visual_start)
            end
            ::continue::
        end
    end

    if not opts.preview then
        vim.api.nvim_input('<Esc>')
    end

    if target == 0 or #positions == 0 then
        return
    end

    for _, pos in ipairs(positions) do
        local r, c = unpack(pos)
        local curr = lines[r - sr + 1]
        if c <= target then
            vim.api.nvim_buf_set_lines(0, r - 1, r, true, {str_insert(curr, c, (' '):rep(target - c + (opts.reverse and 1 or 0)))})
        else
            vim.api.nvim_buf_set_lines(0, r - 1, r, true, {string.sub(curr, 1, target) .. string.sub(curr, c)})
        end
    end

    if opts.preview and opts.marks then
        highlight(sr, sc, er, ec)
    end

    if not opts.preview and opts.callback then
        vim.schedule(opts.callback)
    end

    vim.print(' ')

    return 1
end

---@param str string?
---@return integer? # Error number
---@return string? # New string
local function input(str)
    str = str or ''
    local ch = vim.fn.getcharstr()
    if ch == vim.api.nvim_replace_termcodes('<Esc>', true, false, true) then
        vim.print(' ')
        return 0, nil
    end
    if ch == vim.api.nvim_replace_termcodes('<CR>', true, false, true) then
        return 1, nil
    end

    if ch == vim.api.nvim_replace_termcodes('<BS>', true, false, true) then
        return 2, str:sub(1, #str - 1)
    else
        return nil, str .. ch
    end
end

---@param pattern string
---@param opts AlignOptions?
local function align_wrapper(pattern, opts)
    opts = opts or {}
    if opts.marks and opts.marks.sr then
        local sr, sc, er, ec = opts.marks.sr, opts.marks.sc, opts.marks.er, opts.marks.ec
        if sr == er then
            return
        end
        highlight(sr, sc, er, ec)
    end
    opts.preview = false
    align(pattern, opts)
end

---@param opts AlignToCharOptions?
local function align_to_char(opts)
    opts = opts or {}
    if opts.marks and opts.marks.sr then
        local sr, sc, er, ec = opts.marks.sr, opts.marks.sc, opts.marks.er, opts.marks.ec
        if sr == er then
            return
        end
        highlight(sr, sc, er, ec)
    end
    opts.length = math.max(opts.length or 1, 1)
    opts.preview = not not opts.preview and opts.length > 1
    local prompt = 'Enter ' .. (opts.length > 1 and opts.length .. ' characters: ' or 'a character: ')
    vim.print(prompt)
    local pattern = ''
    local cleanup = opts.preview and tmpbuf(opts.marks) or nil
    vim.cmd.redraw()
    while #pattern < opts.length do
        vim.print(prompt .. pattern)
        local err, new_str = input(pattern)
        if err == 0 then
            if cleanup then
                cleanup()
                cleanup = function() end
            end
            vim.api.nvim_input('<Esc>')
            return
        end
        if err == 1 then
            break
        end
        pattern = new_str --[[@as string]]

        if opts.preview then
            if cleanup then
                cleanup()
            end
            cleanup = tmpbuf(opts.marks)
            align(pattern, opts)
        end

        vim.cmd.redraw()
    end
    if cleanup then
        cleanup()
    end
    align_wrapper(pattern, opts)
end

---@param opts AlignOptions?
local function align_to_string(opts)
    opts = opts or {}
    if opts.marks and opts.marks.sr then
        local sr, sc, er, ec = opts.marks.sr, opts.marks.sc, opts.marks.er, opts.marks.ec
        if sr == er then
            return
        end
        highlight(sr, sc, er, ec)
    end
    opts.preview = not not opts.preview
    opts.regex = not not opts.regex
    local prompt = opts.regex and 'Enter pattern: ' or 'Enter string: '
    vim.print(prompt)
    local pattern = ''
    local cleanup = opts.preview and tmpbuf(opts.marks) or nil
    vim.cmd.redraw()
    while true do
        vim.print(prompt .. pattern)
        local err, new_pattern = input(pattern)
        if err == 0 then
            if cleanup then
                cleanup()
                cleanup = function() end
            end
            vim.api.nvim_input('<Esc>')
            vim.print(' ')
            return
        end
        if err == 1 then
            break
        end
        pattern = new_pattern --[[@as string]]

        if opts.preview then
            if cleanup then
                cleanup()
            end
            cleanup = tmpbuf(opts.marks)
            opts.preview = true
            align(pattern, opts)
        end
        vim.cmd.redraw()
    end
    if cleanup then
        cleanup()
    end
    align_wrapper(pattern, opts)
end

---@param fn function
---@param opts (AlignOptions | AlignWrapperOptions | AlignToCharOptions)?
local function operator(fn, opts)
    opts = opts or {}
    local old_func = vim.go.operatorfunc

    _G.op_align = function()
        local sr, sc = unpack(vim.api.nvim_buf_get_mark(0, '['))
        local er, ec = unpack(vim.api.nvim_buf_get_mark(0, ']'))

        if not sr or sr == er then
            vim.go.operatorfunc = old_func
            _G.op_align = nil
            return
        end

        highlight(sr, sc, er, ec)

        opts.marks = {sr = sr, sc = sc, er = er, ec = ec}
        if fn == align_to_char then
            --[[@cast opts AlignToCharOptions]]
            align_to_char(opts)
        elseif fn == align_to_string then
            --[[@cast opts AlignOptions]]
            align_to_string(opts)
        elseif fn == align_wrapper then
            --[[@cast opts AlignWrapperOptions]]
            align_wrapper(opts.pattern, opts)
        else
            error('Unknown function: ' .. fn)
        end
        vim.api.nvim_buf_clear_namespace(0, -1, 0, -1)

        vim.go.operatorfunc = old_func
        _G.op_align = nil
    end
    vim.go.operatorfunc = 'v:lua.op_align'
    vim.api.nvim_feedkeys('g@', 'n', false)
end

return {
    align = align_wrapper,
    align_to_char = align_to_char,
    align_to_string = align_to_string,
    operator = operator,
}
