namespace expression_optimizer

constant COMPONENT_TYPE_NONE: tiny = 0
constant COMPONENT_TYPE_COMPLEX: tiny = 1
constant COMPONENT_TYPE_NUMBER: tiny = 2
constant COMPONENT_TYPE_VARIABLE: tiny = 4
constant COMPONENT_TYPE_VARIABLE_PRODUCT: tiny = 8

Component {
	type: tiny = COMPONENT_TYPE_NONE

	is_complex => type == COMPONENT_TYPE_COMPLEX
	is_number => type == COMPONENT_TYPE_NUMBER
	is_variable => type == COMPONENT_TYPE_VARIABLE
	is_variable_product => type == COMPONENT_TYPE_VARIABLE_PRODUCT

	is_one() {
		=> is_number and this.(NumberComponent).value.is_one()
	}

	is_zero() {
		=> is_number and this.(NumberComponent).value.data == 0
	}

	static add_numbers(c1: large, c2: large, is_c1_decimal: bool, is_c2_decimal: bool) {
		if is_c1_decimal {
			if is_c2_decimal => pack { data: decimal_to_bits(bits_to_decimal(c1) + bits_to_decimal(c2)), is_decimal: true }
			=> pack { data: decimal_to_bits(bits_to_decimal(c1) + c2), is_decimal: true }
		}

		if is_c2_decimal => pack { data: decimal_to_bits(c1 + bits_to_decimal(c2)), is_decimal: true }
		=> pack { data: c1 + c2, is_decimal: false }
	}

	virtual negation()

	virtual addition(other: Component): Component {
		=> none as Component
	}

	virtual subtraction(other: Component): Component {
		=> none as Component
	}

	virtual multiplication(other: Component): Component {
		=> none as Component
	}

	virtual division(other: Component): Component {
		=> none as Component
	}

	virtual bitwise_and(other: Component): Component {
		=> none as Component
	}

	virtual bitwise_xor(other: Component): Component {
		=> none as Component
	}

	virtual bitwise_or(other: Component): Component {
		=> none as Component
	}

	virtual equals(other: Component): bool
	virtual clone(): Component

	plus(other: Component) {
		=> addition(other)
	}

	minus(other: Component) {
		=> subtraction(other)
	}

	times(other: Component) {
		=> multiplication(other)
	}

	divide(other: Component) {
		=> division(other)
	}
}

