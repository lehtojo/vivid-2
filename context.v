VARIABLE_CATEGORY_LOCAL = 0
VARIABLE_CATEGORY_PARAMETER = 1
VARIABLE_CATEGORY_MEMBER = 2
VARIABLE_CATEGORY_GLOBAL = 3

NORMAL_CONTEXT = 1
TYPE_CONTEXT = 2
FUNCTION_CONTEXT = 4
IMPLEMENTATION_CONTEXT = 8

LAMBDA_CONTEXT_MODIFIER = 16
CONSTRUCTOR_CONTEXT_MODIFIER = 32
DESTRUCTOR_CONTEXT_MODIFIER = 64

LANGUAGE_OTHER = 0
LANGUAGE_CPP = 1
LANGUAGE_VIVID = 2

SELF_POINTER_IDENTIFIER = 'this'
LAMBDA_SELF_POINTER_IDENTIFIER = 'lambda'

Indexer {
	private context_count = 0
	private hidden_count = 0
	private stack_count = 0
	private label_count = 0
	private identity_count = 0

	context => context_count++
	hidden => hidden_count++
	stack => stack_count++
	label => label_count++
	identity => identity_count++
}

Context {
	identity: String
	identifier: String
	name: String
	type: normal

	variables: Map<String, Variable>
	functions: Map<String, FunctionList>
	types: Map<String, Type>
	labels: Map<String, Label>

	parent: Context
	subcontexts: List<Context>
	imports: List<Type>

	indexer: Indexer

	is_global => find_type_parent() == none
	is_member => find_type_parent() != none
	is_type => type == TYPE_CONTEXT
	is_namespace => is_type and this.(Type).is_static
	is_function => has_flag(type, FUNCTION_CONTEXT)
	is_lambda => has_flag(type, LAMBDA_CONTEXT_MODIFIER)
	is_implementation => has_flag(type, IMPLEMENTATION_CONTEXT)
	is_lambda_implementation => has_flag(type, IMPLEMENTATION_CONTEXT | LAMBDA_CONTEXT_MODIFIER)

	is_inside_function => is_implementation or is_function or (parent != none and parent.is_inside_function)
	is_inside_lambda => is_lambda_implementation or is_lambda or (parent != none and parent.is_inside_lambda)

	locals() {
		result = List<Variable>()
		loop variable in variables { result.add(variable.value) }
		loop subcontext in subcontexts { result.add_range(subcontext.locals) }
		=> result
	}

	init(identity: String, type: normal) {
		this.identity = identity
		this.type = type
		this.identifier = String.empty
		this.name = String.empty
		this.variables = Map<String, Variable>()
		this.functions = Map<String, FunctionList>()
		this.types = Map<String, Type>()
		this.labels = Map<String, Label>()
		this.subcontexts = List<Context>()
		this.imports = List<Type>()
		this.indexer = Indexer()
	}

	init(parent: Context, type: normal) {
		this.identity = parent.identity + `.` + to_string(parent.indexer.context)
		this.type = type
		this.identifier = String.empty
		this.name = String.empty
		this.variables = Map<String, Variable>()
		this.functions = Map<String, FunctionList>()
		this.types = Map<String, Type>()
		this.labels = Map<String, Label>()
		this.subcontexts = List<Context>()
		this.imports = List<Type>()
		this.indexer = Indexer()
		connect(parent)
	}

	virtual get_fullname() {
		=> String.empty
	}

	# Summary: Tries to find the self pointer variable
	virtual get_self_pointer() {
		if parent != none => parent.get_self_pointer() as Variable
		=> none as Variable
	}

	# Summary: Adds this context under the specified context
	connect(context: Context) {
		parent = context
		parent.subcontexts.add(this)
	}

	# Summary: Declares the specified type
	declare(type: Type) {
		if types.contains_key(type.name) => false

		type.parent = this
		types.add(type.name, type)
		=> true
	}

	# Summary: Declares the specified function
	declare(function: Function) {
		if functions.contains_key(function.name) {
			entry = functions[function.name]
			=> entry.add(function)
		}

		entry = FunctionList()
		functions.add(function.name, entry)
		=> entry.add(function)
	}

	# Summary: Declares the specified variable
	declare(variable: Variable) {
		if variables.contains_key(variable.name) => false

		variable.parent = this
		variables.add(variable.name, variable)
		=> true
	}

	# Summary: Declares a variable into the context
	declare(type: Type, category: large, name: String) {
		if variables.contains_key(name) => none as Variable
		variable = Variable(this, type, category, name, MODIFIER_DEFAULT)
		if not declare(variable) => none as Variable
		=> variable
	}

	# Summary: Declares a hidden variable with the specified type
	declare_hidden(type: Type) {
		variable = Variable(this, type, VARIABLE_CATEGORY_LOCAL, identity + '.' + to_string(indexer.hidden), MODIFIER_DEFAULT)
		declare(variable)
		=> variable
	}

	# Summary: Tries to find the first parent context which is a type
	find_type_parent() {
		iterator = parent

		loop (iterator != none) {
			if iterator.is_type => iterator as Type
			iterator = iterator.parent
		}

		=> none as Type
	}

	# Summary: Returns all parent contexts, which represent types
	get_parent_types() {
		result = List<Type>()
		iterator = parent

		loop (iterator != none) {
			if iterator.is_type result.add(iterator as Type)
			iterator = iterator.parent 
		}

		=> result
	}

	# Summary: Returns whether the specified context is this context or one of the parent contexts
	is_inside(context: Context) {
		=> context == this or [parent != none and parent.is_inside(context)]
	}

	# Summary: Returns whether the specified type is declared inside this context
	is_local_type_declared(name: String) {
		=> types.contains_key(name)
	}

	# Summary: Returns whether the specified function is declared inside this context
	is_local_function_declared(name: String) {
		=> functions.contains_key(name)
	}

	# Summary: Returns whether the specified variable is declared inside this context
	is_local_variable_declared(name: String) {
		=> variables.contains_key(name)
	}

	# Summary: Returns whether the specified type is declared inside this context or in the parent contexts
	is_type_declared(name: String) {
		if types.contains_key(name) => true

		loop (i = 0, i < imports.size, i++) {
			if imports[i].is_local_type_declared(name) => true
		}

		=> parent != none and parent.is_type_declared(name)
	}

	# Summary: Returns whether the specified function is declared inside this context or in the parent contexts
	is_function_declared(name: String) {
		if functions.contains_key(name) => true

		loop (i = 0, i < imports.size, i++) {
			if imports[i].is_local_function_declared(name) => true
		}

		=> parent != none and parent.is_function_declared(name)
	}

	# Summary: Returns whether the specified variable is declared inside this context or in the parent contexts
	is_variable_declared(name: String) {
		if variables.contains_key(name) => true

		loop (i = 0, i < imports.size, i++) {
			if imports[i].is_local_variable_declared(name) => true
		}

		=> parent != none and parent.is_variable_declared(name)
	}

	# Summary: Returns whether the specified type is declared inside this context or in the parent contexts depending on the specified flag
	is_type_declared(name: String, local: bool) {
		if local => is_local_type_declared(name)
		=> is_type_declared(name)
	}

	# Summary: Returns whether the specified function is declared inside this context or in the parent contexts depending on the specified flag
	is_function_declared(name: String, local: bool) {
		if local => is_local_function_declared(name)
		=> is_function_declared(name)
	}

	# Summary: Returns whether the specified variable is declared inside this context or in the parent contexts depending on the specified flag
	is_variable_declared(name: String, local: bool) {
		if local => is_local_variable_declared(name)
		=> is_variable_declared(name)
	}

	# Summary: Returns the specified type by searching it from the local types, imports and parent types
	get_type(name: String) {
		if types.contains_key(name) => types[name]

		loop (i = 0, i < imports.size, i++) {
			if imports[i].types.contains_key(name) {
				=> types[name]
			}
		}

		if parent != none => parent.get_type(name) as Type
		=> none as Type
	}

	# Summary: Returns the specified function by searching it from the local types, imports and parent types
	get_function(name: String) {
		if functions.contains_key(name) => functions[name]

		loop (i = 0, i < imports.size, i++) {
			if imports[i].functions.contains_key(name) {
				=> functions[name]
			}
		}

		if parent != none => parent.get_function(name) as FunctionList
		=> none as FunctionList
	}

	# Summary: Returns the specified variable by searching it from the local types, imports and parent types
	get_variable(name: String) {
		if variables.contains_key(name) => variables[name]

		loop (i = 0, i < imports.size, i++) {
			if imports[i].variables.contains_key(name) {
				=> variables[name]
			}
		}

		if parent != none => parent.get_variable(name) as Variable
		=> none as Variable
	}

	create_label() {
		=> Label(get_fullname() + '_I' + to_string(indexer.label))
	}

	create_stack_address() {
		=> String('stack.') + identity + '.' + to_string(indexer.stack)
	}

	# Summary: Moves all types, functions and variables from the specified context to this context
	merge(context: Context) {
		# Add all types
		loop type in context.types {
			types.add(type.key, type.value)
			type.value.parent = this
		}

		# Add all functions
		loop function in context.functions {
			# If the function can not be added, add all of its overloads
			if not functions.add(function.key, function.value) {
				overloads = functions[function.key]
				
				# Try to add the overloads separately
				loop overload in function.value.overloads {
					overloads.add(overload)
					overload.parent = this
				}

				continue
			}

			loop overload in function.value.overloads {
				overload.parent = this
			}
		}

		# Add all variables
		loop variable in context.variables {
			variables.add(variable.key, variable.value)
			variable.value.parent = this
		}

		# Add all subcontexts
		loop subcontext in context.subcontexts {
			exists = false

			loop other in subcontexts {
				if subcontext != other continue
				exists = true
				stop
			}

			if exists continue
			
			subcontext.parent = this
			subcontexts.add(subcontext)
		}

		update()
		context.destroy()
	}

	update() {}

	destroy() {
		if parent != none parent.subcontexts.remove(this)
		parent = none
	}
}

