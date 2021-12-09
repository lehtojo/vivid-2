MangleDefinition {
	constant TABLE = '0123456789ABCDEF'

	type: Type
	index: large
	pointers: large
	hexadecimal: String

	init(type: Type, index: large, pointers: large) {
		this.type = type
		this.index = index
		this.pointers = pointers
	}

	string() {
		if hexadecimal as link == none {
			digits = List<char>()
			n = index - 1

			if n == 0 { digits.add(`0`) }

			loop (n > 0) {
				a = n / 16
				r = n - a * 16
				n = a

				digits.insert(0, TABLE[r])
			}

			hexadecimal = String(digits.elements, digits.size)
		}

		result = String(`S`)
		if index != 0 { result = result + hexadecimal }
		=> result + `_`
	}
}

Mangle {
	constant EXPORT_TYPE_TAG = '_T'
	constant VIVID_LANGUAGE_TAG = '_V'
	constant CPP_LANGUAGE_TAG = '_Z'
	constant START_LOCATION_COMMAND = `N`
	constant TYPE_COMMAND = `N`
	constant START_TEMPLATE_ARGUMENTS_COMMAND = `I`
	constant STACK_REFERENCE_COMMAND = `S`
	constant STACK_REFERENCE_END = `_`
	constant END_COMMAND = `E`
	constant POINTER_COMMAND = `P`
	constant PARAMETERS_END = `_`
	constant NO_PARAMETERS_COMMAND = `v`
	constant START_RETURN_TYPE_COMMAND = `r`
	constant STATIC_VARIABLE_COMMAND = `A`
	constant CONFIGURATION_COMMAND = `C`
	constant DESCRIPTOR_COMMAND = `D`
	constant START_FUNCTION_POINTER_COMMAND = `F`
	constant START_MEMBER_VARIABLE_COMMAND = `V`
	constant START_MEMBER_VIRTUAL_FUNCTION_COMMAND = `F`
	constant VIRTUAL_FUNCTION_POSTFIX = '_v'

	definitions: List<MangleDefinition> = List<MangleDefinition>()
	value: String

	init(from: Mangle) {
		if from != none {
			definitions = List<MangleDefinition>(from.definitions)
			value = from.value
		}
		else {
			value = String(VIVID_LANGUAGE_TAG)
		}
	}

	init(value: String) {
		this.value = value
	}

	add(raw: String) {
		value = value + raw
	}

	add(character: char) {
		value = value + character
	}

	private push(last: MangleDefinition, pointers: large) {
		loop (i = 0, i < pointers, i++) {
			definitions.add(MangleDefinition(last.type, definitions.size, last.pointers + i + 1))
			value = value + POINTER_COMMAND
		}

		value = value + last.string()
	}

	# Summary: Adds the specified type to this mangled identifier
	add(type: Type, pointers: large, full: bool) {
		if pointers == 0 and type.is_primitive and not (type.name == primitives.LINK) and not type.is_array_type {
			value = value + type.identifier
			return
		}

		# Try to find the specified type from the definitions
		# NOTE: This also finds the definition with the closest pointer value compared to the specified pointer value
		i = -1

		loop (j = 0, j < definitions.size, j++) {
			definition = definitions[j]
			if definition.type.match(type) and definition.pointers <= pointers { i = j }
		}

		if i == -1 {
			# Add the pointer commands
			loop (j = 0, j < pointers, j++) { value = value + POINTER_COMMAND }

			# Add the default definition, without any pointers, if the type is not a primitive
			if not type.is_primitive or type.name == primitives.LINK or type.is_array_type {
				definitions.add(MangleDefinition(type, definitions.size, 0))
			}

			# Support functions types
			if type.is_function_type {
				function = type as FunctionType

				value = value + START_FUNCTION_POINTER_COMMAND
				definitions.add(MangleDefinition(type, definitions.size, 1))

				type = function.return_type

				# Add the return type
				if primitives.is_primitive(type, primitives.UNIT) {
					value = value + NO_PARAMETERS_COMMAND
				}
				else {
					pointers = (not type.is_primitive) as large
					add(type, pointers, true)
				}

				# Finally, add the parameter types
				add(function.parameters)
				value = value + END_COMMAND
				return
			}

			if primitives.is_primitive(type, primitives.LINK) or type.is_array_type {
				value = value + POINTER_COMMAND
				
				argument = type.get_accessor_type()
				pointers = (not argument.is_primitive) as large
				
				add(argument, pointers, true)
				return
			}

			# Append the full location of the specified type if that is allowed
			parents = type.get_parent_types()

			if full and parents.size > 0 {
				value = value + START_LOCATION_COMMAND
				add_path(parents)
			}

			value = value + to_string(type.identifier.length) + type.identifier

			# Support template types
			if type.is_template_type {
				value = value + START_TEMPLATE_ARGUMENTS_COMMAND
				add(type.template_arguments)
				value = value + END_COMMAND
			}

			# End the location command if there are any parents
			if full and parents.size > 0 {
				value = value + END_COMMAND
			}

			# Add the pointer variant types
			loop (j = 0, j < pointers, j++) {
				definitions.add(MangleDefinition(type, definitions.size, j + 1))
			}

			return
		}

		# Determine the amount of nested pointers needed for the best definition to match the specified type
		pointer_difference = pointers - definitions[i].pointers

		# The difference should never be negative but it can be zero
		if pointer_difference <= 0 {
			value = value + definitions[i].string()
			return
		}

		push(definitions[i], pointer_difference)
	}

	add_path(path: List<Type>) {
		components = List<Type>()

		loop (i = path.size - 1, i >= 0, i--) {
			type = path[i]
			exists = false

			loop definition in definitions {
				if not definition.type.match(type) continue
				exists = true
				stop
			}

			if exists stop
			components.add(type)
		}

		components.reverse()

		loop type in components {
			# The path must consist of user defined types
			if not type.is_user_defined abort('Invalid type path')

			# Try to find the current type from the definitions
			added = false

			loop definition in definitions {
				if not definition.type.match(type) continue
				value = definition.string() + value
				added = true
				stop
			}

			if added continue
			add(type, 0, false)
		}
	}

	add(types: List<Type>) {
		loop type in types {
			add(type, (not type.is_primitive) as large, true)
		}
	}

	add(type: Type) {
		add(type, (not type.is_primitive) as large, true)
	}

	clone() {
		=> Mangle(this)
	}
}