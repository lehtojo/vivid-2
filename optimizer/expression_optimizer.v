namespace expression_optimizer

constant VARIABLE_ACCESS_COST = 1
constant STANDARD_OPERATOR_COST = 10

constant ADDITION_COST = STANDARD_OPERATOR_COST
constant SUBTRACTION_COST = STANDARD_OPERATOR_COST

constant POWER_OF_TWO_MULTIPLICATION_COST = STANDARD_OPERATOR_COST
constant MULTIPLICATION_COST = 3 * STANDARD_OPERATOR_COST

constant POWER_OF_TWO_DIVISION_COST = STANDARD_OPERATOR_COST
constant DIVISION_COST = 70 * STANDARD_OPERATOR_COST

constant MEMORY_ACCESS_COST = 10 * STANDARD_OPERATOR_COST
constant CONDITIONAL_JUMP_COST = 10 * STANDARD_OPERATOR_COST

constant FUNCTION_CALL_COST = 12 * STANDARD_OPERATOR_COST
constant MEMORY_ADDRESS_CALL_COST = 2 * FUNCTION_CALL_COST

constant MAXIMUM_LOOP_UNWRAP_STEPS = 100

constant SMALL_FUNCTION_THRESHOLD = 20 * MEMORY_ACCESS_COST

# Summary:
# Approximates the complexity of the specified node tree to execute
get_cost(node: Node) {
	result = 0
	iterator = node.first

	loop (iterator !== none) {
		instance = iterator.instance

		if instance == NODE_OPERATOR {
			operator = iterator.(OperatorNode).operator

			if operator === Operators.ADD {
				result += ADDITION_COST
			}
			else operator === Operators.SUBTRACT {
				result += SUBTRACTION_COST
			}
			else operator === Operators.MULTIPLY {
				# Take into account that power of two multiplications are significantly faster
				if common.is_power_of_two(iterator.first) or common.is_power_of_two(iterator.last) {
					result += POWER_OF_TWO_MULTIPLICATION_COST
				}
				else {
					result += MULTIPLICATION_COST
				}
			}
			else operator === Operators.DIVIDE {
				# Take into account that power of two division are significantly faster
				if common.is_power_of_two(iterator.last) {
					result += POWER_OF_TWO_DIVISION_COST
				}
				else {
					result += DIVISION_COST
				}
			}
			else {
				result += STANDARD_OPERATOR_COST
			}
		}
		else (instance & (NODE_LINK | NODE_ACCESSOR)) != 0 {
			result += MEMORY_ACCESS_COST
		}
		else instance == NODE_FUNCTION {
			result += FUNCTION_CALL_COST
		}
		else instance == NODE_CALL {
			result += MEMORY_ADDRESS_CALL_COST
		}
		else (instance & (NODE_IF | NODE_ELSE_IF | NODE_ELSE)) != 0 {
			result += CONDITIONAL_JUMP_COST
		}
		else instance == NODE_LOOP {
			result += CONDITIONAL_JUMP_COST
			result += get_cost(iterator) * MAXIMUM_LOOP_UNWRAP_STEPS

			iterator = iterator.next
			continue
		}
		else instance == NODE_VARIABLE {
			result += VARIABLE_ACCESS_COST

			iterator = iterator.next
			continue
		}
		else (instance & (NODE_NEGATE | NODE_NOT)) != 0 {
			result += STANDARD_OPERATOR_COST

			iterator = iterator.next
			continue
		}
		else instance == NODE_DISABLED {
			iterator = iterator.next
			continue
		}

		result += get_cost(iterator)
		iterator = iterator.next
	}

	return result
}

