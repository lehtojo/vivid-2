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

	constant XOR = 'xor'
	constant EVALUATE = 'lea'
	constant UNSIGNED_CONVERSION_MOVE = 'movzx'
	constant SIGNED_CONVERSION_MOVE = 'movsx'
	constant SIGNED_DWORD_CONVERSION_MOVE = 'movsxd'
}