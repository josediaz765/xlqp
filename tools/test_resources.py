from pathlib import Path
import argparse
import subprocess

repo = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--runtime', default='luau')
parser.add_argument('--revision')
parser.add_argument('--source-root', type=Path)
args = parser.parse_args()

def source(path):
    if args.revision:
        return subprocess.check_output(['git', '-C', str(repo), 'show', f'{args.revision}:{path}']).decode('utf-8')
    return ((args.source_root or repo) / path).read_text(encoding='utf-8')

def literal(value):
    equals = '='
    while ']' + equals + ']' in value:
        equals += '='
    return '[' + equals + '[' + value + ']' + equals + ']'

fixture = r'''
local nativeLoad = loadstring
local index = {
    files = {['backups/cobalt.luau']='cobalt', empty='empty', retry='retry', parallel='parallel', ['snapshot/api']='api', ['snapshot/full-api']='full-api', ['snapshot/version']='version'},
    aliases = {['https://example.test/cobalt']='backups/cobalt.luau'},
    scripts = {'backups/cobalt.luau'},
}
local reads = {}
local failNext = true
local env = setmetatable({
    __XLQP_ROOT = 'xlqp',
    __XLQP_READ = function(path)
        reads[path] = (reads[path] or 0) + 1
        coroutine.yield('HTTP:' .. path)
        if path == 'retry' and failNext then
            failNext = false
            error('simulated network failure')
        end
        if path == 'api' then return '{"Classes":[],"Enums":[]}' end
        if path == 'full-api' then return '{"Classes":[],"Enums":[],"full":true}' end
        if path == 'version' then return 'version-test' end
        return if path == 'empty' then '' else 'return 42'
    end,
    require = function() return index end,
}, {__index=getfenv()})
local module = assert(nativeLoad(resourceSource, 'xlqp/src/framework/resources.luau'))
setfenv(module, env)
local resources = module()
local fetchModule = assert(nativeLoad(fetchSource, 'xlqp/src/framework/services/fetchService.luau'))
setfenv(fetchModule, setmetatable({require=function() return resources end}, {__index=getfenv()}))
local fetch = fetchModule()
local function start(fn, expected)
    local co = coroutine.create(fn)
    local ok, value = coroutine.resume(co)
    assert(ok, value)
    assert(value == 'HTTP:' .. expected, tostring(value))
    assert(coroutine.status(co) == 'suspended')
    return co
end
local function finish(co)
    local ok, value = coroutine.resume(co)
    assert(ok, value)
    assert(coroutine.status(co) == 'dead')
    return value
end
local co = start(function()
    local chunk = assert(fetch.load('backups/cobalt.luau', 'iy/cobalt'))
    return chunk()
end, 'cobalt')
assert(finish(co) == 42)
assert(fetch.load('https://example.test/cobalt')() == 42)
assert(resources.lookup('https://raw.githubusercontent.com/tlredz/iy-remake/main/backups/cobalt.luau') == 'return 42')
assert(reads.cobalt == 1)
assert(resources.lookup('missing') == nil)
assert(resources.load('missing') == nil)
assert(finish(start(function() return resources.lookup('empty') end, 'empty')) == '')
assert(resources.lookup('empty') == '' and reads.empty == 1)
co = start(function() return resources.lookup('retry') end, 'retry')
local ok, err = coroutine.resume(co)
assert(not ok and tostring(err):find('simulated network failure', 1, true))
assert(resources.entries.retry == nil)
assert(finish(start(function() return resources.lookup('retry') end, 'retry')) == 'return 42')
local a = start(function() return resources.lookup('parallel') end, 'parallel')
local b = start(function() return resources.lookup('parallel') end, 'parallel')
assert(finish(a) == 'return 42' and finish(b) == 'return 42')
assert(resources.lookup('parallel') == 'return 42')
assert(getmetatable(resources.entries) == nil)
print('PASS: yielding Cobalt fetch/load; aliases and cache; empty/missing files; network retry; concurrent callers')
local function fetchJson(url, expected)
    local co = coroutine.create(function()
        local body = resources.httpGet({}, url)
        assert(body:sub(1, 1) == '{', "Can't parse JSON")
        return body
    end)
    local value
    while coroutine.status(co) ~= 'dead' do
        local ok
        ok, value = coroutine.resume(co)
        assert(ok, value)
    end
    assert(value == expected, 'Wrong API snapshot routed')
end
fetchJson('http://setup.roblox.com/version-test-API-Dump.json', '{"Classes":[],"Enums":[]}')
fetchJson('https://setup.roblox.com/version-test-Full-API-Dump.json', '{"Classes":[],"Enums":[],"full":true}')
fetchJson('https://setup.roblox.com/version-test-API-Dump.json?cache=1', '{"Classes":[],"Enums":[]}')
assert(finish(start(function() return resources.lookup('http://setup.roblox.com/version') end, 'version')) == 'version-test')
assert(resources.lookup('https://setup.roblox.com/version?cache=1') == 'version-test')
print('PASS: Dex version-prefixed API URLs return JSON; full dump/query strings; plain version endpoint remains text')
'''
work = repo / 'work'
work.mkdir(exist_ok=True)
target = work / 'resource-regression.luau'
target.write_text('local resourceSource = ' + literal(source('src/framework/resources.luau')) + '\nlocal fetchSource = ' + literal(source('src/framework/services/fetchService.luau')) + '\n' + fixture, encoding='utf-8', newline='\n')
result = subprocess.run([args.runtime, str(target)], capture_output=True, text=True, encoding='utf-8')
print(result.stdout, end='')
print(result.stderr, end='')
raise SystemExit(result.returncode)