Function Constructor {
	is_default: bool

	static empty(context: Context, start: Position, end: Position) {
		constructor = Constructor(context, MODIFIER_DEFAULT, start, end, true)
		constructor.implement(List<Type>())
		=> constructor
	}

	init(context: Context, modifiers: normal, start: Position, end: Position, is_default: bool) {
		Function.init(context, modifiers, Keywords.INIT.identifier, start, end)
		this.type |= CONSTRUCTOR_CONTEXT_MODIFIER
		this.is_default = is_default
	}
}

Function Destructor {
	is_default: bool

	static empty(context: Context, start: Position, end: Position) {
		constructor = Destructor(context, MODIFIER_DEFAULT, start, end, true)
		constructor.implement(List<Type>())
		=> constructor
	}

	init(context: Context, modifiers: normal, start: Position, end: Position, is_default: bool) {
		Function.init(context, modifiers, Keywords.DEINIT.identifier, start, end)
		this.type |= DESTRUCTOR_CONTEXT_MODIFIER
		this.is_default = is_default
	}
}

RuntimeConfiguration {
	constant CONFIGURATION_VARIABLE = '.configuration'

	variable: Variable

	init(type: Type) {
		variable = type.declare(Link.get_variant(primitives.create_number(primitives.U64, FORMAT_UINT64)), VARIABLE_CATEGORY_MEMBER, String(CONFIGURATION_VARIABLE))
	}
}

