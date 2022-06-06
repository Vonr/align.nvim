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

local function align(str, reverse, preview)
    if not str or str == '' then
        return
    end
    reverse = not not reverse
    preview = not not preview

    restore()
    local _, sr, sc, _ = unpack(vim.fn.getpos('v'))
    local _, er, ec, _ = unpack(vim.fn.getcurpos())
    if er == sr then
        return
    end
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

    -- local rectified = {}
    for _, pos in ipairs(positions) do
        local r, c = unpack(pos)
        local curr = lines[r - sr + 1]
        if c <= target then
            vim.api.nvim_buf_set_lines(0, r - 1, r, true, {string.insert(curr, c, (' '):rep(target - c + (reverse and 1 or 0)))})
        else
            vim.api.nvim_buf_set_lines(0, r - 1, r, true, {string.sub(curr, 1, target) .. string.sub(curr, c)})
        end
    end

    if not preview then
        vim.api.nvim_input('<Esc>')
    end

    return 1
end

local function input(str)
    local ch = vim.fn.getcharstr()
    if ch == vim.api.nvim_replace_termcodes('<Esc>', true, false, true) then
        print()
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

local function align_wrapper(str, reverse)
    align(str, reverse, false)
end


local function align_to_char(length, reverse, preview)
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
        align(str, not not reverse, true)
    end
    align_wrapper(str, not not reverse)
    print()
end

local function align_to_string(is_pattern, reverse, preview)
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
            vim.cmd[[redraw]]
            return
        end
        if err == 1 then
            break
        end
        str = new_str

        local escaped = escape(str, is_pattern)
        align(escaped, not not reverse, true)
    end
    -- TODO: undo such that no history is kept
    align_wrapper(escape(str, is_pattern), not not reverse)
end

return {
    align = align_wrapper,
    align_to_char = align_to_char,
    align_to_string = align_to_string,
}
