local _persist = rawget(_G, "_persist_vars")
if not _persist then
    _persist = {}
    rawset(_G, "_persist_vars", _persist)
end

function Persist(key)
    if not _persist[key] then
        _persist[key] = {}
    end
    return _persist[key]
end

function PersistReset(key)
    if key then
        _persist[key] = nil
    else
        for k in pairs(_persist) do
            _persist[k] = nil
        end
    end
end