Context Type {
	modifiers: normal
	position: Position
	format: large = SYSTEM_FORMAT
	template_arguments: List<Type> = List<Type>()

	initialization: Array<Node> = Array<Node>()

	constructors: FunctionList = FunctionList()
	destructors: FunctionList = FunctionList()
	supertypes: List<Type> = List<Type>()

	virtuals: Map<String, FunctionList> = Map<String, FunctionList>()
	overrides: Map<String, FunctionList> = Map<String, FunctionList>()

	configuration: RuntimeConfiguration

	is_resolved: bool = true

	is_primitive => has_flag(modifiers, MODIFIER_PRIMITIVE)
	is_number => has_flag(modifiers, MODIFIER_NUMBER)
	is_user_defined => not is_primitive and destructors.overloads.size > 0

	is_unresolved => not is_resolved
	is_static => has_flag(modifiers, MODIFIER_STATIC)
	
	is_generic_type => not has_flag(modifiers, MODIFIER_TEMPLATE_TYPE)
	is_template_type => has_flag(modifiers, MODIFIER_TEMPLATE_TYPE)

	reference_size: large = SYSTEM_BYTES

	# Summary: Returns how many bytes this type contains
	content_size() {
		bytes = 0

		loop variable in variables {
			if variable.value.is_static continue
			bytes += variable.value.type.reference_size
		}

		loop supertype in supertypes { bytes += supertype.content_size }

		=> bytes
	}

	init(identity: String) {
		Context.init(identity, TYPE_CONTEXT)
	}

	init(context: Context, name: String, modifiers: normal, position: Position) {
		Context.init(name, TYPE_CONTEXT)
		
		this.name = name
		this.identifier = name
		this.modifiers = modifiers
		this.position = position
		this.supertypes = List<Type>()

		add_constructor(Constructor.empty(this, position, position))
		add_destructor(Destructor.empty(this, position, position))

		connect(context)
		context.declare(this)
	}

	init(name: String, modifiers: normal) {
		Context.init(name, TYPE_CONTEXT)
		this.name = name
		this.identifier = name
		this.modifiers = modifiers
	}

	add_runtime_configuration() {
		if configuration != none return
		configuration = RuntimeConfiguration(this)
	}

	virtual clone() {
		abort('Type did not support cloning')
		=> none as Type
	}

	virtual get_accessor_type() {
		=> none as Type
	}

	add_constructor(constructor: Constructor) {
		if constructors.overloads.size <= 0 or not constructors.overloads[0].(Constructor).is_default {
			constructors.add(constructor)
			declare(constructor)
			return
		}

		# Remove all default constructors
		functions[Keywords.INIT.identifier].overloads.clear()
		constructors.overloads.clear()
		
		# Declare the specified constructor
		constructors.add(constructor)
		declare(constructor)
	}

	add_destructor(destructor: Destructor) {
		if not is_user_defined or not destructors.overloads[0].(Destructor).is_default {
			destructors.add(destructor)
			declare(destructor)
			return
		}

		# Remove all default destructors
		functions[Keywords.DEINIT.identifier].overloads.clear()
		destructors.overloads.clear()
		
		# Declare the specified destructor
		destructors.add(destructor)
		declare(destructor)
	}

	# Summary: Returns all supertypes this type inherits
	get_all_supertypes() {
		result = List<Type>(supertypes)
		loop supertype in supertypes { result.add_range(supertype.get_all_supertypes()) }
		=> result
	}

	is_supertype_declared(type: Type) {
		if supertypes.contains(type) => true
		loop supertype in supertypes { if supertype.is_supertype_declared(type) => true }
		=> false
	}

	is_super_function_declared(name: String) {
		loop supertype in supertypes { if supertype.is_local_function_declared(name) => true }
		=> false
	}

	# Summary: Returns whether the type contains a function, which overloads the specified operator
	is_operator_overloaded(operator: Operator) {
		if not Operators.operator_overloads.contains_key(operator) => false
		overload = Operators.operator_overloads[operator]
		=> is_local_function_declared(name) or is_super_function_declared(name)
	}

	is_type_inherited(type: Type) {
		loop supertype in supertypes {
			if supertype == type or supertype.is_type_inherited(type) => true
		}

		=> false
	}

	get_supertype_base_offset(type: Type) {
		position: large = 0
		if type == this => Optional<large>(position)

		loop supertype in supertypes {
			if supertype == type => Optional<large>(position)

			result = supertype.get_supertype_base_offset(type) as Optional<large>
			if result has offset => Optional<large>(position + offset)

			position += supertype.content_size
		}

		=> Optional<large>()
	}

	is_inheriting_allowed(inheritant: Type) {
		# Type must not inherit itself
		if inheritant == this => false

		# The inheritant should not have this type as its supertype
		inheritant_supertypes = inheritant.get_all_supertypes()
		if inheritant_supertypes.contains(this) => false

		# Deny the inheritance if supertypes already contain the inheritant or if any supertype would be duplicated
		inheritor_supertypes = get_all_supertypes()
		
		# The inheritor can inherit the same type multiple times
		if inheritor_supertypes.contains(inheritant) => false

		# Look for conflicts between the supertypes of the inheritor and the inheritant
		loop supertype in inheritant_supertypes {
			if inheritor_supertypes.contains(supertype) => false
		}

		=> true
	}

	get_register_format() {
		if format == FORMAT_DECIMAL => FORMAT_DECIMAL
		=> SYSTEM_FORMAT
	}

	virtual match(other: Type) {
		=> this.name == other.name and this.identity == other.identity
	}

	virtual string() {
		names = List<String>()
		loop iterator in get_parent_types() { names.add(iterator.name) }
		names.add(name)
		=> String.join(`.`, names)
	}
}

