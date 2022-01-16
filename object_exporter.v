# Summary:
# Converts objects such as template functions and types to exportable formats such as mangled strings
namespace object_exporter

#warning Investigate exporting of member parameters (constructors)

# Summary:
# Creates a template name by combining the specified name and the template argument names together
create_template_name(name: String, template_argument_names: List<String>) {
	=> name + `<` + String.join(String(', '), template_argument_names) + `>`
}

# Summary:
# Converts the specified modifiers into source code
get_modifiers(modifiers: large) {
	result = List<String>()
	if (has_flag(modifiers, MODIFIER_PRIVATE)) result.add(Keywords.PRIVATE.identifier)
	if (has_flag(modifiers, MODIFIER_PROTECTED)) result.add(Keywords.PROTECTED.identifier)
	if (has_flag(modifiers, MODIFIER_STATIC)) result.add(Keywords.STATIC.identifier)
	if (has_flag(modifiers, MODIFIER_READONLY)) result.add(Keywords.READONLY.identifier)
	if (has_flag(modifiers, MODIFIER_EXPORTED)) result.add(Keywords.EXPORT.identifier)
	if (has_flag(modifiers, MODIFIER_CONSTANT)) result.add(Keywords.CONSTANT.identifier)
	if (has_flag(modifiers, MODIFIER_OUTLINE)) result.add(Keywords.OUTLINE.identifier)
	if (has_flag(modifiers, MODIFIER_INLINE)) result.add(Keywords.INLINE.identifier)
	if (has_flag(modifiers, MODIFIER_PLAIN)) result.add(Keywords.PLAIN.identifier)
	if (has_flag(modifiers, MODIFIER_PACK)) result.add(Keywords.PACK.identifier)
	=> String.join(` `, result)
}

# Summary:
# Exports the specified template function which may have the specified parent type
export_template_function(builder: StringBuilder, function: TemplateFunction) {
	builder.append(get_modifiers(function.modifiers))
	builder.append(` `)
	builder.append(create_template_name(function.name, function.template_parameters))
	builder.append(`(`)
	builder.append(String.join(String(', '), function.parameters.map<String>((i: Parameter) -> i.export_string())))
	builder.append(`)`)
	builder.append(` `)
	builder.append(to_string(function.blueprint.slice(1)))
	builder.append('\n\n')
}

# Summary:
# Exports the specified short template function which may have the specified parent type
export_short_template_function(builder: StringBuilder, function: Function) {
	builder.append(get_modifiers(function.modifiers))
	builder.append(` `)
	builder.append(function.name)
	builder.append(`(`)
	builder.append(String.join(String(', '), function.parameters.map<String>((i: Parameter) -> i.export_string())))
	builder.append(`)`)
	builder.append(' {\n')
	builder.append(to_string(function.blueprint))
	builder.append('\n}\n')
}

# Summary:
# Exports the specified template type
export_template_type(builder: StringBuilder, type: TemplateType) {
	if type.inherited.size > 0 {
		builder.append(to_string(type.inherited))
		builder.append(` `)
	}

	builder.append(create_template_name(type.name, type.template_parameters))
	builder.append(to_string(type.blueprint.slice(1)))
	builder.append('\n\n')
}

# Summary:
# Returns true if the specified function represents an actual template function or if any of its parameter types is not defined
is_template_function(function: Function) {
	=> (function.is_template_function or function.parameters.any((i: Parameter) -> i.type == none)) and not function.is_template_function_variant
}

# Summary:
# Returns true if the specified function represents an actual template function variant or if any of its parameter types is not defined
is_template_function_variant(function: Function) {
	=> function.is_template_function_variant or function.parameters.any((i: Parameter) -> i.type == none)
}

# Summary:
# Looks for template functions and types and exports them to string builders
get_template_export_files(context: Context) {
	files = Map<SourceFile, StringBuilder>()

	functions_with_sources = context.functions.get_values()
		.flatten<Function>((i: FunctionList) -> i.overloads) # Collect all overloads
		.filter(i -> is_template_function(i) and i.start != none and i.start.file != none) # Collect all template function overloads, which have a source file

	# Group all template function overloads by their source file
	# TODO: Generalize the grouping function
	grouped_functions = assembler.group_by<Function, SourceFile>(functions_with_sources, (i: Function) -> i.start.file)

	loop iterator in grouped_functions {
		builder = StringBuilder()
		functions = iterator.value

		loop function in functions {
			if function.is_template_function {
				export_template_function(builder, function as TemplateFunction)
			}
			else {
				export_short_template_function(builder, function)
			}
		}

		files.add(iterator.key, builder)
	}

	types_with_sources = common.get_all_types(context).filter(i -> i.position != none and i.position.file != 0)

	# TODO: Generalize the grouping function
	grouped_types = assembler.group_by<Type, SourceFile>(types_with_sources, (i: Type) -> i.position.file)

	loop iterator in grouped_types {
		file = iterator.key
		types = iterator.value

		loop type in types {
			if type.is_template_type_variant continue

			template_functions = type.functions.get_values()
				.flatten<Function>((i: FunctionList) -> i.overloads) # Collect all member function overloads
				.filter(is_template_function) # Filter out non-template functions

			if template_functions.size == 0 continue

			# Get the builder for the current source file
			builder = none as StringBuilder

			if files.contains_key(file) {
				builder = files[file]
			}
			else {
				builder = StringBuilder()
				files.add(file, builder)
			}

			builder.append(type.name)
			builder.append(` `)
			builder.append(`{`)

			loop function in template_functions {
				if function.is_template_function {
					export_template_function(builder, function as TemplateFunction)
				}
				else {
					export_short_template_function(builder, function)
				}
			}

			builder.append(`}`)
		}
	}

	loop iterator in grouped_types {
		file = iterator.key
		types = iterator.value

		loop type in types {
			if not type.is_template_type or type.is_template_type_variant continue

			# Get the builder for the current source file
			builder = none as StringBuilder

			if files.contains_key(file) {
				builder = files[file]
			}
			else {
				builder = StringBuilder()
				files.add(file, builder)
			}

			export_template_type(builder, type as TemplateType)
		}
	}

	=> files
}

