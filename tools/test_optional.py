from pathlib import Path
import argparse
import subprocess

repo = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--runtime', default='luau')
parser.add_argument('--revision')
parser.add_argument('--source-root', type=Path)
parser.add_argument('--case', choices=['emotes', 'dependencies', 'runner', 'wallwalk', 'all'], default='all')
args = parser.parse_args()

def source(path):
    if args.revision:
        return subprocess.check_output(['git', '-C', str(repo), 'show', f'{args.revision}:{path}']).decode('utf-8')
    return ((args.source_root or repo) / path).read_text(encoding='utf-8')

def literal(value):
    eq = '='
    while ']' + eq + ']' in value:
        eq += '='
    return '[' + eq + '[' + value + ']' + eq + ']'

emotes = source('backups/emotes/main.luau')
preamble = emotes.split('local offsaleAnimationJson', 1)[0]
keybind = 'local function setupPCKeybind()' + emotes.split('local function setupPCKeybind()', 1)[1]
safe_load = 'function SafeLoad(url, name)' + emotes.split('function SafeLoad(url, name)', 1)[1].split('\nSafeLoad(', 1)[0]
fixture = r'''
local nativeLoad = loadstring
local function module(source, env)
    local chunk = assert(nativeLoad(source))
    setfenv(chunk, setmetatable(env, {__index=getfenv()}))
    return chunk
end
local function checkEmotes()
    local keys = {}
    for _, name in {'Period','Semicolon','F4','Unknown'} do
        keys[name] = {Name=name, EnumType=keys, kind='EnumItem'}
    end
    setmetatable(keys, {__index=function(_, name) error('Invalid KeyCode: ' .. name) end})
    local enums = {
        KeyCode=keys, UserInputState={Begin='Begin', End='End'},
        ContextActionResult={Pass='Pass', Sink='Sink'}, ContextActionPriority={High={Value=2000}},
    }
    local cases = {
        {label='omitted key', config={notifyFunction=function() end}, expected=keys.Period},
        {label='no config', expected=keys.Period},
        {label='bad config', config=false, expected=keys.Period},
        {label='key string', config={keycode='F4'}, expected=keys.F4},
        {label='key EnumItem', config={keycode=keys.Semicolon}, expected=keys.Semicolon},
        {label='invalid string', config={keycode='InvalidKey'}, expected=keys.Period},
        {label='false key', config={keycode=false}, expected=keys.Period},
        {label='numeric key', config={keycode=42}, expected=keys.Period},
        {label='wrong enum', config={keycode={kind='EnumItem', EnumType={}, Name='Begin'}}, expected=keys.Period},
        {label='Unknown key', config={keycode=keys.Unknown}, expected=keys.Period},
        {label='mobile', config={isMobile=true}, mobile=true},
        {label='nonboolean mobile', config={isMobile='false'}, expected=keys.Period},
    }
    for _, case in cases do
        local global, callback, bound, focused, toggles, mobile = {}, nil, nil, nil, 0, false
        local actions = {}
        function actions:GetBoundActionInfo() return {} end
        function actions:UnbindAction() end
        function actions:BindActionAtPriority(_, fn, _, _, key) bound=key; callback=fn end
        local env = {
            Enum=enums, _G=global, typeof=function(value) return type(value)=='table' and value.kind or type(value) end,
            game={GetService=function() return actions end}, ContextActionService=actions,
            State={hudEditorActive=false}, UserInputService={GetFocusedTextBox=function() return focused end},
            toggleEmotesMenu=function() toggles+=1 end,
            setupMobileButton=function() mobile=true end,
        }
        local chunk = module(preamble .. '\n' .. keybind .. '\nreturn config', env)
        local ok, result = pcall(chunk, case.config)
        assert(ok, case.label .. ': ' .. tostring(result))
        assert(global.EmotesGUIRunning==true, case.label .. ': initialization was not marked successful')
        if case.mobile then
            assert(mobile and bound==nil)
        else
            assert(bound==case.expected, case.label .. ': wrong key')
            assert(callback(nil, 'End')=='Pass' and toggles==0)
            focused={}; assert(callback(nil, 'Begin')=='Pass' and toggles==0)
            focused=nil; env.State.hudEditorActive=true
            assert(callback(nil, 'Begin')=='Pass' and toggles==0)
            env.State.hudEditorActive=false
            assert(callback(nil, 'Begin')=='Sink' and toggles==1)
        end
    end
    for _, active in {false, true} do
        local global = {EmotesGUIRunning=true}
        local chunk = module(preamble .. '\nreturn "continued"', {
            Enum=enums, _G=global, typeof=function(v) return type(v)=='table' and v.kind or type(v) end,
            game={GetService=function() return {GetBoundActionInfo=function() return active and {inputTypes={keys.Period}} or {} end} end},
        })
        local result = chunk({})
        assert(result==(if active then nil else 'continued'), 'stale/active emote guard')
    end
    print('PASS: actual emote config/keybind; omitted/invalid/valid keys; mobile selection; textbox isolation; stale running guard')
end
local function checkDependencies()
    for _, mode in {'ok','download','empty','parse','initialize'} do
        local notices, attempts = 0, 0
        local env = {
            game={}, Notify=function() notices+=1 end,
            task={wait=function() end},
            __XLQP_HTTP=function()
                attempts+=1
                if mode=='download' then error('network failed') end
                if mode=='empty' then return '' end
                return 'dependency source'
            end,
            loadstring=function()
                if mode=='parse' then return nil, 'invalid syntax' end
                return function()
                    if mode=='initialize' then error('library failed') end
                    return {ready=true}
                end
            end,
            getgenv=function() return {} end,
        }
        local chunk = module(safeLoad .. '\nreturn SafeLoad("https://example.test/library.lua", "test library")', env)
        local ok, result = pcall(chunk)
        if mode=='ok' then
            assert(ok and result.ready and attempts==1)
        else
            assert(not ok and tostring(result):find('test library',1,true), mode .. ': missing dependency error')
            assert(attempts==(if mode=='download' or mode=='empty' then 3 else 1))
            if mode=='download' or mode=='empty' then assert(notices==1) end
        end
    end
    print('PASS: actual emote dependency loader; successful library; download/empty/parse/initialization failures propagate; retries')
end
local function checkRunner()
    local cases = {{index=1},{index=2},{index=2,moon=true},{index=3},{index=4},{index=5},{index=6}}
    for _, case in cases do
        for _, scenario in {'ok','download','compile','initialize','overlap'} do
            local mode = scenario
            local ran, fetches, errors, uncaught, messages, timers, suspended = 0, 0, {}, {}, {}, {}, {}
            local env = {task={
                delay=function(_, fn) table.insert(timers, fn) end,
                spawn=function(fn, ...)
                    local co = coroutine.create(fn)
                    local ok, err = coroutine.resume(co, ...)
                    if not ok then table.insert(uncaught, tostring(err)) end
                    if coroutine.status(co)=='suspended' then table.insert(suspended, co) end
                end,
            }}
            local commands = module(runner, env)()
            local self = {isMobile=false, fetchService={load=function(path)
                fetches+=1
                if mode=='download' then error('download failed') end
                if mode=='compile' then return nil,'parse failed' end
                if mode=='overlap' then coroutine.yield('HTTP') end
                return function(config)
                    if mode=='initialize' then error('initialize failed') end
                    ran+=1
                    if path=='backups/emotes/main.luau' then
                        assert(config.keycode=='F4' and config.isMobile==false)
                        assert(type(config.notifyFunction)=='function')
                        config.notifyFunction({Title='Emote', Content='hidden'})
                    end
                    return 'ready'
                end
            end}}
            function self:notify(_, content)
                if content=='finished loading' then assert(ran>0,'success announced before initialization') end
                assert(content~='hidden', 'notify=false ignored')
                table.insert(messages, content)
            end
            function self:reportError(label, reason, trace)
                assert(type(trace)=='string' and #trace>0)
                table.insert(errors, tostring(reason))
            end
            local function invoke()
                local values = if case.index==3 then {'F4',false} else {case.moon}
                local pos=0
                commands[case.index].run(self, {nextValue=function() pos+=1; return values[pos] end})
            end
            invoke()
            if scenario=='overlap' then
                assert(#suspended==1)
                invoke()
                assert(fetches==1 and messages[#messages]=='is already loading','duplicate launch')
                local ok, err = coroutine.resume(suspended[1]); assert(ok, err)
            end
            local success = scenario=='ok' or scenario=='overlap'
            assert(#uncaught==0, table.concat(uncaught, '\n'))
            assert(#errors==(if success then 0 else 1), scenario .. ': error not reported')
            local successes=0
            for _, message in messages do if message=='finished loading' then successes+=1 end end
            assert(successes==(if success then 1 else 0), 'false success')
            local count=#messages
            for _, timer in timers do timer() end
            assert(#messages==count,'slow timer continued after completion')
            if not success then
                mode='ok'; invoke()
                assert(ran==1 and messages[#messages]=='finished loading','retry blocked after failure')
            end
        end
    end
    print('PASS: all 7 tool launch variants; initialization before success; download/compile/runtime errors; retry; overlapping yielding loads; timer cleanup')
end
local function checkWallwalk()
    for _, mode in {'download','compile','initialize','missing','ok'} do
        local fetches, messages = 0, {}
        local self = {privateEnv={}, fetchService={load=function()
            fetches+=1
            if mode=='download' then error('download failed') end
            if mode=='compile' then return nil,'parse failed' end
            return function()
                if mode=='initialize' then error('initialize failed') end
                if mode=='missing' then return {} end
                return function() end
            end
        end}}
        function self:notify(_, text) table.insert(messages,text) end
        local getWallwalk = module(wallwalk, {})()
        local result = getWallwalk(self)
        if mode=='ok' then
            assert(type(result)=='function' and getWallwalk(self)==result and fetches==1)
        else
            assert(result==nil and self.privateEnv.wallwalkSetEnabled==nil)
            assert(#messages==1 and messages[1]:find('could not load:',1,true),'missing actionable failure')
        end
    end
    print('PASS: actual Wallwalk loader; download/compile/initialization errors; invalid controller; successful controller cache')
end
'''
fixture = ('local preamble=' + literal(preamble) + '\nlocal keybind=' + literal(keybind)
           + '\nlocal safeLoad=' + literal(safe_load) + '\nlocal runner='
           + literal(source('src/commands/cmds/general/scripts.luau')) + '\nlocal wallwalk='
           + literal(source('src/commands/cmds/teleport/walk.luau').split('\nreturn {',1)[0] + '\nreturn getWallwalk') + '\n' + fixture)
checks = {'emotes': 'checkEmotes()', 'dependencies': 'checkDependencies()', 'runner': 'checkRunner()', 'wallwalk': 'checkWallwalk()'}
fixture += '\n' + '\n'.join(checks.values() if args.case == 'all' else [checks[args.case]]) + '\n'
work = repo / 'work'
work.mkdir(exist_ok=True)
path = work / f'test_optional_{args.case}.luau'
path.write_text(fixture, encoding='utf-8', newline='\n')
result = subprocess.run([args.runtime, str(path)], capture_output=True, text=True)
print(result.stdout, end='')
if result.returncode:
    print(result.stderr, end='')
raise SystemExit(result.returncode)