Variable {
	name: String
	type: Type
	category: normal
	modifiers: normal
	position: Position
	parent: Context
	alignment: normal = 0
	is_self_pointer: bool = false
	usages: List<Node> = List<Node>()
	writes: List<Node> = List<Node>()
	reads: List<Node> = List<Node>()

	is_constant => has_flag(modifiers, MODIFIER_CONSTANT)
	is_public => has_flag(modifiers, MODIFIER_PUBLIC)
	is_protected => has_flag(modifiers, MODIFIER_PROTECTED)
	is_private => has_flag(modifiers, MODIFIER_PRIVATE)
	is_static => has_flag(modifiers, MODIFIER_STATIC)
	
	is_global => category == VARIABLE_CATEGORY_GLOBAL
	is_local => category == VARIABLE_CATEGORY_LOCAL
	is_parameter => category == VARIABLE_CATEGORY_PARAMETER
	is_member => category == VARIABLE_CATEGORY_MEMBER
	is_predictable => category == VARIABLE_CATEGORY_LOCAL or category == VARIABLE_CATEGORY_PARAMETER

	is_hidden => name.index_of(`.`) != -1
	is_generated => position == none

	is_unresolved => type == none or type.is_unresolved
	is_resolved => type != none and type.is_resolved

	# TODO: Inline support
	is_inlined => false

	init(parent: Context, type: Type, category: normal, name: String, modifiers: normal) {
		this.name = name
		this.type = type
		this.category = category
		this.modifiers = modifiers
		this.parent = parent
	}

	# Summary: Returns whether this variable is edited inside the specified node
	is_edited_inside(node: Node) {
		loop write in writes {
			# If one of the parent nodes of the current write is the specified node, then this variable is edited inside the specified node
			loop (iterator = write.parent, iterator != none, iterator = iterator.parent) {
				if iterator == node => true
			}
		}

		=> false
	}

	# Summary: Returns the alignment compared to the specified parent type
	get_alignment(parent: Type) {
		if this.parent == parent {
			alignment: large = 0
			loop supertype in parent.supertypes { alignment += supertype.content_size }
			alignment += this.alignment
			=> alignment
		}

		position: large = 0

		loop supertype in parent.supertypes {
			alignment: large = get_alignment(supertype)
			if alignment >= 0 => position + alignment

			position += supertype.content_size
		}

		=> -1
	}
}

