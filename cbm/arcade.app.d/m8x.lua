-- idunc: generated file ! DO NOT MODIFY !
local m8 = require("m8api")
local _ = require("mailbox")

m8.results = function(found, chkparam)
    if chkparam then chkparam(found) end
    m8.mailbox(_.m8_results_box, found)
    local rc = m8.Exec(_.m8_results_box)
    assert(rc ~= nil, "results() fail")
    return rc
end

m8.inform = function(attr, chkparam)
    if chkparam then chkparam(attr) end
    m8.mailbox(_.m8_inform_box, attr)
    local rc = m8.Exec(_.m8_inform_box)
    assert(rc ~= nil, "inform() fail")
    return rc
end

m8.programs = function(plist, chkparam)
    if chkparam then chkparam(plist) end
    m8.mailbox(_.m8_programs_box, plist)
    local rc = m8.Exec(_.m8_programs_box)
    assert(rc ~= nil, "programs() fail")
    return rc
end

m8.launch = function(names, chkparam)
    if chkparam then chkparam(names) end
    m8.mailbox(_.m8_launch_box, names)
    local rc = m8.Exec(_.m8_launch_box)
    assert(rc ~= nil, "launch() fail")
    return rc
end
