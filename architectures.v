namespace instructions

namespace shared {
	constant COMPARE = 'cmp'
	constant ADD = 'add'
	constant AND = 'and'
	constant MOVE = 'mov'
	constant NEGATE = 'neg'
	constant SUBTRACT = 'sub'
	constant RETURN = 'ret'
	constant NOP = 'nop'
}

namespace x64 {
	constant EVALUATE_MAX_MULTIPLIER = 8

	constant DOUBLE_PRECISION_ADD = 'addsd'
	constant DOUBLE_PRECISION_SUBTRACT = 'subsd'
	constant DOUBLE_PRECISION_MULTIPLY = 'mulsd'
	constant DOUBLE_PRECISION_DIVIDE = 'divsd'

	constant NOT = 'not'
	constant OR = 'or'
	constant XOR = 'xor'
	constant EVALUATE = 'lea'
	constant UNSIGNED_CONVERSION_MOVE = 'movzx'
	constant SIGNED_CONVERSION_MOVE = 'movsx'
	constant SIGNED_DWORD_CONVERSION_MOVE = 'movsxd'
	constant SHIFT_LEFT = 'sal'
	constant SHIFT_RIGHT = 'sar'
	constant SIGNED_MULTIPLY = 'imul'
	constant CALL = 'call'
	constant EXCHANGE = 'xchg'

	constant JUMP_ABOVE = 'ja'
	constant JUMP_ABOVE_OR_EQUALS = 'jae'
	constant JUMP_BELOW = 'jb'
	constant JUMP_BELOW_OR_EQUALS = 'jbe'
	constant JUMP_EQUALS = 'je'
	constant JUMP_GREATER_THAN = 'jg'
	constant JUMP_GREATER_THAN_OR_EQUALS = 'jge'
	constant JUMP_LESS_THAN = 'jl'
	constant JUMP_LESS_THAN_OR_EQUALS = 'jle'
	constant JUMP = 'jmp'
	constant JUMP_NOT_EQUALS = 'jne'
	constant JUMP_NOT_ZERO = 'jnz'
	constant JUMP_ZERO = 'jz'

	constant TEST = 'test'

	constant SIGNED_DIVIDE = 'idiv'
	constant EXTEND_QWORD = 'cqo'

	constant RAW_MEDIA_REGISTER_MOVE = 'movq'
	constant MEDIA_REGISTER_BITWISE_XOR = 'pxor'
	constant CONVERT_INTEGER_TO_DOUBLE_PRECISION = 'cvtsi2sd'
	constant CONVERT_DOUBLE_PRECISION_TO_INTEGER = 'cvtsd2si'
	constant DOUBLE_PRECISION_MOVE = 'movsd'

	constant PUSH = 'push'
	constant POP = 'pop'
}

namespace arm64 {
	constant NOT = 'mvn'
	constant DECIMAL_NEGATE = 'fneg'
	constant JUMP_LABEL = 'b'
	constant JUMP_REGISTER = 'blr'
}