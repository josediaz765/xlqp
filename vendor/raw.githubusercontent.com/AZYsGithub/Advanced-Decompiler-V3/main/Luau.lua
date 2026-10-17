local CASE_MULTIPLIER = 227
local Luau = {
    OpCode = {
        {
            ['name'] = 'NOP',
            ['type'] = 'none',
        },
        {
            ['name'] = 'BREAK',
            ['type'] = 'none',
        },
        {
            ['name'] = 'LOADNIL',
            ['type'] = 'A',
        },
        {
            ['name'] = 'LOADB',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'LOADN',
            ['type'] = 'AsD',
        },
        {
            ['name'] = 'LOADK',
            ['type'] = 'AD',
        },
        {
            ['name'] = 'MOVE',
            ['type'] = 'AB',
        },
        {
            ['name'] = 'GETGLOBAL',
            ['type'] = 'AC',
            ['aux'] = true,
        },
        {
            ['name'] = 'SETGLOBAL',
            ['type'] = 'AC',
            ['aux'] = true,
        },
        {
            ['name'] = 'GETUPVAL',
            ['type'] = 'AB',
        },
        {
            ['name'] = 'SETUPVAL',
            ['type'] = 'AB',
        },
        {
            ['name'] = 'CLOSEUPVALS',
            ['type'] = 'A',
        },
        {
            ['name'] = 'GETIMPORT',
            ['type'] = 'AD',
            ['aux'] = true,
        },
        {
            ['name'] = 'GETTABLE',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'SETTABLE',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'GETTABLEKS',
            ['type'] = 'ABC',
            ['aux'] = true,
        },
        {
            ['name'] = 'SETTABLEKS',
            ['type'] = 'ABC',
            ['aux'] = true,
        },
        {
            ['name'] = 'GETTABLEN',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'SETTABLEN',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'NEWCLOSURE',
            ['type'] = 'AD',
        },
        {
            ['name'] = 'NAMECALL',
            ['type'] = 'ABC',
            ['aux'] = true,
        },
        {
            ['name'] = 'CALL',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'RETURN',
            ['type'] = 'AB',
        },
        {
            ['name'] = 'JUMP',
            ['type'] = 'sD',
        },
        {
            ['name'] = 'JUMPBACK',
            ['type'] = 'sD',
        },
        {
            ['name'] = 'JUMPIF',
            ['type'] = 'AsD',
        },
        {
            ['name'] = 'JUMPIFNOT',
            ['type'] = 'AsD',
        },
        {
            ['name'] = 'JUMPIFEQ',
            ['type'] = 'AsD',
            ['aux'] = true,
        },
        {
            ['name'] = 'JUMPIFLE',
            ['type'] = 'AsD',
            ['aux'] = true,
        },
        {
            ['name'] = 'JUMPIFLT',
            ['type'] = 'AsD',
            ['aux'] = true,
        },
        {
            ['name'] = 'JUMPIFNOTEQ',
            ['type'] = 'AsD',
            ['aux'] = true,
        },
        {
            ['name'] = 'JUMPIFNOTLE',
            ['type'] = 'AsD',
            ['aux'] = true,
        },
        {
            ['name'] = 'JUMPIFNOTLT',
            ['type'] = 'AsD',
            ['aux'] = true,
        },
        {
            ['name'] = 'ADD',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'SUB',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'MUL',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'DIV',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'MOD',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'POW',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'ADDK',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'SUBK',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'MULK',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'DIVK',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'MODK',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'POWK',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'AND',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'OR',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'ANDK',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'ORK',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'CONCAT',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'NOT',
            ['type'] = 'AB',
        },
        {
            ['name'] = 'MINUS',
            ['type'] = 'AB',
        },
        {
            ['name'] = 'LENGTH',
            ['type'] = 'AB',
        },
        {
            ['name'] = 'NEWTABLE',
            ['type'] = 'AB',
            ['aux'] = true,
        },
        {
            ['name'] = 'DUPTABLE',
            ['type'] = 'AD',
        },
        {
            ['name'] = 'SETLIST',
            ['type'] = 'ABC',
            ['aux'] = true,
        },
        {
            ['name'] = 'FORNPREP',
            ['type'] = 'AsD',
        },
        {
            ['name'] = 'FORNLOOP',
            ['type'] = 'AsD',
        },
        {
            ['name'] = 'FORGLOOP',
            ['type'] = 'AsD',
            ['aux'] = true,
        },
        {
            ['name'] = 'FORGPREP_INEXT',
            ['type'] = 'A',
        },
        {
            ['name'] = 'FASTCALL3',
            ['type'] = 'ABC',
            ['aux'] = true,
        },
        {
            ['name'] = 'FORGPREP_NEXT',
            ['type'] = 'A',
        },
        {
            ['name'] = 'NATIVECALL',
            ['type'] = 'none',
        },
        {
            ['name'] = 'GETVARARGS',
            ['type'] = 'AB',
        },
        {
            ['name'] = 'DUPCLOSURE',
            ['type'] = 'AD',
        },
        {
            ['name'] = 'PREPVARARGS',
            ['type'] = 'A',
        },
        {
            ['name'] = 'LOADKX',
            ['type'] = 'A',
            ['aux'] = true,
        },
        {
            ['name'] = 'JUMPX',
            ['type'] = 'E',
        },
        {
            ['name'] = 'FASTCALL',
            ['type'] = 'AC',
        },
        {
            ['name'] = 'COVERAGE',
            ['type'] = 'E',
        },
        {
            ['name'] = 'CAPTURE',
            ['type'] = 'AB',
        },
        {
            ['name'] = 'SUBRK',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'DIVRK',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'FASTCALL1',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'FASTCALL2',
            ['type'] = 'ABC',
            ['aux'] = true,
        },
        {
            ['name'] = 'FASTCALL2K',
            ['type'] = 'ABC',
            ['aux'] = true,
        },
        {
            ['name'] = 'FORGPREP',
            ['type'] = 'AsD',
        },
        {
            ['name'] = 'JUMPXEQKNIL',
            ['type'] = 'AsD',
            ['aux'] = true,
        },
        {
            ['name'] = 'JUMPXEQKB',
            ['type'] = 'AsD',
            ['aux'] = true,
        },
        {
            ['name'] = 'JUMPXEQKN',
            ['type'] = 'AsD',
            ['aux'] = true,
        },
        {
            ['name'] = 'JUMPXEQKS',
            ['type'] = 'AsD',
            ['aux'] = true,
        },
        {
            ['name'] = 'IDIV',
            ['type'] = 'ABC',
        },
        {
            ['name'] = 'IDIVK',
            ['type'] = 'ABC',
        },
        {
            ['name'] = '_COUNT',
            ['type'] = 'none',
        },
    },
    BytecodeTag = {
        LBC_VERSION_MIN = 3,
        LBC_VERSION_MAX = 6,
        LBC_TYPE_VERSION_MIN = 1,
        LBC_TYPE_VERSION_MAX = 3,
        LBC_CONSTANT_NIL = 0,
        LBC_CONSTANT_BOOLEAN = 1,
        LBC_CONSTANT_NUMBER = 2,
        LBC_CONSTANT_STRING = 3,
        LBC_CONSTANT_IMPORT = 4,
        LBC_CONSTANT_TABLE = 5,
        LBC_CONSTANT_CLOSURE = 6,
        LBC_CONSTANT_VECTOR = 7,
    },
    BytecodeType = {
        LBC_TYPE_NIL = 0,
        LBC_TYPE_BOOLEAN = 1,
        LBC_TYPE_NUMBER = 2,
        LBC_TYPE_STRING = 3,
        LBC_TYPE_TABLE = 4,
        LBC_TYPE_FUNCTION = 5,
        LBC_TYPE_THREAD = 6,
        LBC_TYPE_USERDATA = 7,
        LBC_TYPE_VECTOR = 8,
        LBC_TYPE_BUFFER = 9,
        LBC_TYPE_ANY = 15,
        LBC_TYPE_TAGGED_USERDATA_BASE = 64,
        LBC_TYPE_TAGGED_USERDATA_END = 64 + 32,
        LBC_TYPE_OPTIONAL_BIT = bit32.lshift(1, 7),
        LBC_TYPE_INVALID = 256,
    },
    CaptureType = {
        LCT_VAL = 0,
        LCT_REF = 1,
        LCT_UPVAL = 2,
    },
    BuiltinFunction = {
        LBF_NONE = 0,
        LBF_ASSERT = 1,
        LBF_MATH_ABS = 2,
        LBF_MATH_ACOS = 3,
        LBF_MATH_ASIN = 4,
        LBF_MATH_ATAN2 = 5,
        LBF_MATH_ATAN = 6,
        LBF_MATH_CEIL = 7,
        LBF_MATH_COSH = 8,
        LBF_MATH_COS = 9,
        LBF_MATH_DEG = 10,
        LBF_MATH_EXP = 11,
        LBF_MATH_FLOOR = 12,
        LBF_MATH_FMOD = 13,
        LBF_MATH_FREXP = 14,
        LBF_MATH_LDEXP = 15,
        LBF_MATH_LOG10 = 16,
        LBF_MATH_LOG = 17,
        LBF_MATH_MAX = 18,
        LBF_MATH_MIN = 19,
        LBF_MATH_MODF = 20,
        LBF_MATH_POW = 21,
        LBF_MATH_RAD = 22,
        LBF_MATH_SINH = 23,
        LBF_MATH_SIN = 24,
        LBF_MATH_SQRT = 25,
        LBF_MATH_TANH = 26,
        LBF_MATH_TAN = 27,
        LBF_BIT32_ARSHIFT = 28,
        LBF_BIT32_BAND = 29,
        LBF_BIT32_BNOT = 30,
        LBF_BIT32_BOR = 31,
        LBF_BIT32_BXOR = 32,
        LBF_BIT32_BTEST = 33,
        LBF_BIT32_EXTRACT = 34,
        LBF_BIT32_LROTATE = 35,
        LBF_BIT32_LSHIFT = 36,
        LBF_BIT32_REPLACE = 37,
        LBF_BIT32_RROTATE = 38,
        LBF_BIT32_RSHIFT = 39,
        LBF_TYPE = 40,
        LBF_STRING_BYTE = 41,
        LBF_STRING_CHAR = 42,
        LBF_STRING_LEN = 43,
        LBF_TYPEOF = 44,
        LBF_STRING_SUB = 45,
        LBF_MATH_CLAMP = 46,
        LBF_MATH_SIGN = 47,
        LBF_MATH_ROUND = 48,
        LBF_RAWSET = 49,
        LBF_RAWGET = 50,
        LBF_RAWEQUAL = 51,
        LBF_TABLE_INSERT = 52,
        LBF_TABLE_UNPACK = 53,
        LBF_VECTOR = 54,
        LBF_BIT32_COUNTLZ = 55,
        LBF_BIT32_COUNTRZ = 56,
        LBF_SELECT_VARARG = 57,
        LBF_RAWLEN = 58,
        LBF_BIT32_EXTRACTK = 59,
        LBF_GETMETATABLE = 60,
        LBF_SETMETATABLE = 61,
        LBF_TONUMBER = 62,
        LBF_TOSTRING = 63,
        LBF_BIT32_BYTESWAP = 64,
        LBF_BUFFER_READI8 = 65,
        LBF_BUFFER_READU8 = 66,
        LBF_BUFFER_WRITEU8 = 67,
        LBF_BUFFER_READI16 = 68,
        LBF_BUFFER_READU16 = 69,
        LBF_BUFFER_WRITEU16 = 70,
        LBF_BUFFER_READI32 = 71,
        LBF_BUFFER_READU32 = 72,
        LBF_BUFFER_WRITEU32 = 73,
        LBF_BUFFER_READF32 = 74,
        LBF_BUFFER_WRITEF32 = 75,
        LBF_BUFFER_READF64 = 76,
        LBF_BUFFER_WRITEF64 = 77,
        LBF_VECTOR_MAGNITUDE = 78,
        LBF_VECTOR_NORMALIZE = 79,
        LBF_VECTOR_CROSS = 80,
        LBF_VECTOR_DOT = 81,
        LBF_VECTOR_FLOOR = 82,
        LBF_VECTOR_CEIL = 83,
        LBF_VECTOR_ABS = 84,
        LBF_VECTOR_SIGN = 85,
        LBF_VECTOR_CLAMP = 86,
        LBF_VECTOR_MIN = 87,
        LBF_VECTOR_MAX = 88,
    },
    ProtoFlag = {
        LPF_NATIVE_MODULE = bit32.lshift(1, 0),
        LPF_NATIVE_COLD = bit32.lshift(1, 1),
        LPF_NATIVE_FUNCTION = bit32.lshift(1, 2),
    },
}

