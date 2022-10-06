local real = nil

local function restore()
    if not real then
        return
    end
    local s, e, t = unpack(real)
    real = nil
    if s < 2 then
        return
    end
    vim.api.nvim_buf_set_lines(
        0,
        s - 1,
        e,
        true,
        t
    )
end

-- By @Chromosore
local function str_insert(dst, pos, src)
    return dst:sub(1, pos-1) .. src .. dst:sub(pos)
end

local function escape(str, is_pattern)
    if not is_pattern then
        str = vim.fn.escape(str, '^$()%.[]*+-?')
    end
    if #str > 1 then
        local double_backslashes = {}
        for match in str:gmatch('(\\\\)') do
            table.insert(double_backslashes, str:find(match, (double_backslashes[#double_backslashes] or 0) + 1))
        end
        str = str:gsub('\\', '%%')

        for _, match in ipairs(double_backslashes) do
            str = str:sub(1, match - 2) .. [[\]] .. str:sub(match + 1)
        end
    end
    return str
end

local function align(str, reverse, preview, marks)
    local sr, sc, er, ec
    if marks then
        sr, sc, er, ec = unpack(marks)
    else
        _, sr, sc, _ = unpack(vim.fn.getpos('v'))
        _, er, ec, _ = unpack(vim.fn.getcurpos())
    end

    if not preview then
        vim.api.nvim_buf_clear_namespace(0, -1, 0, -1)
    else if marks then
        for i = sr, er do
            vim.api.nvim_buf_add_highlight(0, -1, 'Visual', i - 1, 0, -1)
        end
    end
    end

    if sr == ec then
        return
    end

    if not str or str == '' then
        return
    end
    reverse = not not reverse
    preview = not not preview

    restore()

    if er < sr then
        er, sr = sr, er
    end

    local target = 0
    local positions = {}

    local visual = vim.fn.mode() == 'v'

    local lines
    if preview then
        lines = vim.api.nvim_buf_get_lines(0, sr - 1, er, true)
        if not real then
            real = {sr, er, lines}
        end
    else
        lines = real and real[3] or vim.api.nvim_buf_get_lines(0, sr - 1, er, true)
        real = nil
    end

    if not lines then
        return
    end

    for i = sr, er do
        local line = lines[i - sr + 1]
        if not line then
            break
        end

        if preview and ((i == sr and visual and not pcall(string.find, line, str, sc)) or not pcall(string.find, line, str)) then
            return
        end
        local start = i == sr and visual and line:find(str, sc) or line:find(str)

        if start then
            if i == er and ec < start and visual then
                break
            end
            table.insert(positions, { i, start })
            if reverse then
                for j = start - 1, 1, -1 do
                    if line:sub(j, j) == " " then
                        start = j
                    else
                        break
                    end
                end
            end
            target = math.max(target, start)
        end
    end

    if target == 0 or #positions == 0 then
        return
    end

    for _, pos in ipairs(positions) do
        local r, c = unpack(pos)
        local curr = lines[r - sr + 1]
        if c <= target then
            vim.api.nvim_buf_set_lines(0, r - 1, r, true, {str_insert(curr, c, (' '):rep(target - c + (reverse and 1 or 0)))})
        else
            vim.api.nvim_buf_set_lines(0, r - 1, r, true, {string.sub(curr, 1, target) .. string.sub(curr, c)})
        end
    end

    if not preview then
        vim.api.nvim_input('<Esc>')
    else if marks then
        for i = sr, er do
            vim.api.nvim_buf_add_highlight(0, -1, 'Visual', i - 1, 0, -1)
        end
    end
    end
    print(' ')

    return 1
end

local function input(str)
    local ch = vim.fn.getcharstr()
    if ch == vim.api.nvim_replace_termcodes('<Esc>', true, false, true) then
        print(' ')
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

local function align_wrapper(str, reverse, marks)
    if marks and marks.sr then
        local sr, er = marks.sr, marks.er
        if sr == er then
            return
        end
        for i = sr, er do
            vim.api.nvim_buf_add_highlight(0, -1, 'Visual', i - 1, 0, -1)
        end
    end
    align(str, reverse, false, marks)
end


local function align_to_char(length, reverse, preview, marks)
    if marks and marks.sr then
        local sr, er = marks.sr, marks.er
        if sr == er then
            return
        end
        for i = sr, er do
            vim.api.nvim_buf_add_highlight(0, -1, 'Visual', i - 1, 0, -1)
        end
    end
    length = math.max(length, 1)
    preview = not not preview and length > 1
    local prompt = 'Enter ' .. (length > 1 and length .. ' characters: ' or 'a character: ')
    print(prompt)
    local str = ''
    while #str < length do
        vim.cmd[[redraw]]
        print(prompt .. str)
        local err, new_str = input(str)
        if preview then
            restore()
        end
        if err == 0 then
            return
        end
        if err == 1 then
            break
        end
        str = new_str
        align(escape(str), not not reverse, true, marks)
    end
    align_wrapper(escape(str), not not reverse, marks)
end

local function align_to_string(is_pattern, reverse, preview, marks)
    if marks and marks.sr then
        local sr, er = marks.sr, marks.er
        if sr == er then
            return
        end
        for i = sr, er do
            vim.api.nvim_buf_add_highlight(0, -1, 'Visual', i - 1, 0, -1)
        end
    end
    preview = not not preview
    is_pattern = not not is_pattern
    local prompt = is_pattern and 'Enter pattern: ' or 'Enter string: '
    print(prompt)
    local str = ''
    -- local previews = 0
    while true do
        vim.cmd[[redraw]]
        print(prompt .. str)
        local err, new_str = input(str)
        if preview then
            restore()
        end
        if err == 0 then
            -- TODO: undo such that no history is kept
            print(' ')
            vim.cmd[[redraw]]
            return
        end
        if err == 1 then
            break
        end
        str = new_str

        local escaped = escape(str, is_pattern)
        align(escaped, not not reverse, true, marks)
    end
    -- TODO: undo such that no history is kept
    align_wrapper(escape(str, is_pattern), not not reverse, marks)
end

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

        for i = sr, er do
            vim.api.nvim_buf_add_highlight(0, -1, 'Visual', i - 1, 0, -1)
        end

        local marks = {sr, sc, er, ec}
        if fn == align_to_char then
            align_to_char(opts.length, opts.reverse, opts.preview, marks)
        elseif fn == align_to_string then
            align_to_string(opts.is_pattern, opts.reverse, opts.preview, marks)
        elseif fn == align_wrapper then
            align_wrapper(opts.str, opts.reverse, marks)
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