FunctionList {
	overloads: List<Function> = List<Function>()

	# Summary: Tries to add the specified function. Returns the conflicting function, which prevents adding the specified function, if one exists.
	add(function: Function) {
		# Conflicts can only happen with functions which are similar kind (either a template function or a standard function) and have the same amount of parameters
		is_template_function = function.is_template_function
		count = function.parameters.size

		loop overload in overloads {
			if overload.parameters.size != count or overload.is_template_function != is_template_function continue
			pass = false

			loop (i = 0, i < count, i++) {
				x = function.parameters[i].type
				y = overload.parameters[i].type
				if x == none or y == none or x == y continue
				pass = true
				stop
			}

			if not pass => overload
		}

		overloads.add(function)
		=> none as Function
	}

	# Summary: Returns the number of casts needed to call the specified function candidate with the specified parameter types
	get_cast_count(candidate: Function, parameter_types: List<Type>) {
		casts = 0

		loop (i = 0, i < parameter_types.size, i++) {
			if candidate.parameters[i].type != none or candidate.parameters[i].type == parameter_types[i] continue
			casts++
		}

		=> casts
	}

	get_overload(parameter_types: List<Type>, template_arguments: List<Type>) {
		candidates = List<Function>()

		if template_arguments.size > 0 {
			loop overload in overloads {
				if not overload.is_template_function or not overload.(TemplateFunction).passes(parameter_types, template_arguments) continue
				candidates.add(overload)
			}
		}
		else {
			loop overload in overloads {
				if overload.is_template_function or not overload.passes(parameter_types) continue
				candidates.add(overload)
			}
		}

		if candidates.size == 0 => none as Function
		if candidates.size == 1 => candidates[0]

		minimum_candidate =  candidates[0]
		minimum_casts = get_cast_count(minimum_candidate, parameter_types)

		loop (i = 1, i < candidates.size, i++) {
			candidate = candidates[i]
			casts = get_cast_count(candidate, parameter_types)

			if casts >= minimum_casts continue

			minimum_candidate = candidate
			minimum_casts = casts
		}

		=> minimum_candidate
	}

	get_overload(parameter_types: List<Type>) {
		=> get_overload(parameter_types, List<Type>(0))
	}

	get_implementation(parameter_types: List<Type>, template_arguments: List<Type>) {
		overload = get_overload(parameter_types, template_arguments)
		if overload == none => none as FunctionImplementation
		if template_arguments.size > 0 => overload.(TemplateFunction).get(parameter_types, template_arguments)
		=> overload.get(parameter_types)
	}

	get_implementation(parameter_types: List<Type>) {
		=> get_implementation(parameter_types, List<Type>(0, false))
	}

	get_implementation(parameter: Type) {
		parameter_types = List<Type>()
		parameter_types.add(parameter)
		=> get_implementation(parameter_types, List<Type>(0, false))
	}
}

Parameter {
	name: String
	position: Position
	type: Type

	init(name: String, type: Type) {
		this.name = name
		this.position = none
		this.type = type
	}

	init(name: String, position: Position, type: Type) {
		this.name = name
		this.position = position
		this.type = type
	}

	export_string() {
		if type == none => name
		=> name + ': ' + type.string()
	}

	string() {
		if type == none => name + ': any'
		=> name + ': ' + type.string()
	}
}

