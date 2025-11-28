local solver = {}

local Graph = {}
Graph.__index = Graph

function Graph.new()
    return setmetatable({
        edges = {},
        nodes = {},
        payloads = {},
        resolved = {},
        visited = {},
        visiting = {}
    }, Graph)
end

function Graph:add(pkg_obj, dependencies)
    local name = pkg_obj.name

    if not self.edges[name] then
        self.nodes[#self.nodes + 1] = name
        self.edges[name] = dependencies or {}
        self.payloads[name] = pkg_obj
    else
        for _, dep in ipairs(dependencies or {}) do
            local exists = false

            for _, d in ipairs(self.edges[name]) do
                if d == dep then exists = true break end
            end

            if not exists then
                table.insert(self.edges[name], dep)
            end
        end
    end
end

function Graph:visit(node)
    if self.visiting[node] then
        error("Cyclic dependency detected involving package: " .. node)
    end

    if self.visited[node] then return end

    self.visiting[node] = true
    local deps = self.edges[node]

    if deps then
        for _, dep_name in ipairs(deps) do
            if self.edges[dep_name] then
                self:visit(dep_name)
            end
        end
    end

    self.visiting[node] = nil
    self.visited[node] = true
    table.insert(self.resolved, node)
end

function Graph:resolve()
    self.resolved = {}
    self.visited = {}
    self.visiting = {}

    for _, node in ipairs(self.nodes) do
        if not self.visited[node] then
            local ok, err = pcall(function() self:visit(node) end)
            if not ok then return nil, err end
        end
    end

    local final_objects = {}
    for _, name in ipairs(self.resolved) do
        table.insert(final_objects, self.payloads[name])
    end

    return final_objects
end

function solver.solve_dependencies(input_data)
    local g = Graph.new()

    for _, pkg in ipairs(input_data) do
        g:add(pkg, pkg.deps)
    end

    return g:resolve()
end

return solver