# Summary:
# Creates a node tree representing the specified components
recreate(components: List<Component>) {
	result = recreate(components[])

	loop (i = 1, i < components.size, i++) {
		component = components[i]

		if component.is_number {
			if component.is_zero continue

			value = component.(NumberComponent).value
			number = NumberNode(value.format, value.data, none as Position)

			if value.is_negative { result = OperatorNode(Operators.SUBTRACT).set_operands(result, number.negate()) }
			else { result = OperatorNode(Operators.ADD).set_operands(result, number) }
		}
		else component.is_variable {
			variable_component = component as VariableComponent

			coefficient = variable_component.coefficient
			operator = Operators.ADD

			if coefficient.is_negative {
				coefficient = coefficient.negation()
				operator = Operators.SUBTRACT
			}

			# When the coefficient is exactly zero (double), the variable can be ignored, meaning the inaccuracy of the comparison is expected
			if coefficient.is_zero() continue

			node = create_variable_with_order(variable_component.variable, variable_component.order)

			# When the coefficient is exactly one (double), the coefficient can be ignored, meaning the inaccuracy of the comparison is expected
			if not coefficient.is_one() {
				node = OperatorNode(Operators.MULTIPLY).set_operands(node, NumberNode(coefficient.format, coefficient.data, none as Position))
			}

			result = OperatorNode(operator).set_operands(result, node)
		}
		else component.is_complex {
			complex_component = component as ComplexComponent

			operator = Operators.ADD
			if complex_component.is_negative { operator = Operators.SUBTRACT }

			result = OperatorNode(operator).set_operands(result, complex_component.node.clone())
		}
		else component.is_variable_product {
			product_component = component as VariableProductComponent

			is_negative = product_component.coefficient.is_negative
			if is_negative product_component.negation()

			other = recreate(product_component)

			operator = Operators.ADD
			if is_negative { operator = Operators.SUBTRACT }

			result = OperatorNode(operator).set_operands(result, other)
		}
	}

	return result
}

# Summary:
# Builds a node tree representing a variable with an order
create_variable_with_order(variable: Variable, order: normal) {
	if order == 0 return NumberNode(SYSTEM_SIGNED, 1, none as Position)

	result = VariableNode(variable) as Node

	loop (i = 1, i < abs(order), i++) {
		result = OperatorNode(Operators.MULTIPLY).set_operands(result, VariableNode(variable))
	}

	if order < 0 {
		result = OperatorNode(Operators.DIVIDE).set_operands(NumberNode(SYSTEM_SIGNED, 1, none as Position), result)
	}

	return result
}

# Summary:
# Creates a node tree representing the specified component
recreate(component: Component) {
	if component.is_number {
		number_component = component as NumberComponent
		return NumberNode(number_component.value.format, number_component.value.data, none as Position)
	}

	if component.is_variable {
		variable_component = component as VariableComponent
		coefficient = variable_component.coefficient

		if coefficient.is_zero {
			return NumberNode(coefficient.format, coefficient.data, none as Position)
		}

		result = create_variable_with_order(variable_component.variable, variable_component.order)
		if coefficient.is_one() return result

		return OperatorNode(Operators.MULTIPLY).set_operands(result, NumberNode(coefficient.format, coefficient.data, none as Position))
	}

	if component.is_complex {
		complex_component = component as ComplexComponent
		complex_node = complex_component.node.clone()

		if complex_component.is_negative return NegateNode(complex_node, none as Position)
		return complex_node
	}

	if component.is_variable_product {
		product_component = component as VariableProductComponent
		coefficient = product_component.coefficient

		result = create_variable_with_order(product_component.variables[].variable, product_component.variables[].order)

		loop (i = 1, i < product_component.variables.size, i++) {
			variable = product_component.variables[i]

			result = OperatorNode(Operators.MULTIPLY).set_operands(result, create_variable_with_order(variable.variable, variable.order))
		}

		if coefficient.is_one() return result

		return OperatorNode(Operators.MULTIPLY).set_operands(result, NumberNode(coefficient.format, coefficient.data, none as Position))
	}

	abort('Unsupported component encountered while recreating')
}

# Summary:
# Negates the all the specified components using their internal negation method
perform_negate(components: List<Component>) {
	loop component in components {
		component.negation()
	}

	return components
}