Context Function {
	modifiers: normal
	language: normal = LANGUAGE_VIVID

	self: Variable
	parameters: List<Parameter>
	blueprint: List<Token>
	start: Position
	end: Position

	implementations: List<FunctionImplementation> = List<FunctionImplementation>()

	is_constructor => has_flag(type, CONSTRUCTOR_CONTEXT_MODIFIER)
	is_public => has_flag(modifiers, MODIFIER_PUBLIC)
	is_protected => has_flag(modifiers, MODIFIER_PROTECTED)
	is_private => has_flag(modifiers, MODIFIER_PRIVATE)
	is_static => has_flag(modifiers, MODIFIER_STATIC)
	is_imported => has_flag(modifiers, MODIFIER_IMPORTED)
	is_exported => has_flag(modifiers, MODIFIER_EXPORTED)
	is_outlined => has_flag(modifiers, MODIFIER_OUTLINE)
	is_template_function => has_flag(modifiers, MODIFIER_TEMPLATE_FUNCTION)

	init(parent: Context, modifiers: normal, name: String, blueprint: List<Token>, start: Position, end: Position) {
		Context.init(parent, FUNCTION_CONTEXT)

		this.name = name
		this.modifiers = modifiers
		this.parameters = List<Parameter>()
		this.blueprint = blueprint
		this.start = start
		this.end = end
	}

	init(parent: Context, modifiers: normal, name: String, start: Position, end: Position) {
		Context.init(parent, FUNCTION_CONTEXT)

		this.name = name
		this.modifiers = modifiers
		this.parameters = List<Parameter>()
		this.blueprint = List<Token>()
		this.start = start
		this.end = end
	}

	init(parent: Context, modifiers: normal, name: String, return_type: Type, parameters: List<Parameter>) {
		Context.init(parent, FUNCTION_CONTEXT)

		this.name = name
		this.modifiers = modifiers
		this.parameters = parameters
		this.blueprint = List<Token>()

		implementation = FunctionImplementation(this, return_type, parent)
		implementation.set_parameters(parameters)
		implementations.add(implementation)

		implementation.implement(blueprint)
	}

	# Summary: Implements the function with the specified parameter type
	implement(type: Type) {
		parameter_types = List<Type>()
		parameter_types.add(type)
		=> implement(parameter_types)
	}

	# Summary: Implements the function with the specified parameter types
	implement(parameter_types: List<Type>) {
		implementation_parameters = List<Parameter>(types.size, false)

		# Pack parameters with names and types
		loop (i = 0, i < parameters.size, i++) {
			implementation_parameters.add(Parameter(parameters[i].name, parameter_types[i]))
		}

		# Create a function implementation
		implementation = FunctionImplementation(this, none as Type, parent)
		implementation.set_parameters(implementation_parameters)

		# Add the created implementation to the list
		implementations.add(implementation)

		implementation.implement(clone(blueprint))

		=> implementation
	}

	# Summary: Returns whether the specified parameter types can be used to implement this function
	passes(types: List<Type>) {
		if types.size != parameters.size => false

		loop (i = 0, i < parameters.size, i++) {
			expected = parameters[i].type
			if expected == none continue

			actual = types[i]
			if expected == actual continue

			if not expected.is_primitive or not actual.is_primitive {
				if not expected.is_type_inherited(actual) and not actual.is_type_inherited(expected) => false
			} 
			else resolver.get_shared_type(expected, actual) == none => false
		}

		=> true
	}

	# Summary: Returns whether the specified parameter types can be used to implement this function
	passes(types: List<Type>, template_arguments: Array<Type>) {
		if template_arguments.count > 0 => is_template_function and this.(TemplateFunction).passes(types, template_arguments)
		=> not is_template_function and passes(types)
	}

	# Summary: Tries to find function implementation with the specified parameter type
	get(type: Type) {
		parameter_types = List<Type>()
		parameter_types.add(type)
		=> get(parameter_types)
	}

	# Summary: Tries to find function implementation with the specified parameter types
	get(parameter_types: List<Type>) {
		if parameter_types.size != parameters.size => none as FunctionImplementation

		# Implementation should not be made if any of the parameters has a fixed type but it is unresolved
		loop parameter_type in parameter_types {
			if parameter_type == none or parameter_type.is_unresolved => none as FunctionImplementation
		}

		implementation_types = List<Type>(parameter_types.size, false)

		# Override the parameter types with forced parameter types
		loop (i = 0, i < parameter_types.size, i++) {
			parameter_type = parameters[i].type
			if parameter_type != none { implementation_types[i] = parameter_type }
			else { implementation_types[i] = parameter_types[i] }
		}

		# Try to find an implementation which already has the specified parameter types
		loop implementation in implementations {
			matches = true

			loop (i = 0, i < implementation_types.size, i++) {
				a = implementation_types[i]
				b = implementation.parameters[i].type

				if a != b {
					matches = false
					stop
				}
			}

			if matches => implementation
		}

		if is_imported => none as FunctionImplementation

		=> implement(implementation_types)
	}
}

Type TemplateType {
	blueprint: List<Token>
	template_parameters: List<String>

	init(context: Context, name: String, modifiers: normal, blueprint: List<Token>, template_parameters: List<String>, position: Position) {
		Type.init(context, name, modifiers | MODIFIER_TEMPLATE_TYPE, position)
		this.blueprint = blueprint
		this.template_parameters = template_parameters
	}

	init(context: Context, name: String, modifiers: normal, argument_count: large) {
		Type.init(context, name, modifiers | MODIFIER_TEMPLATE_TYPE)
		
		# Create an empty type with the specified name using tokens
		blueprint = List<Token>()
		blueprint.add(IdentifierToken(name))
		blueprint.add(ParenthesisToken(`{`, none, none, List<Token>()))

		# Generate the template arguments
		loop (i = 0, i < argument_count, i++) {
			template_arguments.add(String(`T`) + to_string(i))
		}
	}

	try_get_variant(arguments: List<Type>) {
		abort('Getting template type variants is not supported')
		=> none as Type
	}

	create_variant(arguments: List<Type>) {
		abort('Creating template type variants is not supported')
		=> none as Type
	}

	# Summary: Returns a variant with the specified template arguments, creating it if necessary
	get_variant(arguments: List<Type>) {
		if arguments.size < template_parameters.size => none as Type
		variant = try_get_variant(arguments)
		if variant != none => variant
		=> create_variant(arguments) 
	}
}

