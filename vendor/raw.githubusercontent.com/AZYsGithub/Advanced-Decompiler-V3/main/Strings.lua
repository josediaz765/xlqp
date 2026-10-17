local MemeStrings = {
    ' boo \u{1f47b}',
    ' Exceeded decompiler timeout.',
    ' DECOMPILED BY ADVANCED DECOMPILER V3',
    ' DISASSEMBLED...',
    ' Decompiled with the Synapse X Luau decompiler.',
    ' \u{1d4d3}\u{1d4ee}\u{1d4ec}\u{1d4f8}\u{1d4f6}\u{1d4f9}\u{1d4f2}\u{1d4f5}\u{1d4ee}\u{1d4ed} \u{1d4eb}\u{1d502} \u{1d4ef}\u{1d4fb}\u{1d4ee}\u{1d4ea}\u{1d4f4}\u{1d502} \u{1d4ed}\u{1d4ee}\u{1d4ec}\u{1d4f8}\u{1d4f6}\u{1d4f9}\u{1d4f2}\u{1d4f5}\u{1d4ee}\u{1d4fb}',
    'SynapseX Decompiler',
    'decompiler is slow, removed right now :(',
    [[NOTE: Currently in beta! Not representative of final product.]],
    ' params : ...',
    ' ' .. os.date(),
    ' your advertisement could be here',
}
local Strings = {
    SUCCESS = '--' .. MemeStrings[math.random(#MemeStrings)] .. '\n%s',
    TIMEOUT = '-- DECOMPILER TIMEOUT',
    COMPILATION_FAILURE = '-- SCRIPT FAILED TO COMPILE, ERROR:\n%s',
    UNSUPPORTED_LBC_VERSION = '-- PASSED BYTECODE IS TOO OLD AND IS NOT SUPPORTED',
    USED_GLOBALS = '-- USED GLOBALS: %s.\n',
    DECOMPILER_REMARK = '-- DECOMPILER REMARK: %s\n',
}

return Strings