function Luau:INSN_OP(insn)
    return bit32.band(insn, 0xff)
end
function Luau:INSN_A(insn)
    return bit32.band(bit32.rshift(insn, 8), 0xff)
end
function Luau:INSN_B(insn)
    return bit32.band(bit32.rshift(insn, 16), 0xff)
end
function Luau:INSN_C(insn)
    return bit32.band(bit32.rshift(insn, 24), 0xff)
end
function Luau:INSN_D(insn)
    return bit32.rshift(insn, 16)
end
function Luau:INSN_sD(insn)
    local D = Luau:INSN_D(insn)
    local sD = D

    if D > 0x7fff and D <= 0xffff then
        sD = (-(0xffff - D)) - 1
    end

    return sD
end
function Luau:INSN_E(insn)
    return bit32.rshift(insn, 8)
end
function Luau:GetBaseTypeString(type, checkOptional)
    local LuauBytecodeType = Luau.BytecodeType
    local tag = bit32.band(type, bit32.bnot(LuauBytecodeType.LBC_TYPE_OPTIONAL_BIT))
    local result

    if tag == LuauBytecodeType.LBC_TYPE_NIL then
        result = 'nil'
    elseif tag == LuauBytecodeType.LBC_TYPE_BOOLEAN then
        result = 'boolean'
    elseif tag == LuauBytecodeType.LBC_TYPE_NUMBER then
        result = 'number'
    elseif tag == LuauBytecodeType.LBC_TYPE_STRING then
        result = 'string'
    elseif tag == LuauBytecodeType.LBC_TYPE_TABLE then
        result = 'table'
    elseif tag == LuauBytecodeType.LBC_TYPE_FUNCTION then
        result = 'function'
    elseif tag == LuauBytecodeType.LBC_TYPE_THREAD then
        result = 'thread'
    elseif tag == LuauBytecodeType.LBC_TYPE_USERDATA then
        result = 'userdata'
    elseif tag == LuauBytecodeType.LBC_TYPE_VECTOR then
        result = 'Vector3'
    elseif tag == LuauBytecodeType.LBC_TYPE_BUFFER then
        result = 'buffer'
    elseif tag == LuauBytecodeType.LBC_TYPE_ANY then
        result = 'any'
    else
        error('Unhandled type in GetBaseTypeString', 2)
    end
    if checkOptional then
        local optional = bit32.band(type, LuauBytecodeType.LBC_TYPE_OPTIONAL_BIT) == 0 and '' or '?'

        result ..= optional
    end

    return result