Function TemplateFunction {
	template_parameters: List<String>
	header: FunctionToken
	variants: Map<String, Function> = Map<String, Function>()

	init(parent: Context, modifiers: normal, name: String, template_parameters: List<String>, parameter_tokens: List<Token>, start: Position, end: Position) {
		Function.init(parent, modifiers | MODIFIER_TEMPLATE_FUNCTION, name, start, end)

		this.template_parameters = template_parameters
		this.header = FunctionToken(IdentifierToken(name), ParenthesisToken(parameter_tokens))
	}

	init(context: Context, modifiers: large, name: String, parameters: large, arguments: large) {
		Function.init(context, modifiers | MODIFIER_TEMPLATE_FUNCTION, name, none as Position, none as Position)

		# Generate parameter names based on the specified parameter count
		parameter_tokens = List<Token>(parameters, false)

		loop (i = 0, i < parameters, i++) {
			parameter_tokens.add(IdentifierToken(String('P') + to_string(i)))
			parameter_tokens.add(OperatorToken(Operators.COMMA))
		}

		# Remove the unncecessary comma from the end
		if parameters > 0 parameters.remove_at(parameters.size - 1)

		header = FunctionToken(IdentifierToken(name), ParenthesisToken(parameter_tokens))
	}

	# Summary: Creates the parameters of this function in a way that they do not have types
	initialize() {
		result = header.get_parameters(Context(String.empty, FUNCTION_CONTEXT))

		if result has parameters {
			parameters.add_range(parameters)
			=> true
		}

		=> false
	}

	try_get_variant(template_arguments: List<Type>) {
		names = List<String>()
		loop template_argument in template_arguments { names.add(template_argument.string()) }
		identifier = String.join(String(', '), names)

		if variants.contains_key(identifier) => variants[identifier]
		=> none as FunctionImplementation
	}

	insert_arguments(tokens: List<Token>, arguments: List<Type>) {
		loop (i = 0, i < tokens.size, i++) {
			token = tokens[i]

			if token.type == TOKEN_TYPE_IDENTIFIER {
				j = template_parameters.index_of(token.(IdentifierToken).value)
				if j == -1 continue

				position = token.position

				tokens.remove_at(i)
				tokens.insert_range(i, common.get_tokens(arguments[j], position))
			}
			else token.type == TOKEN_TYPE_FUNCTION {
				insert_arguments(token.(FunctionToken).parameters.tokens, arguments)
			}
			else token.type == TOKEN_TYPE_PARENTHESIS {
				insert_arguments(token.(ParenthesisToken).tokens, arguments)
			}
		}
	}

	create_variant(template_arguments: List<Type>) {
		names = List<String>()
		loop template_argument in template_arguments { names.add(template_argument.string()) }
		identifier = String.join(String(', '), names)

		# Copy the blueprint and insert the specified arguments to their places
		blueprint: List<Token> = clone(this.blueprint)
		blueprint[0].(FunctionToken).identifier.value = name + `<` + identifier + `>`

		insert_arguments(blueprint, template_arguments)

		# Parse the new variant
		result = parser.parse(parent, blueprint, 0, parser.MAX_PRIORITY).first
		if result == none or result.instance != NODE_FUNCTION_DEFINITION abort('Invalid template function blueprint')

		# Register the new variant
		variant = result.(FunctionDefinitionNode).function
		variants.add(identifier, variant)
		=> variant
	}

	passes(types: List<Type>) {
		=> abort('Tried to execute pass function without template parameters') as bool
	}

	passes(actual_types: List<Type>, template_arguments: List<Type>) {
		if template_arguments.size != template_parameters.size => false

		# None of the types can be unresolved
		loop type in actual_types { if type.is_unresolved => false }
		loop type in template_arguments { if type.is_unresolved => false }

		# Clone the header, insert the template arguments and determine the expected parameters
		header: FunctionToken = this.header.clone() as FunctionToken
		insert_arguments(header.parameters.tokens, template_arguments)

		if not (header.get_parameters(Context(this, FUNCTION_CONTEXT)) has expected_parameters) => false
		if expected_parameters.size != actual_types.size => false

		loop (i = 0, i < actual_types.size, i++) {
			expected = expected_parameters[i].type
			if expected == none continue

			actual = actual_types[i]
			if expected.match(actual) continue

			# If both types are not primitives, either a upcast or downcast must be possible
			if not expected.is_primitive and not actual.is_primitive {
				if not expected.is_type_inherited(actual) and not actual.is_type_inherited(expected) => false
			}
			else resolver.get_shared_type(expected, actual) == none {
				=> false
			}
		}

		=> true
	}

	get(parameter_types: List<Type>) {
		=> abort('Tried to get overload of template function without template arguments') as FunctionImplementation
	}

	get(parameter_types: List<Type>, template_arguments: List<Type>) {
		if template_arguments.size != template_parameters.size abort('Missing template arguments')

		variant = try_get_variant(template_arguments)

		if variant == none {
			variant = create_variant(template_arguments)
			if variant == none => none as FunctionImplementation
		}

		implementation = variant.get(parameter_types)
		implementation.identifier = name
		implementation.metadata.modifiers = modifiers
		implementation.template_arguments = template_arguments
		=> implementation
	}
}

