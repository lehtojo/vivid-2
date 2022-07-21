namespace platform

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
	constant RAX = 0
	constant RCX = 1
	constant RDX = 2
	constant RBX = 3
	constant RSP = 4
	constant RBP = 5
	constant RSI = 6
	constant RDI = 7
	constant R8 = 8
	constant R9 = 9
	constant R10 = 10
	constant R11 = 11
	constant R12 = 12
	constant R13 = 13
	constant R14 = 14
	constant R15 = 15

	constant YMM0 = 0
	constant YMM1 = 1
	constant YMM2 = 2
	constant YMM3 = 3
	constant YMM4 = 4
	constant YMM5 = 5
	constant YMM6 = 6
	constant YMM7 = 7
	constant YMM8 = 8
	constant YMM9 = 9
	constant YMM10 = 10
	constant YMM11 = 11
	constant YMM12 = 12
	constant YMM13 = 13
	constant YMM14 = 14
	constant YMM15 = 15

	constant EVALUATE_MAX_MULTIPLIER = 8

	constant LOCK_PREFIX = 'lock'
	constant EXCHANGE_ADD = 'xadd'
	constant ATOMIC_EXCHANGE_ADD = 'lock xadd'

	constant DOUBLE_PRECISION_ADD = 'addsd'
	constant DOUBLE_PRECISION_SUBTRACT = 'subsd'
	constant DOUBLE_PRECISION_MULTIPLY = 'mulsd'
	constant DOUBLE_PRECISION_DIVIDE = 'divsd'
	constant DOUBLE_PRECISION_COMPARE = 'comisd'
	constant DOUBLE_PRECISION_XOR = 'xorpd'

	constant NOT = 'not'
	constant OR = 'or'
	constant XOR = 'xor'
	constant EVALUATE = 'lea'

	constant UNSIGNED_CONVERSION_MOVE = 'movzx'
	constant SIGNED_CONVERSION_MOVE = 'movsx'
	constant SIGNED_DWORD_CONVERSION_MOVE = 'movsxd'
	constant UNALIGNED_XMMWORD_MOVE = 'movups'

	constant SHIFT_LEFT = 'sal'
	constant SHIFT_RIGHT = 'sar'
	constant SHIFT_RIGHT_UNSIGNED = 'shr'
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

	constant SIGNED_MULTIPLY = 'imul'
	constant UNSIGNED_MULTIPLY = 'mul'

	constant SIGNED_DIVIDE = 'idiv'
	constant UNSIGNED_DIVIDE = 'div'

	constant EXTEND_QWORD = 'cqo'

	constant RAW_MEDIA_REGISTER_MOVE = 'movq'
	constant MEDIA_REGISTER_BITWISE_XOR = 'pxor'
	constant CONVERT_INTEGER_TO_DOUBLE_PRECISION = 'cvtsi2sd'
	constant CONVERT_DOUBLE_PRECISION_TO_INTEGER = 'cvttsd2si'
	constant DOUBLE_PRECISION_MOVE = 'movsd'

	constant PUSH = 'push'
	constant POP = 'pop'

	constant CONDITIONAL_MOVE_ABOVE = 'cmova'
	constant CONDITIONAL_MOVE_ABOVE_OR_EQUALS = 'cmovae'
	constant CONDITIONAL_MOVE_BELOW = 'cmovb'
	constant CONDITIONAL_MOVE_BELOW_OR_EQUALS = 'cmovbe'
	constant CONDITIONAL_MOVE_EQUALS = 'cmove'
	constant CONDITIONAL_MOVE_GREATER_THAN = 'cmovg'
	constant CONDITIONAL_MOVE_GREATER_THAN_OR_EQUALS = 'cmovge'
	constant CONDITIONAL_MOVE_LESS_THAN = 'cmovl'
	constant CONDITIONAL_MOVE_LESS_THAN_OR_EQUALS = 'cmovle'
	constant CONDITIONAL_MOVE_NOT_EQUALS = 'cmovne'
	constant CONDITIONAL_MOVE_NOT_ZERO = 'cmovnz'
	constant CONDITIONAL_MOVE_ZERO = 'cmovz'

	constant CONDITIONAL_SET_ABOVE = 'seta'
	constant CONDITIONAL_SET_ABOVE_OR_EQUALS = 'setae'
	constant CONDITIONAL_SET_BELOW = 'setb'
	constant CONDITIONAL_SET_BELOW_OR_EQUALS = 'setbe'
	constant CONDITIONAL_SET_EQUALS = 'sete'
	constant CONDITIONAL_SET_GREATER_THAN = 'setg'
	constant CONDITIONAL_SET_GREATER_THAN_OR_EQUALS = 'setge'
	constant CONDITIONAL_SET_LESS_THAN = 'setl'
	constant CONDITIONAL_SET_LESS_THAN_OR_EQUALS = 'setle'
	constant CONDITIONAL_SET_NOT_EQUALS = 'setne'
	constant CONDITIONAL_SET_NOT_ZERO = 'setnz'
	constant CONDITIONAL_SET_ZERO = 'setz'

	constant SYSTEM_CALL = 'syscall'

	# Parameterless instructions
	constant _RET = 0
	constant _LABEL = 1
	constant _CQO = 2
	constant _SYSCALL = 3
	constant _FLD1 = 4
	constant _FYL2x = 5
	constant _F2XM1 = 6
	constant _FADDP = 7
	constant _FCOS = 8
	constant _FSIN = 9
	constant _NOP = 10
	constant _MAX_PARAMETERLESS_INSTRUCTIONS = 11

	# Single parameter instructions
	constant _PUSH = 0
	constant _POP = 1
	constant _JA = 2
	# 3: imul
	constant _MUL = 4
	constant _IDIV = 5
	constant _DIV = 6
	constant _JAE = 7
	constant _JB = 8
	constant _JBE = 9
	constant _JE = 10
	constant _JG = 11
	constant _JGE = 12
	constant _JL = 13
	constant _JLE = 14
	constant _JMP = 15
	constant _JNE = 16
	constant _JNZ = 17
	constant _JZ = 18
	constant _CALL = 19
	constant _FILD = 20
	constant _FLD = 21
	constant _FISTP = 22
	constant _FSTP = 23
	constant _NEG = 24
	constant _NOT = 25
	constant _SETA = 26
	constant _SETAE = 27
	constant _SETB = 28
	constant _SETBE = 29
	constant _SETE = 30
	constant _SETG = 31
	constant _SETGE = 32
	constant _SETL = 33
	constant _SETLE = 34
	constant _SETNE = 35
	constant _SETNZ = 36
	constant _SETZ = 37
	constant _MAX_SINGLE_PARAMETER_INSTRUCTIONS = 38

	# Dual parameter instructions
	constant _MOV = 0
	constant _ADD = 1
	constant _SUB = 2
	constant _IMUL = 3 # Also in single and triple parameter instructions
	constant _SAL = 4
	constant _SAR = 5
	constant _MOVZX = 6
	constant _MOVSX = 7
	constant _MOVSXD = 8
	constant _LEA = 9
	constant _CMP = 10
	constant _ADDSD = 11
	constant _SUBSD = 12
	constant _MULSD = 13
	constant _DIVSD = 14
	constant _MOVSD = 15
	constant _MOVQ = 16
	constant _CVTSI2SD = 17
	constant _CVTTSD2SI = 18
	constant _AND = 19
	constant _XOR = 20
	constant _OR = 21
	constant _COMISD = 22
	constant _TEST = 23
	constant _MOVUPS = 24
	constant _SQRTSD = 25
	constant _XCHG = 26
	constant _PXOR = 27
	constant _SHR = 28
	constant _CMOVA = 29
	constant _CMOVAE = 30
	constant _CMOVB = 31
	constant _CMOVBE = 32
	constant _CMOVE = 33
	constant _CMOVG = 34
	constant _CMOVGE = 35
	constant _CMOVL = 36
	constant _CMOVLE = 37
	constant _CMOVNE = 38
	constant _CMOVNZ = 39
	constant _CMOVZ = 40
	constant _XORPD = 41
	constant _XADD = 42
	constant _MAX_DUAL_PARAMETER_INSTRUCTIONS = 43

	# Triple parameter instructions
	# 3: imul
	constant _MAX_TRIPLE_PARAMETER_INSTRUCTIONS = 4

	parameterless_encodings: List<List<InstructionEncoding>>
	single_parameter_encodings: List<List<InstructionEncoding>>
	dual_parameter_encodings: List<List<InstructionEncoding>>
	triple_parameter_encodings: List<List<InstructionEncoding>>

	create_conditional_move_encoding(operation: large) {
		return [
			# cmov** r64, r64 | cmov** r32, r32 | cmov r16, r16
			InstructionEncoding(operation, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 2, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(operation, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 4, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 4),
			InstructionEncoding(operation, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 8, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 8),

			# cmov** r64, m64 | cmov** r32, m32 | cmov r16, m16
			InstructionEncoding(operation, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(operation, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(operation, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),
		]
	}

	create_conditional_set_encoding(operation: large) {
		return [
			# set** r64 | set** r32 | set r16
			InstructionEncoding(operation, 0, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(operation, 0, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 4),
			InstructionEncoding(operation, 0, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_STANDARD_REGISTER, 0, 8),

			# set**  m64 | set** m32 | set m16
			InstructionEncoding(operation, 0, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(operation, 0, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(operation, 0, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),
		]
	}

	###
	initialize() {
		JumpInstruction.initialize()

		parameterless_encodings = List<List<InstructionEncoding>>()
		single_parameter_encodings = List<List<InstructionEncoding>>()
		dual_parameter_encodings = List<List<InstructionEncoding>>()
		triple_parameter_encodings = List<List<InstructionEncoding>>()

		loop (i = 0, i < _MAX_PARAMETERLESS_INSTRUCTIONS, i++) { parameterless_encodings.add(List<InstructionEncoding>()) }
		loop (i = 0, i < _MAX_SINGLE_PARAMETER_INSTRUCTIONS, i++) { single_parameter_encodings.add(List<InstructionEncoding>()) }
		loop (i = 0, i < _MAX_DUAL_PARAMETER_INSTRUCTIONS, i++) { dual_parameter_encodings.add(List<InstructionEncoding>()) }
		loop (i = 0, i < _MAX_TRIPLE_PARAMETER_INSTRUCTIONS, i++) { triple_parameter_encodings.add(List<InstructionEncoding>()) }
	}
	###

	initialize() {
		JumpInstruction.initialize()

		parameterless_encodings = List<List<InstructionEncoding>>()
		single_parameter_encodings = List<List<InstructionEncoding>>()
		dual_parameter_encodings = List<List<InstructionEncoding>>()
		triple_parameter_encodings = List<List<InstructionEncoding>>()

		loop (i = 0, i < _MAX_PARAMETERLESS_INSTRUCTIONS, i++) { parameterless_encodings.add(List<InstructionEncoding>()) }
		loop (i = 0, i < _MAX_SINGLE_PARAMETER_INSTRUCTIONS, i++) { single_parameter_encodings.add(List<InstructionEncoding>()) }
		loop (i = 0, i < _MAX_DUAL_PARAMETER_INSTRUCTIONS, i++) { dual_parameter_encodings.add(List<InstructionEncoding>()) }
		loop (i = 0, i < _MAX_TRIPLE_PARAMETER_INSTRUCTIONS, i++) { triple_parameter_encodings.add(List<InstructionEncoding>()) }

		parameterless_encodings[_RET] = [
			# ret
			InstructionEncoding(0xC3),
		]

		parameterless_encodings[_LABEL] = [
			InstructionEncoding(0x00, ENCODING_ROUTE_L, false),
		]

		parameterless_encodings[_CQO] = [
			InstructionEncoding(0x99, ENCODING_ROUTE_NONE, true),
		]

		parameterless_encodings[_SYSCALL] = [
			InstructionEncoding(0x050F, ENCODING_ROUTE_NONE, false),
		]

		parameterless_encodings[_FLD1] = [
			InstructionEncoding(0xE8D9, ENCODING_ROUTE_NONE, false),
		]

		parameterless_encodings[_FYL2x] = [
			InstructionEncoding(0xF1D9, ENCODING_ROUTE_NONE, false),
		]

		parameterless_encodings[_F2XM1] = [
			InstructionEncoding(0xF0D9, ENCODING_ROUTE_NONE, false),
		]

		parameterless_encodings[_FADDP] = [
			InstructionEncoding(0xC1DE, ENCODING_ROUTE_NONE, false),
		]

		parameterless_encodings[_FCOS] = [
			InstructionEncoding(0xFFD9, ENCODING_ROUTE_NONE, false),
		]

		parameterless_encodings[_FSIN] = [
			InstructionEncoding(0xFED9, ENCODING_ROUTE_NONE, false),
		]

		parameterless_encodings[_NOP] = [
			InstructionEncoding(0x90, ENCODING_ROUTE_NONE, false),
		]

		single_parameter_encodings[_PUSH] = [
			# push r64, push r16
			InstructionEncoding(0x50, 0, ENCODING_ROUTE_O, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x50, 0, ENCODING_ROUTE_O, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8),
		]

		single_parameter_encodings[_POP] = [
			# pop r64, pop r16
			InstructionEncoding(0x58, 0, ENCODING_ROUTE_O, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x58, 0, ENCODING_ROUTE_O, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8),
		]

		single_parameter_encodings[_IMUL] = [
			# imul r64 | imul r32 | imul r16 | imul r8
			InstructionEncoding(0xF6, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0xF7, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0xF7, 5, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8),
		]

		single_parameter_encodings[_DIV] = [
			# div r64 | div r32 | div r16 | div r8
			InstructionEncoding(0xF6, 6, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0xF7, 6, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 6, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0xF7, 6, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# div m64 | div m32 | div m16 | div m8
			InstructionEncoding(0xF6, 6, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0xF7, 6, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 6, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0xF7, 6, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),
		]

		single_parameter_encodings[_JA] = [ InstructionEncoding(0x870F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]
		single_parameter_encodings[_JAE] = [ InstructionEncoding(0x830F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]
		single_parameter_encodings[_JB] = [ InstructionEncoding(0x820F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]
		single_parameter_encodings[_JBE] = [ InstructionEncoding(0x860F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]
		single_parameter_encodings[_JE] = [ InstructionEncoding(0x840F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]
		single_parameter_encodings[_JG] = [ InstructionEncoding(0x8F0F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]
		single_parameter_encodings[_JGE] = [ InstructionEncoding(0x8D0F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]
		single_parameter_encodings[_JL] = [ InstructionEncoding(0x8C0F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]
		single_parameter_encodings[_JLE] = [ InstructionEncoding(0x8E0F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]
		single_parameter_encodings[_JNE] = [ InstructionEncoding(0x850F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]
		single_parameter_encodings[_JNZ] = [ InstructionEncoding(0x850F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]
		single_parameter_encodings[_JZ] = [ InstructionEncoding(0x840F, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8) ]

		single_parameter_encodings[_JMP] = [
			InstructionEncoding(0xE9, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8),
			InstructionEncoding(0xFF, 4, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8),
			InstructionEncoding(0xFF, 4, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),
		]

		single_parameter_encodings[_CALL] = [
			# call label
			InstructionEncoding(0xE8, 0, ENCODING_ROUTE_D, false, ENCODING_FILTER_TYPE_LABEL, 0, 8),

			# call r64
			InstructionEncoding(0xFF, 2, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# call m64
			InstructionEncoding(0xFF, 2, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8)
		]

		single_parameter_encodings[_FILD] = [ InstructionEncoding(0xDF, 5, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8) ]
		single_parameter_encodings[_FLD] = [ InstructionEncoding(0xDD, 0, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8) ]
		single_parameter_encodings[_FISTP] = [ InstructionEncoding(0xDF, 7, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8) ]
		single_parameter_encodings[_FSTP] = [ InstructionEncoding(0xDD, 3, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8) ]

		single_parameter_encodings[_NEG] = [
			# neg r64 | neg r32 | neg r16 | neg r8
			InstructionEncoding(0xF6, 3, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0xF7, 3, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 3, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0xF7, 3, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# neg m64 | neg m32 | neg m16 | neg m8
			InstructionEncoding(0xF6, 3, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0xF7, 3, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 3, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0xF7, 3, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),
		]

		single_parameter_encodings[_NOT] = [
			# not r64 | not r32 | not r16 | not r8
			InstructionEncoding(0xF6, 2, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0xF7, 2, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 2, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0xF7, 2, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# not m64 | not m32 | not m16 | not m8
			InstructionEncoding(0xF6, 2, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0xF7, 2, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 2, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0xF7, 2, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8),
		]

		single_parameter_encodings[_SETA] = create_conditional_set_encoding(0x970F)
		single_parameter_encodings[_SETAE] = create_conditional_set_encoding(0x930F)
		single_parameter_encodings[_SETB] = create_conditional_set_encoding(0x920F)
		single_parameter_encodings[_SETBE] = create_conditional_set_encoding(0x960F)
		single_parameter_encodings[_SETE] = create_conditional_set_encoding(0x940F)
		single_parameter_encodings[_SETG] =  create_conditional_set_encoding(0x9F0F)
		single_parameter_encodings[_SETGE] = create_conditional_set_encoding(0x9D0F)
		single_parameter_encodings[_SETL] = create_conditional_set_encoding(0x9C0F)
		single_parameter_encodings[_SETLE] = create_conditional_set_encoding(0x9E0F)
		single_parameter_encodings[_SETNE] = create_conditional_set_encoding(0x950F)
		single_parameter_encodings[_SETNZ] = create_conditional_set_encoding(0x950F)
		single_parameter_encodings[_SETZ] =  create_conditional_set_encoding(0x940F)

		dual_parameter_encodings[_MOV] = [
			# mov r64, r64 | mov r32, r32 | mov r16, r16 | mov r8, r8
			InstructionEncoding(0x8A, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x8B, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x8B, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x8B, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# mov m64, r64 | mov m32, r32 | mov m16, r16 | mov m8, r8
			InstructionEncoding(0x88, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x89, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x89, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x89, 0, ENCODING_ROUTE_MR, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# mov r64, m64 | mov r32, m32 | mov r16, m16 | mov r8, m8
			InstructionEncoding(0x8A, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0x8B, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x8B, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0x8B, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),

			# mov r64, c32
			InstructionEncoding(0xC7, 0, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# mov r64, c64 | mov r32, c32 | mov r16, c16 | mov r8, c8
			InstructionEncoding(0xB0, 0, ENCODING_ROUTE_OC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_SIGNLESS_CONSTANT, 0, 1),
			InstructionEncoding(0xB8, 0, ENCODING_ROUTE_OC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_SIGNLESS_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xB8, 0, ENCODING_ROUTE_OC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_SIGNLESS_CONSTANT, 0, 4),
			InstructionEncoding(0xB8, 0, ENCODING_ROUTE_OC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_SIGNLESS_CONSTANT, 0, 8),

			# mov m64, c32 | mov m32, c32 | mov m16, c16 | mov m8, c8
			InstructionEncoding(0xC6, 0, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_SIGNLESS_CONSTANT, 0, 1),
			InstructionEncoding(0xC7, 0, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_SIGNLESS_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xC7, 0, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_SIGNLESS_CONSTANT, 0, 4),
			InstructionEncoding(0xC7, 0, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_SIGNLESS_CONSTANT, 0, 4),
		]

		dual_parameter_encodings[_ADD] = [
			# add r64, c8 | add r32, c8 | add r16, c8
			InstructionEncoding(0x83, 0, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x83, 0, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x83, 0, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# add rax, c32 | add eax, c32 | add ax, c16 | add al, c8
			InstructionEncoding(0x04, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, RAX, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x05, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, RAX, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x05, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, RAX, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x05, 0, ENCODING_ROUTE_SC, true, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, RAX, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# add r64, c32 | add r32, c32 | add r16, c16 | add r8, c8
			InstructionEncoding(0x80, 0, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 0, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 0, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 0, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# add m64, c32 | add m32, c32 | add m16, c16 | add m8, c8
			InstructionEncoding(0x80, 0, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 0, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 0, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 0, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# add r64, r64 | add r32, r32 | add r16, r16 | add r8, r8
			InstructionEncoding(0x02, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x03, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x03, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x03, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# add m64, r64 | add m32, r32 | add m16, r16 | add m8, r8
			InstructionEncoding(0x00, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x01, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x01, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x01, 0, ENCODING_ROUTE_MR, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# add r64, m64 | add r32, m32 | add r16, m16 | add r8, m8
			InstructionEncoding(0x02, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0x03, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x03, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0x03, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),
		]

		dual_parameter_encodings[_SUB] = [
			# sub r64, c8 | sub r32, c8 | sub r16, c8
			InstructionEncoding(0x83, 5, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x83, 5, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x83, 5, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# sub rax, c32 | sub eax, c32 | sub ax, c16 | sub al, c8
			InstructionEncoding(0x2C, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, RAX, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x2D, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, RAX, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x2D, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, RAX, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x2D, 0, ENCODING_ROUTE_SC, true, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, RAX, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# sub r64, c32 | sub r32, c32 | sub r16, c16 | sub r8, c8
			InstructionEncoding(0x80, 5, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 5, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 5, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 5, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# sub m64, c32 | sub m32, c32 | sub m16, c16 | sub m8, c8
			InstructionEncoding(0x80, 5, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 5, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 5, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 5, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# sub r64, r64 | sub r32, r32 | sub r16, r16 | sub r8, r8
			InstructionEncoding(0x2A, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x2B, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x2B, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x2B, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# sub m64, r64 | sub m32, r32 | sub m16, r16 | sub m8, r8
			InstructionEncoding(0x28, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x29, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x29, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x29, 0, ENCODING_ROUTE_MR, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),
		
			# sub r64, m64 | sub r32, m32 | sub r16, m16 | sub r8, m8
			InstructionEncoding(0x2A, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0x2B, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x2B, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0x2B, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),
		]

		dual_parameter_encodings[_IMUL] = [
			# imul r64 | imul r32 | imul r16 | imul r8
			InstructionEncoding(0xF6, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0xF7, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0xF7, 5, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# imul m64 | imul m32 | imul m16 | imul m8
			InstructionEncoding(0xF6, 5, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0xF7, 5, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 5, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0xF7, 5, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),

			# imul r64, m64 | imul r32, m32 | imul r16, m16
			InstructionEncoding(0xAF0F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xAF0F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0xAF0F, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# imul r64, m64 | imul r32, m32 | imul r16, m16
			InstructionEncoding(0xAF0F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xAF0F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0xAF0F, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),

			# imul r64, c8 | imul r32, c8 | imul r16, c8
			InstructionEncoding(0x6B, 0, ENCODING_ROUTE_DRC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x6B, 0, ENCODING_ROUTE_DRC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x6B, 0, ENCODING_ROUTE_DRC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# imul r64, c32 | imul r32, c32 | imul r16, c16
			InstructionEncoding(0x69, 0, ENCODING_ROUTE_DRC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x69, 0, ENCODING_ROUTE_DRC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x69, 0, ENCODING_ROUTE_DRC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
		]

		single_parameter_encodings[_MUL] = [
			# mul r64 | mul r32 | mul r16 | mul r8
			InstructionEncoding(0xF6, 4, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0xF7, 4, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 4, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0xF7, 4, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# mul m64 | mul m32 | mul m16 | mul m8
			InstructionEncoding(0xF6, 4, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0xF7, 4, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 4, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0xF7, 4, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),
		]

		single_parameter_encodings[_IDIV] = [
			# idiv r64 | idiv r32 | idiv r16 | idiv r8
			InstructionEncoding(0xF6, 7, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0xF7, 7, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 7, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0xF7, 7, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# idiv m64 | idiv m32 | idiv m16 | idiv m8
			InstructionEncoding(0xF6, 7, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0xF7, 7, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xF7, 7, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0xF7, 7, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),
		]

		dual_parameter_encodings[_SAL] = [
			# sal r64, 1 | sal r32, 1 | sal r16, 1 | sal r8, 1
			InstructionEncoding(0xD0, 4, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 1),
			InstructionEncoding(0xD1, 4, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD1, 4, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 4),
			InstructionEncoding(0xD1, 4, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 8),

			# sal m64, 1 | sal m32, 1 | sal m16, 1 | sal m8, 1
			InstructionEncoding(0xD0, 4, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 1),
			InstructionEncoding(0xD1, 4, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD1, 4, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 4),
			InstructionEncoding(0xD1, 4, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 8),

			# sal r64, c8 | sal r32, c8 | sal r16, c8 | sal r8, c8
			InstructionEncoding(0xC0, 4, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 4, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xC1, 4, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 4, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# sal m64, c8 | sal m32, c8 | sal m16, c8 | sal m8, c8
			InstructionEncoding(0xC0, 4, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 4, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xC1, 4, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 4, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# sal r64, cl | sal r32, cl | sal r16, cl | sal r8, cl
			InstructionEncoding(0xD2, 4, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),
			InstructionEncoding(0xD3, 4, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD3, 4, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),
			InstructionEncoding(0xD3, 4, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),

			# sal m64, cl | sal m32, cl | sal m16, cl | sal m8, cl
			InstructionEncoding(0xD2, 4, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),
			InstructionEncoding(0xD3, 4, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD3, 4, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),
			InstructionEncoding(0xD3, 4, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),
		]

		dual_parameter_encodings[_SAR] = [
			# sar r64, 1 | sar r32, 1 | sar r16, 1 | sar r8, 1
			InstructionEncoding(0xD0, 7, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 1),
			InstructionEncoding(0xD1, 7, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD1, 7, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 4),
			InstructionEncoding(0xD1, 7, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 8),

			# sar m64, 1 | sar m32, 1 | sar m16, 1 | sar m8, 1
			InstructionEncoding(0xD0, 7, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 1),
			InstructionEncoding(0xD1, 7, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD1, 7, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 4),
			InstructionEncoding(0xD1, 7, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 8),

			# sar r64, c8 | sar r32, c8 | sar r16, c8 | sar r8, c8
			InstructionEncoding(0xC0, 7, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 7, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xC1, 7, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 7, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# sar m64, c8 | sar m32, c8 | sar m16, c8 | sar m8, c8
			InstructionEncoding(0xC0, 7, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 7, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xC1, 7, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 7, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# sar r64, cl | sar r32, cl | sar r16, cl | sar r8, cl
			InstructionEncoding(0xD2, 7, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),
			InstructionEncoding(0xD3, 7, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD3, 7, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),
			InstructionEncoding(0xD3, 7, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),

			# sar m64, cl | sar m32, cl | sar m16, cl | sar m8, cl
			InstructionEncoding(0xD2, 7, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),
			InstructionEncoding(0xD3, 7, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD3, 7, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 4),
			InstructionEncoding(0xD3, 7, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 8),
		]

		dual_parameter_encodings[_MOVZX] = [
			# movzx r16, r8
			InstructionEncoding(0xB60F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),

			# movzx r16, m8
			InstructionEncoding(0xB60F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),

			# movzx r32, r8
			InstructionEncoding(0xB60F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 1),

			# movzx r32, m8
			InstructionEncoding(0xB60F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),

			# movzx r64, r8
			InstructionEncoding(0xB60F, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 1),

			# movzx r64, m8
			InstructionEncoding(0xB60F, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),

			# movzx r32, r16
			InstructionEncoding(0xB70F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 2),

			# movzx r32, m16
			InstructionEncoding(0xB70F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2),

			# movzx r64, r16
			InstructionEncoding(0xB70F, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 2),

			# movzx r64, m16
			InstructionEncoding(0xB70F, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2),
		]

		dual_parameter_encodings[_MOVSX] = [
			# movsx r16, r8
			InstructionEncoding(0xBE0F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),

			# movsx r16, m8
			InstructionEncoding(0xBE0F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),

			# movsx r32, r8
			InstructionEncoding(0xBE0F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 1),

			# movsx r32, m8
			InstructionEncoding(0xBE0F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),

			# movsx r64, r8
			InstructionEncoding(0xBE0F, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 1),

			# movsx r64, m8
			InstructionEncoding(0xBE0F, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),

			# movsx r32, r16
			InstructionEncoding(0xBF0F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 2),

			# movsx r32, m16
			InstructionEncoding(0xBF0F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2),

			# movsx r64, r16
			InstructionEncoding(0xBF0F, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 2),

			# movsx r64, m16
			InstructionEncoding(0xBF0F, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2),
		]

		dual_parameter_encodings[_MOVSXD] = [
			# movsxd r64, r32
			InstructionEncoding(0x63, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 4),

			# movsxd r64, m32
			InstructionEncoding(0x63, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
		]

		dual_parameter_encodings[_LEA] = [
			# lea r16, e
			InstructionEncoding(0x8D, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_EXPRESSION, 0, 8, instruction_encoder.OPERAND_SIZE_OVERRIDE),

			# lea r32, e
			InstructionEncoding(0x8D, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_EXPRESSION, 0, 8),

			# lea r64, e
			InstructionEncoding(0x8D, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_EXPRESSION, 0, 8),

			# lea r16, m16
			InstructionEncoding(0x8D, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, instruction_encoder.OPERAND_SIZE_OVERRIDE),

			# lea r32, m32
			InstructionEncoding(0x8D, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),

			# lea r64, m64
			InstructionEncoding(0x8D, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),
		]

		dual_parameter_encodings[_CMP] = [
			# cmp rax, c32, cmp eax, c32, cmp ax, c16, cmp al, c8
			InstructionEncoding(0x3C, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x3D, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x3D, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x3D, 0, ENCODING_ROUTE_SC, true, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# cmp r64, c32, cmp r32, c32, cmp r16, c16, cmp r8, c8
			InstructionEncoding(0x80, 7, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 7, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 7, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 7, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# cmp m64, c32, cmp m32, c32, cmp m16, c16, cmp m8, c8
			InstructionEncoding(0x80, 7, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 7, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 7, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 7, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# cmp r64, r64, cmp r32, r32, cmp r16, r16, cmp r8, r8
			InstructionEncoding(0x3A, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x3B, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x3B, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x3B, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# cmp m64, r64, cmp m32, r32, cmp m16, r16, cmp m8, r8
			InstructionEncoding(0x38, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x39, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x39, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x39, 0, ENCODING_ROUTE_MR, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# cmp r64, m64, cmp r32, m32, cmp r16, m16, cmp r8, m8
			InstructionEncoding(0x3A, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0x3B, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x3B, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0x3B, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),
		]

		dual_parameter_encodings[_ADDSD] = [
			# addsd x, x
			InstructionEncoding(0x580F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, 0xF2),

			# addsd x, m64
			InstructionEncoding(0x580F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, 0xF2),
		]

		dual_parameter_encodings[_SUBSD] = [
			# subsd x, x
			InstructionEncoding(0x5C0F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, 0xF2),

			# subsd x, m64
			InstructionEncoding(0x5C0F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, 0xF2),
		]

		dual_parameter_encodings[_MULSD] = [
			# mulsd x, x
			InstructionEncoding(0x590F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, 0xF2),

			# mulsd x, m64
			InstructionEncoding(0x590F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, 0xF2),
		]

		dual_parameter_encodings[_DIVSD] = [
			# divsd x, x
			InstructionEncoding(0x5E0F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, 0xF2),

			# divsd x, m64
			InstructionEncoding(0x5E0F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, 0xF2),
		]

		dual_parameter_encodings[_MOVSD] = [
			# movsd x, x
			InstructionEncoding(0x100F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, 0xF2),

			# movsd x, m64
			InstructionEncoding(0x100F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, 0xF2),

			# movsd m64, x
			InstructionEncoding(0x110F, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, 0xF2),
		]

		dual_parameter_encodings[_MOVUPS] = [
			# movups x, m128
			InstructionEncoding(0x100F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 16, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 16),

			# movups m128, x
			InstructionEncoding(0x110F, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 16, ENCODING_FILTER_TYPE_REGISTER, 0, 16),

			# movups x, m128
			InstructionEncoding(0x100F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 16),

			# movups m128, x
			InstructionEncoding(0x110F, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 16, ENCODING_FILTER_TYPE_REGISTER, 0, 8),
		]

		dual_parameter_encodings[_MOVQ] = [
			# movq x, r64
			InstructionEncoding(0x6E0F, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_MEDIA_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, 0x66),

			# movq x, m64
			InstructionEncoding(0x6E0F, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_MEDIA_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, 0x66),

			# movq r64, x
			InstructionEncoding(0x7E0F, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEDIA_REGISTER, 0, 8, 0x66),

			# movq m64, x
			InstructionEncoding(0x7E0F, 0, ENCODING_ROUTE_MR, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_MEDIA_REGISTER, 0, 8, 0x66),
		]

		dual_parameter_encodings[_CVTSI2SD] = [
			# cvtsi2sd x, r64
			InstructionEncoding(0x2A0F, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, 0xF2),

			# cvtsi2sd x, m64
			InstructionEncoding(0x2A0F, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, 0xF2),
		]

		dual_parameter_encodings[_CVTTSD2SI] = [
			# cvttsd2si r, x
			InstructionEncoding(0x2C0F, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, 0xF2),

			# cvttsd2si r, m64
			InstructionEncoding(0x2C0F, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, 0xF2),
		]

		dual_parameter_encodings[_AND] = [
			# and rax, c32 | and eax, c32 | and ax, c16 | and al, c8
			InstructionEncoding(0x24, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x25, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x25, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x25, 0, ENCODING_ROUTE_SC, true, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# and r64, c8 | and r32, c8 | and r16, c8
			InstructionEncoding(0x83, 4, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x83, 4, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x83, 4, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# and m64, c8 | and m32, c8 | and m16, c8
			InstructionEncoding(0x83, 4, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x83, 4, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x83, 4, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# and r64, c32 | and r32, c32 | and r16, c16 | and r8, c8
			InstructionEncoding(0x80, 4, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 4, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 4, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 4, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# and m64, c32 | and m32, c32 | and m16, c16 | and m8, c8
			InstructionEncoding(0x80, 4, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 4, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 4, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 4, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# and r64, r64 | and r32, r32 | and r16, r16 | and r8, r8
			InstructionEncoding(0x22, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x23, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x23, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x23, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# and m64, r64 | and m32, r32 | and m16, r16 | and m8, r8
			InstructionEncoding(0x20, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x21, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x21, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x21, 0, ENCODING_ROUTE_MR, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# and r64, m64 | and r32, m32 | and r16, m16 | and r8, m8
			InstructionEncoding(0x22, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0x23, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x23, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0x23, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8)
		]

		dual_parameter_encodings[_XOR] = [
			# xor rax, c32 | xor eax, c32 | xor ax, c16 | xor al, c8
			InstructionEncoding(0x34, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x35, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x35, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x35, 0, ENCODING_ROUTE_SC, true, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# xor r64, c8 | xor r32, c8 | xor r16, c8
			InstructionEncoding(0x83, 6, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x83, 6, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x83, 6, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# xor m64, c8 | xor m32, c8 | xor m16, c8
			InstructionEncoding(0x83, 6, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x83, 6, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x83, 6, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# xor r64, c32 | xor r32, c32 | xor r16, c16 | xor r8, c8
			InstructionEncoding(0x80, 6, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 6, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 6, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 6, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# xor m64, c32 | xor m32, c32 | xor m16, c16 | xor m8, c8
			InstructionEncoding(0x80, 6, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 6, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 6, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 6, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# xor r64, r64 | xor r32, r32 | xor r16, r16 | xor r8, r8
			InstructionEncoding(0x32, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x33, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x33, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x33, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# xor m64, r64 | xor m32, r32 | xor m16, r16 | xor m8, r8
			InstructionEncoding(0x30, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x31, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x31, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x31, 0, ENCODING_ROUTE_MR, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# xor r64, m64 | xor r32, m32 | xor r16, m16 | xor r8, m8
			InstructionEncoding(0x32, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0x33, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x33, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0x33, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8)
		]

		dual_parameter_encodings[_OR] = [
			# or rax, c32 | or eax, c32 | or ax, c16 | or al, c8
			InstructionEncoding(0x0C, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x0D, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x0D, 0, ENCODING_ROUTE_SC, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x0D, 0, ENCODING_ROUTE_SC, true, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# or r64, c8 | or r32, c8 | or r16, c8
			InstructionEncoding(0x83, 1, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x83, 1, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x83, 1, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# or m64, c8 | or m32, c8 | or m16, c8
			InstructionEncoding(0x83, 1, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x83, 1, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x83, 1, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# or r64, c32 | or r32, c32 | or r16, c16 | or r8, c8
			InstructionEncoding(0x80, 1, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 1, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 1, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 1, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# or m64, c32 | or m32, c32 | or m16, c16 | or m8, c8
			InstructionEncoding(0x80, 1, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x81, 1, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x81, 1, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x81, 1, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# or r64, r64 | or r32, r32 | or r16, r16 | or r8, r8
			InstructionEncoding(0x0A, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x0B, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x0B, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x0B, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# or m64, r64 | or m32, r32 | or m16, r16 | or m8, r8
			InstructionEncoding(0x08, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x09, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x09, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x09, 0, ENCODING_ROUTE_MR, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# or r64, m64 | or r32, m32 | or r16, m16 | or r8, m8
			InstructionEncoding(0x0A, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0x0B, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x0B, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0x0B, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8)
		]

		dual_parameter_encodings[_COMISD] = [
			# comisd x, x
			InstructionEncoding(0x2F0F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_MEDIA_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEDIA_REGISTER, 0, 8, 0x66),

			# comisd x, m
			InstructionEncoding(0x2F0F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_MEDIA_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, 0x66),
		]

		dual_parameter_encodings[_TEST] = [
			# test r64, r64 | test r32, r32 | test r16, r16 | test r8, r8
			InstructionEncoding(0x84, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x85, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x85, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x85, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),
		]

		dual_parameter_encodings[_SQRTSD] = [
			# sqrtsd x, x
			InstructionEncoding(0x510F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, 0xF2),
		]

		dual_parameter_encodings[_XCHG] = [
			# xchg rax, r64 | xchg eax, r32 | xchg ax, r16
			InstructionEncoding(0x90, 0, ENCODING_ROUTE_SO, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x90, 0, ENCODING_ROUTE_SO, false, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x90, 0, ENCODING_ROUTE_SO, true, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# xchg r64, rax | xchg r32, eax | xchg r16, ax
			InstructionEncoding(0x90, 0, ENCODING_ROUTE_O, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x90, 0, ENCODING_ROUTE_O, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 4),
			InstructionEncoding(0x90, 0, ENCODING_ROUTE_O, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RAX, 8),

			# xchg r64, r64 | xchg r32, r32 | xchg r16, r16 | xchg r8, r8
			InstructionEncoding(0x86, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x87, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x87, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x87, 0, ENCODING_ROUTE_RR, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),

			# xchg r64, m64, xchg r32, m32, xchg r16, m16, xchg r8, m8
			InstructionEncoding(0x86, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1),
			InstructionEncoding(0x87, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x87, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4),
			InstructionEncoding(0x87, 0, ENCODING_ROUTE_RM, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8),

			# xchg m64, r64, xchg m32, r32, xchg m16, r16, xchg m8, r8
			InstructionEncoding(0x86, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0x87, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x87, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0x87, 0, ENCODING_ROUTE_MR, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),
		]

		dual_parameter_encodings[_PXOR] = [
			# pxor x, x
			InstructionEncoding(0xEF0F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, 0x66),
		]

		dual_parameter_encodings[_SHR] = [
			# shr r64, 1 | shr r32, 1 | shr r16, 1 | shr r8, 1
			InstructionEncoding(0xD0, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 1),
			InstructionEncoding(0xD1, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD1, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 4),
			InstructionEncoding(0xD1, 5, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 8),

			# shr m64, 1 | shr m32, 1 | shr m16, 1 | shr m8, 1
			InstructionEncoding(0xD0, 5, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 1),
			InstructionEncoding(0xD1, 5, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD1, 5, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 4),
			InstructionEncoding(0xD1, 5, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT, 1, 8),

			# shr r64, c8 | shr r32, c8 | shr r16, c8 | shr r8, c8
			InstructionEncoding(0xC0, 5, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 5, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xC1, 5, ENCODING_ROUTE_RC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 5, ENCODING_ROUTE_RC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# shr m64, c8 | shr m32, c8 | shr m16, c8 | shr m8, c8
			InstructionEncoding(0xC0, 5, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 5, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xC1, 5, ENCODING_ROUTE_MC, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0xC1, 5, ENCODING_ROUTE_MC, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# shr r64, cl | shr r32, cl | shr r16, cl | shr r8, cl
			InstructionEncoding(0xD2, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),
			InstructionEncoding(0xD3, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD3, 5, ENCODING_ROUTE_R, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 4),
			InstructionEncoding(0xD3, 5, ENCODING_ROUTE_R, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 8),

			# shr m64, cl | shr m32, cl | shr m16, cl | shr m8, cl
			InstructionEncoding(0xD2, 5, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 1),
			InstructionEncoding(0xD3, 5, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xD3, 5, ENCODING_ROUTE_M, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 4),
			InstructionEncoding(0xD3, 5, ENCODING_ROUTE_M, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_SPECIFIC_REGISTER, platform.x64.RCX, 8),
		]

		dual_parameter_encodings[_CMOVA] = create_conditional_move_encoding(0x470F)
		dual_parameter_encodings[_CMOVAE] = create_conditional_move_encoding(0x430F)
		dual_parameter_encodings[_CMOVB] = create_conditional_move_encoding(0x420F)
		dual_parameter_encodings[_CMOVBE] = create_conditional_move_encoding(0x460F)
		dual_parameter_encodings[_CMOVE] = create_conditional_move_encoding(0x440F)
		dual_parameter_encodings[_CMOVG] = create_conditional_move_encoding(0x4F0F)
		dual_parameter_encodings[_CMOVGE] = create_conditional_move_encoding(0x4D0F)
		dual_parameter_encodings[_CMOVL] = create_conditional_move_encoding(0x4C0F)
		dual_parameter_encodings[_CMOVLE] = create_conditional_move_encoding(0x4E0F)
		dual_parameter_encodings[_CMOVNE] = create_conditional_move_encoding(0x450F)
		dual_parameter_encodings[_CMOVNZ] = create_conditional_move_encoding(0x450F)
		dual_parameter_encodings[_CMOVZ] = create_conditional_move_encoding(0x440F)

		dual_parameter_encodings[_XORPD] = [
			# xorpd x, x
			InstructionEncoding(0x570F, 0, ENCODING_ROUTE_RR, false, ENCODING_FILTER_TYPE_MEDIA_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEDIA_REGISTER, 0, 8, 0x66),

			# xorpd x, m128
			InstructionEncoding(0x570F, 0, ENCODING_ROUTE_RM, false, ENCODING_FILTER_TYPE_MEDIA_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 16, 0x66),
		]

		dual_parameter_encodings[_XADD] = [
			# xadd m64, r64 | xadd m32, r32 | xadd m16, r16 | xadd m8, r8
			InstructionEncoding(0xC00F, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 1, ENCODING_FILTER_TYPE_REGISTER, 0, 1),
			InstructionEncoding(0xC10F, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0xC10F, 0, ENCODING_ROUTE_MR, false, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4),
			InstructionEncoding(0xC10F, 0, ENCODING_ROUTE_MR, true, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8),
		]

		triple_parameter_encodings[_IMUL] = [
			# imul r64, r64, c8 | imul r32, r32, c8 | imul r16, r16, c8
			InstructionEncoding(0x6B, 0, ENCODING_ROUTE_RRC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x6B, 0, ENCODING_ROUTE_RRC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x6B, 0, ENCODING_ROUTE_RRC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# imul r64, m64, c8 | imul r32, m32, c8 | imul r16, m16, c8
			InstructionEncoding(0x6B, 0, ENCODING_ROUTE_RMC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 1, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x6B, 0, ENCODING_ROUTE_RMC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),
			InstructionEncoding(0x6B, 0, ENCODING_ROUTE_RMC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 1),

			# imul r64, r64, c32 | imul r32, r32, c32 | imul r16, r16, c16
			InstructionEncoding(0x69, 0, ENCODING_ROUTE_RRC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x69, 0, ENCODING_ROUTE_RRC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x69, 0, ENCODING_ROUTE_RRC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),

			# imul r64, m64, c32 | imul r32, m32, c32 | imul r16, m16, c16
			InstructionEncoding(0x69, 0, ENCODING_ROUTE_RMC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 2, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 2, ENCODING_FILTER_TYPE_CONSTANT, 0, 2, instruction_encoder.OPERAND_SIZE_OVERRIDE),
			InstructionEncoding(0x69, 0, ENCODING_ROUTE_RMC, false, ENCODING_FILTER_TYPE_REGISTER, 0, 4, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 4, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
			InstructionEncoding(0x69, 0, ENCODING_ROUTE_RMC, true, ENCODING_FILTER_TYPE_REGISTER, 0, 8, ENCODING_FILTER_TYPE_MEMORY_ADDRESS, 0, 8, ENCODING_FILTER_TYPE_CONSTANT, 0, 4),
		]
	}
}

namespace arm64 {
	constant NOT = 'mvn'
	constant DECIMAL_NEGATE = 'fneg'
	constant CALL = 'bl'
	constant JUMP_LABEL = 'b'
	constant JUMP_REGISTER = 'blr'

	constant SHIFT_LEFT = 'lsl'
	constant SHIFT_RIGHT = 'asr'
}