end
function Luau:GetBuiltinInfo(bfid)
    local LuauBuiltinFunction = Luau.BuiltinFunction

    if bfid == LuauBuiltinFunction.LBF_NONE then
        return 'none'
    else
        if bfid == LuauBuiltinFunction.LBF_ASSERT then
            return 'assert'
        elseif bfid == LuauBuiltinFunction.LBF_TYPE then
            return 'type'
        elseif bfid == LuauBuiltinFunction.LBF_TYPEOF then
            return 'typeof'
        elseif bfid == LuauBuiltinFunction.LBF_RAWSET then
            return 'rawset'
        elseif bfid == LuauBuiltinFunction.LBF_RAWGET then
            return 'rawget'
        elseif bfid == LuauBuiltinFunction.LBF_RAWEQUAL then
            return 'rawequal'
        elseif bfid == LuauBuiltinFunction.LBF_RAWLEN then
            return 'rawlen'
        elseif bfid == LuauBuiltinFunction.LBF_TABLE_UNPACK then
            return 'unpack'
        elseif bfid == LuauBuiltinFunction.LBF_SELECT_VARARG then
            return 'select'
        elseif bfid == LuauBuiltinFunction.LBF_GETMETATABLE then
            return 'getmetatable'
        elseif bfid == LuauBuiltinFunction.LBF_SETMETATABLE then
            return 'setmetatable'
        elseif bfid == LuauBuiltinFunction.LBF_TONUMBER then
            return 'tonumber'
        elseif bfid == LuauBuiltinFunction.LBF_TOSTRING then
            return 'tostring'
        end
        if bfid == LuauBuiltinFunction.LBF_MATH_ABS then
            return 'math.abs'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_ACOS then
            return 'math.acos'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_ASIN then
            return 'math.asin'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_ATAN2 then
            return 'math.atan2'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_ATAN then
            return 'math.atan'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_CEIL then
            return 'math.ceil'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_COSH then
            return 'math.cosh'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_COS then
            return 'math.cos'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_DEG then
            return 'math.deg'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_EXP then
            return 'math.exp'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_FLOOR then
            return 'math.floor'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_FMOD then
            return 'math.fmod'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_FREXP then
            return 'math.frexp'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_LDEXP then
            return 'math.ldexp'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_LOG10 then
            return 'math.log10'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_LOG then
            return 'math.log'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_MAX then
            return 'math.max'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_MIN then
            return 'math.min'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_MODF then
            return 'math.modf'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_POW then
            return 'math.pow'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_RAD then
            return 'math.rad'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_SINH then
            return 'math.sinh'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_SIN then
            return 'math.sin'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_SQRT then
            return 'math.sqrt'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_TANH then
            return 'math.tanh'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_TAN then
            return 'math.tan'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_CLAMP then
            return 'math.clamp'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_SIGN then
            return 'math.sign'
        elseif bfid == LuauBuiltinFunction.LBF_MATH_ROUND then
            return 'math.round'
        end
        if bfid == LuauBuiltinFunction.LBF_BIT32_ARSHIFT then
            return 'bit32.arshift'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_BAND then
            return 'bit32.band'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_BNOT then
            return 'bit32.bnot'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_BOR then
            return 'bit32.bor'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_BXOR then
            return 'bit32.bxor'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_BTEST then
            return 'bit32.btest'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_EXTRACT or bfid == LuauBuiltinFunction.LBF_BIT32_EXTRACTK then
            return 'bit32.extract'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_LROTATE then
            return 'bit32.lrotate'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_LSHIFT then
            return 'bit32.lshift'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_REPLACE then
            return 'bit32.replace'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_RROTATE then
            return 'bit32.rrotate'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_RSHIFT then
            return 'bit32.rshift'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_COUNTLZ then
            return 'bit32.countlz'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_COUNTRZ then
            return 'bit32.countrz'
        elseif bfid == LuauBuiltinFunction.LBF_BIT32_BYTESWAP then
            return 'bit32.byteswap'
        end
        if bfid == LuauBuiltinFunction.LBF_STRING_BYTE then
            return 'string.byte'
        elseif bfid == LuauBuiltinFunction.LBF_STRING_CHAR then
            return 'string.char'
        elseif bfid == LuauBuiltinFunction.LBF_STRING_LEN then
            return 'string.len'
        elseif bfid == LuauBuiltinFunction.LBF_STRING_SUB then
            return 'string.sub'
        end
        if bfid == LuauBuiltinFunction.LBF_TABLE_INSERT then
            return 'table.insert'
        end
        if bfid == LuauBuiltinFunction.LBF_VECTOR then
            return 'Vector3.new'
        end
        if bfid == LuauBuiltinFunction.LBF_BUFFER_READI8 then
            return 'buffer.readi8'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_READU8 then
            return 'buffer.readu8'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_WRITEU8 then
            return 'buffer.writeu8'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_READI16 then
            return 'buffer.readi16'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_READU16 then
            return 'buffer.readu16'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_WRITEU16 then
            return 'buffer.writeu16'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_READI32 then
            return 'buffer.readi32'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_READU32 then
            return 'buffer.readu32'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_WRITEU32 then
            return 'buffer.writeu32'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_READF32 then
            return 'buffer.readf32'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_WRITEF32 then
            return 'buffer.writef32'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_READF64 then
            return 'buffer.readf64'
        elseif bfid == LuauBuiltinFunction.LBF_BUFFER_WRITEF64 then
            return 'buffer.writef64'
        end
        if bfid == LuauBuiltinFunction.LBF_VECTOR_MAGNITUDE then
            return 'vector.magnitude'
        elseif bfid == LuauBuiltinFunction.LBF_VECTOR_NORMALIZE then
            return 'vector.normalize'
        elseif bfid == LuauBuiltinFunction.LBF_VECTOR_CROSS then
            return 'vector.cross'
        elseif bfid == LuauBuiltinFunction.LBF_VECTOR_DOT then
            return 'vector.dot'
        elseif bfid == LuauBuiltinFunction.LBF_VECTOR_FLOOR then
            return 'vector.floor'
        elseif bfid == LuauBuiltinFunction.LBF_VECTOR_CEIL then
            return 'vector.ceil'
        elseif bfid == LuauBuiltinFunction.LBF_VECTOR_ABS then
            return 'vector.abs'
        elseif bfid == LuauBuiltinFunction.LBF_VECTOR_SIGN then
            return 'vector.sign'
        elseif bfid == LuauBuiltinFunction.LBF_VECTOR_CLAMP then
            return 'vector.clamp'
        elseif bfid == LuauBuiltinFunction.LBF_VECTOR_MIN then
            return 'vector.min'
        elseif bfid == LuauBuiltinFunction.LBF_VECTOR_MAX then
            return 'vector.max'
        end
    end
end

local function prepare(t)
    local function reconstruct(original, fn)
        local new = {}

        for i, v in original do
            fn(new, i, v)
        end

        return new
    end

    local LuauOpCode = t.OpCode

    t.OpCode = reconstruct(LuauOpCode, function(self, i, v)
        local case = bit32.band((i - 1) * CASE_MULTIPLIER, 0xff)

        self[case] = v
    end)

    return t
end

return prepare(Luau)
