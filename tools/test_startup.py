from pathlib import Path
import argparse
import io
import subprocess
import zipfile

repo = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--runtime', default='luau')
parser.add_argument('--revision')
parser.add_argument('--source-root', type=Path)
parser.add_argument('--expect-fast', action='store_true')
args = parser.parse_args()

def literal(data):
    try:
        text = data.decode('utf-8')
        if '\x00' in text:
            raise ValueError('binary')
        eq = '='
        while ']' + eq + ']' in text:
            eq += '='
        return '[' + eq + '[' + ('\n' if text.startswith('\n') else '') + text + ']' + eq + ']'
    except (UnicodeDecodeError, ValueError):
        return '"' + ''.join(chr(b) if 32 <= b < 127 and b not in (34, 92) else '\\%03d' % b for b in data) + '"'

root = args.source_root or repo
if args.revision:
    archive = zipfile.ZipFile(io.BytesIO(subprocess.check_output(['git', '-C', str(repo), 'archive', '--format=zip', args.revision])))
    names = [name for name in archive.namelist() if not name.endswith('/')]
else:
    names = [p.relative_to(root).as_posix() for folder in ('src', 'assets', 'runtime') for p in (root/folder).rglob('*') if p.is_file()]
    names += ['loader.luau', 'main.luau', 'rbxBundle.luau']
names = sorted(name for name in names if (name.startswith(('src/', 'assets/', 'runtime/')) or name in ('loader.luau', 'main.luau', 'rbxBundle.luau')) and not name.startswith('src/tests/'))
parts = ['local vfs = {}\nlocal modulePaths = {}\nlocal assets = {}\n']
for name in names:
    if args.revision:
        data = archive.read(name)
    else:
        data = (root/name).read_bytes()
    parts.append('vfs[ ' + literal(name.encode()) + ' ] = ' + literal(data) + '\n')
    if name.startswith('src/') and name.endswith(('.lua', '.luau')):
        parts.append('table.insert(modulePaths, ' + literal(name.rsplit('.', 1)[0].encode()) + ')\n')
    elif name.startswith('assets/'):
        parts.append('table.insert(assets, ' + literal(name.encode()) + ')\n')
parts.append('local expectFast = ' + str(args.expect_fast).lower() + '\n')
parts.append(r'''
vfs['backups/cobalt.luau'] = 'return 42'
local nativeLoad = loadstring
local base = 'https://raw.githubusercontent.com/josediaz765/xlqp/main/'
local env
local requests = {}
local failNext = false
local corruptNext = false
local evaluations = 0
local function load(source, name)
    if name and name:sub(1, 6) == '=xlqp/' then
        local original = assert(vfs[name:sub(7)], name)
        assert(source:gsub('\r\n', '\n') == original:gsub('\r\n', '\n'), 'Packaged module differs: ' .. name)
    end
    if name == '=xlqp/main.luau' then
        source = source:gsub('return require%("%./src/core"%):boot%(%)', [[
for _, path in modulePaths do require('./' .. path) end
for _, path in assets do assert(resources.lookup(path) == expected[path], path) end
return resources
]], 1)
    elseif name and name:sub(1, 10) == '=xlqp/src/' and not name:match('/resources%.luau$') and not name:match('/resourcesIndex%.luau$') then
        source = 'markEvaluation() return true'
    end
    local chunk, err = nativeLoad(source, name)
    if chunk then setfenv(chunk, env) end
    return chunk, err
end
env = setmetatable({
    game = {HttpGet = function(_, url)
        table.insert(requests, url)
        assert(url:sub(1, #env.XLQP_BASE_URL) == env.XLQP_BASE_URL)
        local path = url:sub(#env.XLQP_BASE_URL + 1):match('^[^?]+'):gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex, 16)) end)
        coroutine.yield(path)
        if failNext then failNext = false error('network unavailable') end
        if corruptNext then corruptNext = false return 'return {revision="wrong",files={}}' end
        return assert(vfs[path], 'Missing HTTP fixture: ' .. path)
    end},
    XLQP_ROOT = 'xlqp',
    XLQP_BASE_URL = base,
    getgenv = function() return env end,
    loadstring = load,
    modulePaths = modulePaths,
    assets = assets,
    expected = vfs,
    markEvaluation = function() evaluations += 1 end,
    readfile = function(path)
        assert(env.XLQP_LOCAL == true, 'Hosted loader used local files')
        return assert(vfs[path:sub(6)], path)
    end,
}, {__index=getfenv()})
local function run(source, expectedError)
    local co = coroutine.create(function() return assert(load(source or vfs['loader.luau'], 'XLQP/test'))() end)
    while true do
        local ok, result = coroutine.resume(co)
        if not ok then
            assert(expectedError and tostring(result):find(expectedError, 1, true), tostring(result))
            return
        end
        if coroutine.status(co) == 'dead' then
            assert(not expectedError, 'Expected error was not raised')
            return result
        end
    end
end
local resources = run()
local cold = #requests
local coldEvaluations = evaluations
assert(resources and resources.load('missing') == nil)
run()
local warm = #requests - cold
assert(coldEvaluations > 0 and evaluations == coldEvaluations * 2, 'Repeat run reused module return values')
print('MEASURE: startup corpus (' .. #modulePaths .. ' modules, ' .. #assets .. ' assets); cold HTTP=' .. cold .. '; repeat HTTP=' .. warm .. '; outer loader request excluded')
if expectFast then
    assert(cold == 1 and warm == 0, 'Startup still downloads individual modules')
    assert(not requests[1]:find('backups/', 1, true) and not requests[1]:find('vendor/', 1, true))
    local before = #requests
    local optional = coroutine.create(function() return assert(resources.load('backups/cobalt.luau'))() end)
    assert(coroutine.resume(optional))
    local ok, value = coroutine.resume(optional)
    assert(ok and value == 42 and #requests == before + 1)
    assert(resources.load('backups/cobalt.luau')() == 42 and #requests == before + 1)
    assert(run(resources.source('return 42')) == 42)
    env.XLQP_BASE_URL = 'https://example.test/other-copy/'
    before = #requests
    run()
    assert(#requests == before + 1, 'Startup cache leaked across repositories')
    env.__XLQP_STARTUP_CACHE = nil
    failNext = true
    run(nil, 'network unavailable')
    before = #requests
    run()
    assert(#requests == before + 1, 'Failed HTTP poisoned startup cache')
    env.__XLQP_STARTUP_CACHE = nil
    corruptNext = true
    run(nil, 'XLQP startup payload is invalid')
    before = #requests
    run()
    assert(#requests == before + 1, 'Invalid payload poisoned startup cache')
    print('PASS: one startup download; warm source cache; lazy optional scripts; teleport; base isolation; HTTP/payload retry')
end
env.XLQP_LOCAL = true
local before = #requests
run()
assert(#requests == before, 'Local mode used HTTP')
print('PASS: local loader remains offline')
''')
work = repo / 'work'
work.mkdir(exist_ok=True)
target = work / 'startup-regression.luau'
target.write_text(''.join(parts), encoding='utf-8', newline='\n')
result = subprocess.run([args.runtime, str(target)], capture_output=True, text=True, encoding='utf-8')
print(result.stdout, end='')
print(result.stderr, end='')
raise SystemExit(result.returncode)