pack Number {
	data: large
	is_decimal: bool

	is_integer() {
		=> not is_decimal
	}

	format() {
		if is_decimal => FORMAT_DECIMAL
		=> SYSTEM_FORMAT
	}

	is_zero() {
		=> data == 0
	}

	is_one() {
		if is_decimal => bits_to_decimal(data) == 1.0
		=> data == 1
	}

	is_negative() {
		if is_decimal => bits_to_decimal(data) < 0.0
		=> data < 0
	}

	absolute() {
		if is_decimal => data & 0x7FFFFFFFFFFFFFFF # Set the last bit to zero
		=> abs(data)
	}

	plus(other: Number) {
		result: Number
		result.data = 0
		result.is_decimal = false

		if is_decimal {
			result.is_decimal = true

			if other.is_decimal {
				result.data = decimal_to_bits(bits_to_decimal(data) + bits_to_decimal(other.data))
			}
			else {
				result.data = decimal_to_bits(bits_to_decimal(data) + other.data)
			}
		}
		else {
			if other.is_decimal {
				result.data = decimal_to_bits(data + bits_to_decimal(other.data))
				result.is_decimal = true
			}
			else {
				result.data = data + other.data
			}
		}

		=> result
	}

	minus(other: Number) {
		result: Number
		result.data = 0
		result.is_decimal = false

		if is_decimal {
			result.is_decimal = true

			if other.is_decimal {
				result.data = decimal_to_bits(bits_to_decimal(data) - bits_to_decimal(other.data))
			}
			else {
				result.data = decimal_to_bits(bits_to_decimal(data) - other.data)
			}
		}
		else {
			if other.is_decimal {
				result.data = decimal_to_bits(data - bits_to_decimal(other.data))
				result.is_decimal = true
			}
			else {
				result.data = data - other.data
			}
		}

		=> result
	}

	times(other: Number) {
		result: Number
		result.data = 0
		result.is_decimal = false

		if is_decimal {
			result.is_decimal = true

			if other.is_decimal {
				result.data = decimal_to_bits(bits_to_decimal(data) * bits_to_decimal(other.data))
			}
			else {
				result.data = decimal_to_bits(bits_to_decimal(data) * other.data)
			}
		}
		else {
			if other.is_decimal {
				result.data = decimal_to_bits(data * bits_to_decimal(other.data))
				result.is_decimal = true
			}
			else {
				result.data = data * other.data
			}
		}

		=> result
	}

	divide(other: Number) {
		result: Number
		result.data = 0
		result.is_decimal = false

		if is_decimal {
			result.is_decimal = true

			if other.is_decimal {
				result.data = decimal_to_bits(bits_to_decimal(data) / bits_to_decimal(other.data))
			}
			else {
				result.data = decimal_to_bits(bits_to_decimal(data) / other.data)
			}
		}
		else {
			if other.is_decimal {
				result.data = decimal_to_bits(data / bits_to_decimal(other.data))
				result.is_decimal = true
			}
			else {
				result.data = data / other.data
			}
		}

		=> result
	}

	remainder(other: Number) {
		result: Number
		result.data = 0
		result.is_decimal = false

		if not is_decimal and not other.is_decimal { result.data = data % other.data }

		=> result
	}

	negation() {
		result: Number
		result.data = 0
		result.is_decimal = is_decimal

		if is_decimal {
			result.data = decimal_to_bits(-bits_to_decimal(data))
		}
		else {
			result.data = -data
		}

		=> result
	}

	equals(other: Number) {
		=> data === other.data and is_decimal === other.is_decimal
	}
}

Component ComplexComponent {
	node: Node
	is_negative: bool

	init(node: Node) {
		this.type = COMPONENT_TYPE_COMPLEX
		this.node = node
		this.is_negative = false
	}

	init(node: Node, is_negative: bool) {
		this.type = COMPONENT_TYPE_COMPLEX
		this.node = node
		this.is_negative = is_negative
	}

	override negation() {
		is_negative = not is_negative
	}

	override addition(other: Component) {
		if other.is_zero() => this # clone()
		=> none as Component
	}

	override subtraction(other: Component) {
		if other.is_zero() => this # clone()
		=> none as Component
	}

	override multiplication(other: Component) {
		if other.is_one() => this # clone()

		if other.is_zero() => other # NumberComponent(0)
		=> none as Component
	}

	override division(other: Component) {
		if other.is_one() => this # clone()

		=> none as Component
	}

	override equals(other: Component) {
		=> false
	}

	override clone() {
		=> ComplexComponent(node.clone(), is_negative)
	}
}

Component NumberComponent {
	value: Number

	init(value: large, is_decimal: bool) {
		this.type = COMPONENT_TYPE_NUMBER
		this.value = pack { data: value, is_decimal: is_decimal }
	}

	init(value: large) {
		this.type = COMPONENT_TYPE_NUMBER
		this.value = pack { data: value, is_decimal: false }
	}

	init(value: decimal) {
		this.type = COMPONENT_TYPE_NUMBER
		this.value = pack { data: decimal_to_bits(value), is_decimal: true }
	}

	init(value: Number) {
		this.type = COMPONENT_TYPE_NUMBER
		this.value = value
	}

	override negation() {
		value = value.negation()
	}

	override addition(other: Component) {
		if is_zero() => other # other.clone()
		if other.is_zero() => this # clone()

		if other.is_number => NumberComponent(value + other.(NumberComponent).value)

		=> none as NumberComponent
	}

	override subtraction(other: Component) {
		if is_zero() {
			clone = other.clone()
			clone.negation()
			=> clone
		}
		if other.is_zero() => this # clone()

		if other.is_number => NumberComponent(value - other.(NumberComponent).value)

		=> none as NumberComponent
	}

	override multiplication(other: Component) {
		if is_zero() or other.is_one() => this # clone()
		if is_one() or other.is_zero() => other # other.clone()

		if other.is_number => NumberComponent(value * other.(NumberComponent).value)
		if other.is_variable => VariableComponent(other.(VariableComponent).variable, value * other.(VariableComponent).coefficient, 1)
		if other.is_variable_product => (other as VariableProductComponent) * this
		=> none as Component
	}

	override division(other: Component) {
		if other.is_one() => this # clone()

		if other.is_number and not other.is_zero() => NumberComponent(value / other.(NumberComponent).value)

		=> none as Component
	}

	override bitwise_and(other: Component) {
		if value.is_integer and other.is_number and other.(NumberComponent).value.is_integer {
			=> NumberComponent(value.data & other.(NumberComponent).value.data)
		}

		=> none as Component
	}

	override bitwise_or(other: Component) {
		if value.is_integer and other.is_number and other.(NumberComponent).value.is_integer {
			=> NumberComponent(value.data | other.(NumberComponent).value.data)
		}

		=> none as Component
	}

	override bitwise_xor(other: Component) {
		if value.is_integer and other.is_number and other.(NumberComponent).value.is_integer {
			=> NumberComponent(value.data ¤ other.(NumberComponent).value.data)
		}

		=> none as Component
	}

	override equals(other: Component) {
		=> other.is_number and value == other.(NumberComponent).value
	}

	override clone() {
		=> NumberComponent(value)
	}
}

