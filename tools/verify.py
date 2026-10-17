from pathlib import Path
import argparse,json,re,subprocess

REPO=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser()
parser.add_argument('--compiler',default='luau-compile')
parser.add_argument('--runtime',default='luau')
args=parser.parse_args()
subprocess.run(['python',str(REPO/'tools/build_startup.py'),'--check'],check=True)
WORK=REPO/'work'
WORK.mkdir(exist_ok=True)
COMPILER=Path(args.compiler)
LUAU=Path(args.runtime)
sources=sorted(p for p in [*REPO.rglob('*.luau'),*REPO.rglob('*.lua')] if 'work' not in p.relative_to(REPO).parts and '.git' not in p.relative_to(REPO).parts)
for start in range(0,len(sources),30):
    r=subprocess.run([str(COMPILER),'--null',*map(str,sources[start:start+30])],capture_output=True)
    assert r.returncode==0,r.stderr.decode(errors='replace')
assert "applicationName = 'XLQP'" in (REPO/'src/framework/settings.luau').read_text()
assert not (REPO/'LICENSE').exists()
assert 'Copyright (c) 2026 tlredz' in (REPO/'LICENSES/upstream-iy-remake.txt').read_text()
api_data=json.loads((REPO/'vendor/raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json').read_text(encoding='utf-8'))
assert isinstance(api_data['Classes'],list) and isinstance(api_data['Enums'],list)
print(f'PASS: {len(sources)} source files compile; XLQP branding; upstream notice preserved under LICENSES')

def literal(data):
    try:
        text=data.decode('utf-8')
        if '\x00' in text:raise UnicodeDecodeError('utf8',data,0,1,'binary')
        eq='='
        while ']'+eq+']' in text:eq+='='
        return '['+eq+'['+ ('\n' if text.startswith('\n') else '') +text+']'+eq+']'
    except UnicodeDecodeError:
        return '"'+''.join(chr(b) if 32<=b<127 and b not in (34,92) else '\\%03d'%b for b in data)+'"'

parts=['local vfs = {}\n']
download_pattern=re.compile(r'''(?:__XLQP_HTTP\s*\(\s*\w+\s*,|SafeLoad\s*\()\s*(?:'([^']+)'|"([^"]+)"|\[(=*)\[(.*?)\]\3\])''',re.S)
download_urls=set()
for folder in ('backups','vendor'):
    for p in (REPO/folder).rglob('*'):
        if p.suffix not in ('.lua','.luau') or 'legacy' in p.relative_to(REPO).parts:continue
        for match in download_pattern.finditer(p.read_text(encoding='utf-8')):
            url=match[1] or match[2] or match[4]
            if re.search(r'\.luau?(?:\?|$)',url):download_urls.add(url)
parts.append('local downloadUrls = {'+','.join(literal(url.encode()) for url in sorted(download_urls))+'}\n')
for p in sorted(REPO.rglob('*')):
    if not p.is_file() or '.git' in p.relative_to(REPO).parts or 'work' in p.relative_to(REPO).parts:continue
    key=p.relative_to(REPO).as_posix()
    data=p.read_bytes()
    if key=='main.luau':
        old=b'return require("./src/core"):boot()'
        assert data.count(old)==1
        data=data.replace(old,b'return resources')
    parts.append('vfs[ '+literal(key.encode())+' ] = '+literal(data)+'\n')
parts.append(r'''local nativeLoad = loadstring
local base = "https://raw.githubusercontent.com/josediaz765/xlqp/main/"
local function check(localMode)
    local requests = {}
    local env
    local fakeGame = {}
    function fakeGame:HttpGet(url)
        requests[#requests + 1] = url
        assert(url:sub(1, #base) == base, "Unexpected distribution host: " .. url)
        local relative = url:sub(#base + 1):match("^[^?]+"):gsub("%%(%x%x)", function(hex)
            return string.char(tonumber(hex, 16))
        end)
        return assert(vfs[relative], "HTTP path missing: " .. relative)
    end
    env = setmetatable({
        XLQP_ROOT = "xlqp",
        XLQP_LOCAL = localMode,
        game = fakeGame,
        getgenv = function() return env end,
        readfile = function(path)
            assert(localMode, "Hosted loader accessed local files")
            assert(path:sub(1, 5) == "xlqp/")
            return assert(vfs[path:sub(6)], "Local path missing: " .. path)
        end,
        isfile = function(path) return localMode and vfs[path:sub(6)] ~= nil end,
    }, {__index = getfenv()})
    env.loadstring = function(source, name)
        if name == '=xlqp/main.luau' then
            source = source:gsub('return require%("%./src/core"%):boot%(%)', 'return resources', 1)
        end
        local fn, err = nativeLoad(source, name)
        if fn then setfenv(fn, env) end
        return fn, err
    end
    local resources = assert(env.loadstring(vfs['loader.luau'], 'XLQP/test'))()
    local count = 0
    for key, path in resources.files do
        assert(vfs[path], path)
        assert(type(resources.lookup(key)) == "string", key)
        count += 1
    end
    for _, key in resources.scripts do
        local chunk, err = resources.load(key)
        assert(type(chunk) == "function", key .. ": " .. tostring(err))
    end
    for _, url in downloadUrls do
        local body = resources.lookup(url)
        assert(type(body)=='string' and #body>0, 'Missing nested script dependency: ' .. url)
        assert(nativeLoad(body), 'Invalid nested script dependency: ' .. url)
    end
    print('PASS: ' .. #downloadUrls .. ' literal nested script URLs resolve to compilable repository snapshots')
    assert(resources.lookup('assets/logo.png'):sub(1,8) == "\137PNG\r\n\26\n")
    assert(resources.lookup('http://setup.roblox.com/version-test-API-Dump.json') == resources.lookup('snapshot/api'), 'Dex received version text instead of API JSON')
    assert(resources.lookup('https://setup.roblox.com/version-test-Full-API-Dump.json?cache=1') == resources.lookup('snapshot/full-api'))
    assert(resources.request({Url='https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua',Method='GET'}).StatusCode==200)
    local missing = pcall(resources.httpGet, nil, "https://example.com/not-in-repository.lua")
    assert(not missing)
    assert(env.loadstring(resources.source("return 42"))() == 42)
    if localMode then assert(#requests == 0) else assert(#requests > 0) end
    print("PASS: " .. (if localMode then "local" else "hosted") .. " loader; " .. count .. " resource mappings; " .. #resources.scripts .. " lazy sources compile; teleport continuation returns 42; HTTP requests=" .. #requests)
end
check(true)
check(false)
''')
fixture=WORK/'test_xlqp_runtime.luau'
fixture.write_text(''.join(parts),encoding='utf-8',newline='\n')
r=subprocess.run([str(LUAU),str(fixture)],capture_output=True,text=True,encoding='utf-8')
print(r.stdout,end='')
assert r.returncode==0,r.stderr
(WORK/'xlqp-test-results.json').write_text(json.dumps({'source_count':len(sources),'exit_status':r.returncode,'stdout':r.stdout,'stderr':r.stderr,'fixture':'Hosted and local loaders; UI startup intercepted; HTTP served from repository file fixtures'},indent=2),encoding='utf-8')