# Summary:
# Performs not operation when the specified components have exactly one component, otherwise builds a complex component
perform_not(expression: NotNode, components: List<Component>) {
	if components.size == 1 and components[].is_integer {
		data = components[].(NumberComponent).value.data

		if expression.is_bitwise return [ NumberComponent(!data) as Component ]
		else return [ NumberComponent(data ¤ 1) as Component ]
	}

	return [ ComplexComponent(NotNode(recreate(components), expression.is_bitwise, expression.start)) as Component ]
}

# Summary:
# Returns a component list which describes the specified expression
collect_components(expression: Node) {
	result = List<Component>()

	if expression.match(NODE_NUMBER) {
		result.add(NumberComponent(expression.(NumberNode).value, expression.(NumberNode).format == FORMAT_DECIMAL))
	}
	else expression.match(NODE_VARIABLE) {
		result.add(VariableComponent(expression.(VariableNode).variable))
	}
	else expression.match(NODE_OPERATOR) {
		result.add_all(collect_components(expression as OperatorNode) as List<Component>)
	}
	else expression.match(NODE_PARENTHESIS) {
		if expression.first !== none {
			result.add_all(collect_components(expression.first) as List<Component>)
		}
	}
	else expression.match(NODE_NEGATE) {
		result.add_all(perform_negate(collect_components(expression.first) as List<Component>))
	}
	else expression.match(NODE_NOT) {
		result.add_all(perform_not(expression as NotNode, collect_components(expression.first) as List<Component>))
	}
	else expression.match(NODE_CAST) {
		# Look for number casts, which do not change the format from integer to decimal or vice versa
		casted = expression.(CastNode).first

		if casted.instance != NODE_NUMBER {
			result.add(ComplexComponent(expression))
			return result
		}

		from = casted.get_type()
		to = expression.(CastNode).get_type()

		# If this is not a number cast, conversion just return a complex component
		if not from.is_number or not to.is_number {
			result.add(ComplexComponent(expression))
			return result
		}

		# If an integer is converted to a decimal or vice versa, just return a complex component
		is_decimal_conversion = (from == FORMAT_DECIMAL) ¤ (to == FORMAT_DECIMAL)
		
		if is_decimal_conversion {
			result.add(ComplexComponent(expression))
			return result
		}

		result.add_all(collect_components(expression.first) as List<Component>)
	}
	else {
		result.add(ComplexComponent(expression))
	}

	return result
}

# Summary:
# Returns a component list which describes the specified operator node
collect_components(node: OperatorNode) {
	left_components = collect_components(node.first)
	right_components = collect_components(node.last)

	if node.operator === Operators.ADD {
		return simplify_addition(left_components, right_components)
	}

	if node.operator === Operators.SUBTRACT {
		return simplify_subtraction(left_components, right_components)
	}

	if node.operator === Operators.MULTIPLY {
		return simplify_multiplication(left_components, right_components)
	}

	if node.operator === Operators.DIVIDE {
		return simplify_division(left_components, right_components)
	}

	if node.operator === Operators.SHIFT_LEFT {
		return simplify_shift_left(left_components, right_components)
	}

	if node.operator === Operators.SHIFT_RIGHT {
		return simplify_shift_right(left_components, right_components)
	}

	if node.operator === Operators.BITWISE_AND {
		return simplify_bitwise_and(left_components, right_components)
	}

	if node.operator === Operators.BITWISE_XOR {
		return simplify_bitwise_xor(left_components, right_components)
	}

	if node.operator === Operators.BITWISE_OR {
		return simplify_bitwise_or(left_components, right_components)
	}

	if node.operator.type === OPERATOR_TYPE_COMPARISON {
		return simplify_comparison(node.operator, left_components, right_components)
	}

	return [ ComplexComponent(OperatorNode(node.operator).set_operands(recreate(left_components), recreate(right_components))) as Component ]
}