node_to_string(node: Node) {
	if node.instance == NODE_CAST {
		=> (node_to_string(node.first) as String) + ' as ' + node.(CastNode).get_type().string()
	}

	if node.instance == NODE_NUMBER {
		=> node.(NumberNode).string()
	}

	if node.instance == NODE_STRING {
		=> node.(StringNode).text
	}

	abort('Exporter does not support this constant value')
}

# Summary:
# Exports the specified function to the specified builder using the following pattern:
# $modifiers import $name($parameters): $return_type
export_function(builder: StringBuilder, function: Function, implementation: FunctionImplementation) {
	builder.append(get_modifiers(function.modifiers))
	builder.append(` `)
	builder.append(Keywords.IMPORT.identifier)
	builder.append(` `)
	builder.append(function.name)
	builder.append(`(`)
	builder.append(String.join(String(', '), implementation.parameters.map<String>((i: Variable) -> i.string())))
	builder.append(`)`)

	# Add the return type if it is needed
	if not primitives.is_primitive(implementation.return_type, primitives.UNIT) {
		builder.append(': ')
		builder.append(implementation.return_type.string())
	}

	builder.append(`\n`)
}

# Summary:
# Export constants from the specified context:
# Example output:
# constant a = 1
# constant b = 'Hello'
#
# static Foo {
# constant c = 2
# constant d = 'There'
#
# Bar {
# constant e = 3
# constant f = '!'
# }
#
# }
export_context(context: Context) {
	builder = StringBuilder()

	loop iterator in context.variables {
		variable = iterator.value

		# Deny non-private constants
		if variable.is_constant and variable.is_private continue

		# Deny hidden variables
		if variable.is_hidden continue

		builder.append(get_modifiers(variable.modifiers))
		builder.append(` `)
		builder.append(variable.name)

		if variable.is_constant {
			# Extract the constant value
			editor = common.get_editor(variable.writes[0])
			constant_node_value = editor.last

			# Convert the constant value into a string
			constant_value = node_to_string(constant_node_value)

			builder.append(' = ')
			builder.append_line(constant_value)
			continue
		}
		else {
			builder.append(': ')
			builder.append_line(variable.type.string())
		}
	}

	loop iterator in context.functions {
		loop function in iterator.value.overloads {
			# Export the function as follows: $modifiers import $name($parameters): $return_type
			loop implementation in function.implementations {
				if is_template_function_variant(function) continue
				export_function(builder, function, implementation)
			}
		}
	}

	loop type in context.types.get_values() {
		if type.is_template_type or type.is_primitive continue

		if type.supertypes.size > 0 {
			builder.append(String.join(String(', '), type.supertypes.map<String>((i: Type) -> i.string())))
			builder.append(` `)
		}

		exported_variables = export_context(type)

		builder.append(`\n`)

		if type.is_namespace { builder.append(Keywords.NAMESPACE.identifier) }
		else { builder.append(get_modifiers(type.modifiers)) }

		builder.append(` `)
		builder.append(type.name)
		builder.append_line(' {')
		builder.append(exported_variables)
		builder.append_line('}')
		builder.append(`\n`)
	}

	=> builder.string()
}

# Summary:
# Exports all the template type variants from the specified context 
export_template_type_variants(context: Context) {
	template_variants = common.get_all_types(context).filter(i -> i.is_template_type_variant)
	if template_variants.size == 0 => String.empty

	# Export all variants in the following format: $T1.$T2...$Tn.$T<$P1,$P2,...,$Pn>
	builder = StringBuilder()

	loop template_variant in template_variants {
		builder.append_line(template_variant.string())
	}

	=> builder.string()
}

# Summary:
# Exports all the template function variants from the specified context using the following pattern:
# $T1.$T2...$Tn.$name<$U1, $U2, ..., $Un>($V1, $V2, ..., $Vn)
export_template_function_variants(context: Context) {
	template_variants = common.get_all_function_implementations(context)
		.filter(i -> i.metadata.is_template_function or i.metadata.parameters.any((j: Parameter) -> j.type == none))

	if template_variants.size == 0 => String.empty

	# Export all variants in the following format: $T1.$T2...$Tn.$name<$U1, $U2, ..., $Un>($V1, $V2, ..., $Vn)
	builder = StringBuilder()

	loop template_variant in template_variants {
		path = template_variant.parent.string()
		builder.append(path)

		if path.length == 0 builder.append('.')

		builder.append(template_variant.name)
		builder.append(`(`)
		builder.append(String.join(String(', '), template_variant.parameter_types.map<String>((i: Type) -> i.string())))
		builder.append_line(`)`)
	}

	=> builder.string()
}