local async = require("async")

--- Runs the loop until something has happened, answering whether it did.
---
--- A fixed sleep is a race a busy machine wins: forty milliseconds is plenty for a file to be read on
--- an idle laptop and not enough while the same machine is building an application for a phone, and a
--- suite that fails there is a gate nobody trusts. Waiting for the thing itself costs nothing when it
--- happens at once and gives a loaded machine the room it needs when it does not.
--- Ten seconds is the patience because the work being waited on is real: a file read through the pool,
--- a picture fetched, a recording written. Four was enough on an idle laptop and not enough on one that
--- was also building an application for a phone, which is a gate that fails where nothing is wrong.
return function(happened, milliseconds)
    local rounds = math.ceil((milliseconds or 10000) / 5)

    for _ = 1, rounds do
        if happened() then
            return true
        end

        async.sleep(5):await()
    end

    return happened()
end