# Summary:
# Tries to simplify the specified components
simplify(components: List<Component>) {
	if components.size <= 1 return components

	loop (i = 0, i < components.size, i++) {
		current = components[i]
		j = 0

		# Start iterating from the next component
		loop (j < components.size) {
			if i == j {
				j++
				continue
			}

			result = current + components[j]

			# Move to the next component if the two components could not be added together
			if result === none {
				j++
				continue
			}

			# Remove the other component and replace the current one with the result
			if i < j {
				components.remove_at(j)
				components[i] = result
			}
			else {
				components.remove_at(i)
				components[j] = result
				i = j
			}

			# Since the returned component might be completely new, it might react with the previous components
			current = result
			j = 0
		}
	}

	return components
}

# Summary:
# Simplifies the addition between the specified operands
simplify_addition(left_components: List<Component>, right_components: List<Component>) {
	components = List<Component>()
	components.add_all(left_components)
	components.add_all(right_components)
	return simplify(components)
}

# Summary:
# Simplifies the subtraction between the specified operands
simplify_subtraction(left_components: List<Component>, right_components: List<Component>) {
	perform_negate(right_components)

	return simplify_addition(left_components, right_components)
}

# Summary:
# Simplifies the multiplication between the specified operands
simplify_multiplication(left_components: List<Component>, right_components: List<Component>) {
	components = List<Component>()

	loop left_component in left_components {
		loop right_component in right_components {
			result = left_component * right_component

			if result === none {
				result = ComplexComponent(OperatorNode(Operators.MULTIPLY).set_operands(recreate(left_component), recreate(right_component)))
			}

			components.add(result)
		}
	}

	return simplify(components)
}

# Summary:
# Simplifies the division between the specified operands
simplify_division(left_components: List<Component>, right_components: List<Component>) {
	if left_components.size == 1 and right_components.size == 1 {
		result = left_components[] / right_components[]

		if result !== none return [ result ]
	}

	return [ ComplexComponent(OperatorNode(Operators.DIVIDE).set_operands(recreate(left_components), recreate(right_components))) as Component ]
}

# Summary:
# Simplifies left shift between the specified operands
simplify_shift_left(left_components: List<Component>, right_components: List<Component>) {
	if right_components.size != 1 or not right_components[].is_number or right_components[].(NumberComponent).value.is_decimal {
		return [ ComplexComponent(OperatorNode(Operators.SHIFT_LEFT).set_operands(recreate(left_components), recreate(right_components))) as Component ]
	}

	components = List<Component>()
	shifter = right_components[].(NumberComponent).value.data
	multiplier = NumberComponent(1 <| shifter)

	loop component in left_components {
		result = component * multiplier

		if result === none {
			result = ComplexComponent(OperatorNode(Operators.MULTIPLY).set_operands(recreate(component), recreate(multiplier)))
		}

		components.add(result)
	}

	return components
}

# Summary:
# Simplifies right shift between the specified operands
simplify_shift_right(left_components: List<Component>, right_components: List<Component>) {
	if right_components.size != 1 or not right_components[].is_number or right_components[].(NumberComponent).value.is_decimal {
		return [ ComplexComponent(OperatorNode(Operators.SHIFT_RIGHT).set_operands(recreate(left_components), recreate(right_components))) as Component ]
	}

	components = List<Component>()
	shifter = right_components[].(NumberComponent).value.data
	divider = NumberComponent(1 <| shifter)

	loop component in left_components {
		result = component / divider

		if result === none {
			result = ComplexComponent(OperatorNode(Operators.DIVIDE).set_operands(recreate(component), recreate(divider)))
		}

		components.add(result)
	}

	return components
}

# Summary:
# Simplifies bitwise and between the specified operands
simplify_bitwise_and(left_components: List<Component>, right_components: List<Component>) {
	if left_components.size == 1 and right_components.size == 1 {
		result = left_components[].bitwise_and(right_components[])
		if result !== none return [ result ]
	}

	return [ ComplexComponent(OperatorNode(Operators.BITWISE_AND).set_operands(recreate(left_components), recreate(right_components))) as Component ]
}

