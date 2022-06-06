local function align(str, is_pattern, reverse)
    if not str or str == '' then
        return
    end
    reverse = not not reverse

    local _, sr, sc, _ = unpack(vim.fn.getpos('v'))
    local _, er, ec, _ = unpack(vim.fn.getcurpos())
    if er == sr then
        return
    end

    local target = 0
    local positions = {}

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

    local visual = vim.fn.mode() == 'v'

    for i = sr, er, er > sr and 1 or -1 do
        local lines = vim.api.nvim_buf_get_lines(0, i - 1, i, false)
        if not lines then
            break
        end
        local line = lines[1]
        if not line then
            break
        end

        local start = i == sr and visual and line:find(str, sc) or line:find(str)
        if start then
            if i == er and ec < start and visual then
                break
            end
            table.insert(positions, { i, start })
            if reverse then
                print('Hi')
                for j = start - 1, 1, -1 do
                    if line:sub(j, j) == " " then
                        start = j
                        Start = start
                    else
                        break
                    end
                end
            end
            target = math.max(target, start)
        end
        Target = target
    end

    if target == 0 or #positions == 0 then
        return
    end

    for _, pos in ipairs(positions) do
        local r, c = unpack(pos)
        local curr = vim.api.nvim_buf_get_lines(0, r - 1, r, true)[1]
        -- vim.api.nvim_buf_set_lines(
        --     0    ,
        --     r - 1,
        --     r    ,
        --     true ,
        --     { string.insert(curr, c, (' '):rep(target - c)) }
        -- )
        if c <= target then
            vim.api.nvim_buf_set_lines(
                0    ,
                r - 1,
                r    ,
                true ,
                { string.insert(curr, c, (' '):rep(target - c + (reverse and 1 or 0))) }
            )
        else
            -- Use string.sub to split around spaces
            vim.api.nvim_buf_set_lines(
                0    ,
                r - 1,
                r    ,
                true ,
                { string.sub(curr, 1, target) .. string.sub(curr, c) }
            )
        end
    end
    vim.api.nvim_input('<Esc>')
end

local function align_to_char(number, reverse)
    number = number or 1
    if number < 1 then
        return
    end
    local prompt = 'Enter ' .. (number > 1 and number .. ' characters: ' or 'a character: ')
    print(prompt)
    local str = ''
    for _ = 1, number do
        str = str .. vim.fn.getcharstr()
        print(prompt .. str)
    end
    align(str, false, not not reverse)
end

local function align_to_string(is_pattern, reverse)
    local str = vim.fn.input(is_pattern and 'Enter pattern: ' or 'Enter string: ')
    align(str, not not is_pattern, not not reverse)
end

return {
    align_to_char = align_to_char,
    align_to_string = align_to_string,
}