Context FunctionImplementation {
	metadata: Function
	node: Node
	
	self: Variable
	template_arguments: List<Type>
	return_type: Type

	is_constructor => metadata.is_constructor
	is_static => metadata.is_static
	is_empty => (node == none or node.first == none) and not metadata.is_imported

	parameters() {
		result = List<Variable>()

		loop iterator in variables {
			variable = iterator.value
			if not variable.is_parameter or variable.is_self_pointer continue
			result.add(variable)
		}

		=> result
	}

	parameter_types() {
		result = List<Type>()
		loop iterator in parameters() { result.add(iterator.type) }
		=> result
	}

	init(metadata: Function, return_type: Type, parent: Context) {
		Context.init(parent, IMPLEMENTATION_CONTEXT)

		this.metadata = metadata
		this.return_type = return_type
		this.template_arguments = List<Type>(0, false)

		this.name = metadata.name
		this.identifier = metadata.identifier
		
		connect(parent)
	}

	override get_self_pointer() {
		=> self
	}

	# Summary: Sets the function parameters
	set_parameters(parameters: List<Parameter>) {
		loop parameter in parameters {
			variable = Variable(this, parameter.type, VARIABLE_CATEGORY_PARAMETER, parameter.name, MODIFIER_DEFAULT)

			if variables.contains_key(variable.name) => Status('Parameter with the same name already exists')

			variables.add(variable.name, variable)
		}

		=> Status()
	}

	# Summary: Implements the function using the given blueprint
	implement(blueprint: List<Token>) {
		if metadata.is_member and not metadata.is_static {
			self = Variable(this, metadata.find_type_parent(), VARIABLE_CATEGORY_PARAMETER, String(SELF_POINTER_IDENTIFIER), MODIFIER_DEFAULT)
			self.is_self_pointer = true
			self.position = metadata.start
			declare(self)
		}

		node = ScopeNode(this, metadata.start, metadata.end)
		parser.parse(node, this, blueprint, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
	}

	override get_fullname() {
		=> metadata.name
	}
}

Label {
	name: String

	init(name: String) {
		this.name = name
	}

	string() {
		=> name
	}
}

UnresolvedTypeComponent {
	identifier: String
	arguments: List<Type>

	init(identifier: String, arguments: List<Type>) {
		this.identifier = identifier
		this.arguments = arguments
	}

	init(identifier: String) {
		this.identifier = identifier
		this.arguments = List<Type>()
	}

	resolve(context: Context) {
		# Resolve the template arguments
		loop (i = 0, i < arguments.size, i++) {
			argument = arguments[i]
			if argument.is_resolved continue

			replacement = argument.(UnresolvedType).try_resolve_type(context)
			if replacement == none continue

			arguments[i] = replacement
		}
	}
}

Type UnresolvedType {
	components: List<UnresolvedTypeComponent>
	count: ParenthesisToken

	init(identifier: String) {
		Type.init(String.empty, MODIFIER_DEFAULT)
		this.components = List<UnresolvedTypeComponent>()
		this.components.add(UnresolvedTypeComponent(identifier))
		this.is_resolved = false
	}

	init(components: List<UnresolvedTypeComponent>) {
		Type.init(String.empty, MODIFIER_DEFAULT)
		this.components = components
		this.is_resolved = false
	}

	resolve(context: Context) {
		environment = context

		loop component in components {
			component.resolve(environment)

			local = component != components[0]
			if not context.is_type_declared(component.identifier, local) => none as TypeNode

			component_type = context.get_type(component.identifier)

			if component.arguments.size == 0 {
				context = component_type
				continue
			}

			# Require all of the arguments to be resolved
			loop arguments in component.arguments {
				if arguments.is_unresolved => none as TypeNode
			}

			# Since the component has template arguments, the type must be a template type
			if component_type.is_generic_type => none as TypeNode

			if not component_type.is_primitive {
				# Get a variant of the template type using the arguments of the component
				context = component_type.(TemplateType).get_variant(component.arguments)
			}
			else {
				# Some base types are 'manual template types' such as link meaning they can still receive template arguments even though they are not instances of a template type class
				component_type = component_type.clone()
				component_type.template_arguments = component.arguments
				context = component_type
			}
		}

		if count != none abort('Array types are not supported')
		=> TypeNode(context as Type)
	}

	try_resolve_type(context: Context) {
		result = resolve(context)
		if result == none => none as Type
		=> result.try_get_type()
	}
}