Component VariableComponent {
	coefficient: Number
	order: normal
	variable: Variable

	init(variable: Variable, coefficient: Number, order: normal) {
		this.type = COMPONENT_TYPE_VARIABLE
		this.coefficient = coefficient
		this.order = order
		this.variable = variable
	}

	init(variable: Variable, coefficient: large, order: normal) {
		this.type = COMPONENT_TYPE_VARIABLE
		this.coefficient.data = coefficient
		this.coefficient.is_decimal = false
		this.order = order
		this.variable = variable
	}

	init(variable: Variable) {
		this.type = COMPONENT_TYPE_VARIABLE
		this.coefficient.data = 1
		this.coefficient.is_decimal = false
		this.order = 1
		this.variable = variable
	}

	override negation() {
		coefficient = coefficient.negation()
	}

	override addition(other: Component) {
		if other.is_zero() => this # clone()

		if other.is_variable and variable === other.(VariableComponent).variable and order == other.(VariableComponent).order {
			result_coefficient = coefficient + other.(VariableComponent).coefficient
			if result_coefficient.is_zero() => NumberComponent(0)

			=> VariableComponent(variable, result_coefficient, order)
		}

		=> none as Component
	}

	override subtraction(other: Component) {
		if other.is_zero() => this # clone()

		if other.is_variable and variable === other.(VariableComponent).variable and order == other.(VariableComponent).order {
			result_coefficient = coefficient - other.(VariableComponent).coefficient
			if result_coefficient.is_zero() => NumberComponent(0)

			=> VariableComponent(variable, result_coefficient, order)
		}

		=> none as Component
	}

	override multiplication(other: Component) {
		if other.is_one() => this # clone()
		if other.is_zero() => other # NumberComponent(0)

		if other.is_variable {
			result_coefficient = coefficient * other.(VariableComponent).coefficient

			if variable === other.(VariableComponent).variable {
				=> VariableComponent(variable, result_coefficient, order + other.(VariableComponent).order)
			}

			left = VariableComponent(variable, 1, order)
			right = VariableComponent(other.(VariableComponent).variable, 1, other.(VariableComponent).order)

			=> VariableProductComponent(result_coefficient, [ left, right ])
		}

		if other.is_number {
			=> VariableComponent(variable, coefficient * other.(NumberComponent).value, order)
		}

		if other.is_variable_product {
			=> (other as VariableProductComponent) * this
		}

		=> none as Component
	}

	override division(other: Component) {
		if other.is_one => this # clone()

		if other.is_variable and variable === other.(VariableComponent).variable {
			if other.(VariableComponent).coefficient.is_zero() => none as Component

			result_order = order - other.(VariableComponent).order
			result_coefficient = coefficient / other.(VariableComponent).coefficient

			if result_order == 0 => NumberComponent(result_coefficient)

			# Ensure that the coefficient supports fractions
			if result_coefficient.is_decimal or (coefficient % other.(VariableComponent).coefficient).is_zero() {
				=> VariableComponent(variable, result_coefficient, result_order)
			}
		}

		if other.is_number and not other.(NumberComponent).value.is_zero() {
			other_value = other.(NumberComponent).value

			# If neither one of the two coefficients is a decimal number, the dividend must be divisible by the divisor
			if not coefficient.is_decimal and not other_value.is_decimal and not (coefficient % other_value).is_zero() {
				=> none as Component
			}

			=> VariableComponent(variable, coefficient / other_value, order)
		}

		=> none as Component
	}

	override equals(other: Component) {
		=> other.is_variable and coefficient == other.(VariableComponent).coefficient and variable === other.(VariableComponent).variable
	}

	override clone() {
		=> VariableComponent(variable, coefficient, order)
	}
}

