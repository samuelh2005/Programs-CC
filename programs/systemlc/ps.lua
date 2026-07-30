function printTable(columns, rows, spacing)
    spacing = spacing or 2

    -- Cache row values
    local values = {}
    local order = {}

    for _, row in pairs(rows) do
        table.insert(order, row)

        local cached = {}

        for c, column in ipairs(columns) do
            cached[c] = tostring(column.value(row) or "")
        end

        table.insert(values, cached)
    end

    -- Determine column widths
    local widths = {}

    for c, column in ipairs(columns) do
        widths[c] = #column.header

        for _, row in ipairs(values) do
            widths[c] = math.max(widths[c], #row[c])
        end
    end

    local function printRow(row)
        for c, column in ipairs(columns) do
            local value = row[c] or ""

            local format
            if column.align == "right" then
                format = "%" .. widths[c] .. "s"
            else
                format = "%-" .. widths[c] .. "s"
            end

            io.write(string.format(format, value))

            if c < #columns then
                io.write(string.rep(" ", spacing))
            end
        end

        io.write("\n")
    end

    -- Header
    local headers = {}

    for c, column in ipairs(columns) do
        headers[c] = column.header
    end

    printRow(headers)

    -- Separator
    for c, width in ipairs(widths) do
        io.write(string.rep("-", width))

        if c < #widths then
            io.write(string.rep(" ", spacing))
        end
    end

    io.write("\n")

    -- Rows
    for _, row in ipairs(values) do
        printRow(row)
    end
end

-------

local columns = {
    {
        header = "Name",
        value = function(p) return p.name end
    },
    {
        header = "UID",
        align = "right",
        value = function(p) return p.uid end
    },
    {
        header = "Path",
        value = function(p) return p.path end
    },
}

local count, processes = process.list()

printTable(columns, processes)
print("Total #"..count.." processes")