# Summary:
# Simplifies bitwise xor between the specified operands
simplify_bitwise_xor(left_components: List<Component>, right_components: List<Component>) {
	if left_components.size == 1 and right_components.size == 1 {
		result = left_components[].bitwise_xor(right_components[])
		if result !== none return [ result ]
	}

	return [ ComplexComponent(OperatorNode(Operators.BITWISE_XOR).set_operands(recreate(left_components), recreate(right_components))) as Component ]
}

# Summary:
# Simplifies bitwise or between the specified operands
simplify_bitwise_or(left_components: List<Component>, right_components: List<Component>) {
	if left_components.size == 1 and right_components.size == 1 {
		result = left_components[].bitwise_or(right_components[])
		if result !== none return [ result ]
	}

	return [ ComplexComponent(OperatorNode(Operators.BITWISE_OR).set_operands(recreate(left_components), recreate(right_components))) as Component ]
}

# Summary:
# Simplifies comparison operators between the specified operands
simplify_comparison(operator: Operator, left_components: List<Component>, right_components: List<Component>) {
	if left_components.size == 1 and right_components.size == 1 {
		comparison = left_components[].compare(right_components[])

		if comparison !== COMPARISON_UNKNOWN {
			result = when(operator) {
				Operators.GREATER_THAN => comparison > 0,
				Operators.GREATER_OR_EQUAL => comparison >= 0,
				Operators.LESS_THAN => comparison < 0,
				Operators.LESS_OR_EQUAL => comparison <= 0,
				Operators.EQUALS => comparison === 0,
				Operators.NOT_EQUALS => comparison !== 0,
				Operators.ABSOLUTE_EQUALS => comparison === 0,
				Operators.ABSOLUTE_NOT_EQUALS => comparison !== 0,
				else => abort('Unknown comparison operator') as large
			}

			return [ NumberComponent(result) as Component ]
		}
	}

	return [ ComplexComponent(OperatorNode(operator).set_operands(recreate(left_components), recreate(right_components))) as Component ]
}

# Summary:
# Tries to simplify the specified node
get_simplified_value(value: Node) {
	components = collect_components(value)
	simplified = recreate(components)

	return simplified
}

# Summary:
# Finds comparisons and tries to simplify them.
# Returns whether any modifications were done.
optimize_comparisons(root: Node) {
	comparisons = root.find_all(i -> i.instance == NODE_OPERATOR and i.(OperatorNode).operator.type == OPERATOR_TYPE_COMPARISON)
	precomputed = false

	loop comparison in comparisons {
		left = collect_components(comparison.first)
		right = collect_components(comparison.last)

		i = 0
		j = 0

		loop (left.size > 0 and right.size > 0 and i < left.size) {
			if j >= right.size {
				i++
				j = 0
				continue
			}

			x = left[i]
			y = right[j]

			if x.is_complex {
				i++
				j = 0
				continue
			}
			else y.is_complex {
				j++
				continue
			}

			s = x - y

			if s !== none {
				left.remove_at(i)
				right.remove_at(j)

				left.insert(i, s)

				j = 0
			}
			else {
				j++
			}
		}

		if left.size == 0 {
			left.add(NumberComponent(0))
		}

		if right.size == 0 {
			right.add(NumberComponent(0))
		}

		left = simplify(left)
		right = simplify(right)

		comparison.first.replace(recreate(left))
		comparison.last.replace(recreate(right))
	}

	return false
}

is_expression_root(root: Node) {
	if root.instance == NODE_OPERATOR {
		type = root.(OperatorNode).operator.type
		return type == OPERATOR_TYPE_CLASSIC or type == OPERATOR_TYPE_COMPARISON
	}

	return root.match(NODE_NEGATE | NODE_NOT)
}

# Summary:
# Tries to optimize all expressions in the specified node tree
optimize_all_expressions(root: Node) {
	if is_expression_root(root) {
		result = get_simplified_value(root)
		root.replace(result)
		return result
	}

	# Find all top level operators
	expressions = root.find_top(i -> is_expression_root(i))

	loop expression in expressions {
		# Replace the expression with a simplified version
		expression.replace(get_simplified_value(expression))
	}

	return root
}