Component VariableProductComponent {
	coefficient: Number
	variables: List<VariableComponent>

	init(coefficient: Number, variables: List<VariableComponent>) {
		this.type = COMPONENT_TYPE_VARIABLE_PRODUCT
		this.coefficient = coefficient
		this.variables = variables
	}

	override negation() {
		coefficient = coefficient.negation()
	}

	override addition(other: Component) {
		if other.is_zero() => this # clone()
		if not (this == other) => none as Component

		result = clone() as VariableProductComponent
		result.coefficient = coefficient + other.(VariableProductComponent).coefficient
		=> result
	}

	override subtraction(other: Component) {
		if other.is_zero() => this # clone()
		if not (this == other) => none as Component

		result = clone() as VariableProductComponent
		result.coefficient = coefficient - other.(VariableProductComponent).coefficient
		=> result
	}

	override multiplication(other: Component) {
		if other.is_one() => this # clone()
		if other.is_zero() => other # NumberComponent(0)

		if other.is_number {
			result_coefficient = coefficient * other.(VariableComponent).coefficient
			if result_coefficient.is_zero() => NumberComponent(0)

			result = clone() as VariableProductComponent
			result.coefficient = result_coefficient

			=> result
		}

		if other.is_variable {
			result_coefficient = coefficient * other.(VariableComponent).coefficient

			result = clone() as VariableProductComponent
			result.coefficient = result_coefficient

			variable_component_index = result.variables.find_index(i -> i.variable == other.(VariableComponent).variable)

			if variable_component_index >= 0 {
				variable_component = result.variables[variable_component_index]
				variable_component.order += other.(VariableComponent).order

				if variable_component.order == 0 {
					variables.remove_at(variable_component_index)
				}
			}
			else {
				other_clone = other.clone() as VariableComponent
				other_clone.coefficient.data = 1
				other_clone.coefficient.is_decimal = false

				result.variables.add(other_clone)
			}

			=> result
		}

		if other.is_variable_product {
			result_coefficient = coefficient * other.(VariableProductComponent).coefficient

			result = clone() as VariableProductComponent
			result.coefficient = result_coefficient

			loop variable in other.(VariableProductComponent).variables {
				result = (result * variable) as VariableProductComponent
			}

			=> result
		}

		=> none as Component
	}

	override division(other: Component) {
		if other.is_one() => this # clone()

		if other.is_number and not other.(NumberComponent).value.is_zero() {
			other_value = other.(NumberComponent).value

			# If neither one of the two coefficients is a decimal number, the dividend must be divisible by the divisor
			if not coefficient.is_decimal and not other_value.is_decimal and not (coefficient % other_value).is_zero() {
				=> none as Component
			}

			result_coefficient = coefficient / other_value

			result = clone() as VariableProductComponent
			result.coefficient = result_coefficient
			=> result
		}

		=> none as Component
	}

	override equals(other: Component) {
		if other.is_variable_product or variables.size != other.(VariableProductComponent).variables.size => false

		loop variable in variables {
			if not other.(VariableProductComponent).variables.contains(variable) => false
		}

		=> true
	}

	override clone() {
		=> VariableProductComponent(coefficient, variables.map<VariableComponent>((i: VariableComponent) -> i.clone() as VariableComponent))
	}
}