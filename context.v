VARIABLE_CATEGORY_LOCAL = 0
VARIABLE_CATEGORY_PARAMETER = 1
VARIABLE_CATEGORY_MEMBER = 2
VARIABLE_CATEGORY_GLOBAL = 3

NORMAL_CONTEXT = 1
TYPE_CONTEXT = 1 <| 1
FUNCTION_CONTEXT = 1 <| 2
IMPLEMENTATION_CONTEXT = 1 <| 3

LAMBDA_CONTEXT_MODIFIER = 1 <| 4
CONSTRUCTOR_CONTEXT_MODIFIER = 1 <| 5
DESTRUCTOR_CONTEXT_MODIFIER = 1 <| 6

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
	private string_count = 0
	private lambda_count = 0
	private constant_value_count = 0
	private scope_count = 0

	context => context_count++
	hidden => hidden_count++
	stack => stack_count++
	label => label_count++
	identity => identity_count++
	string => string_count++
	lambda => lambda_count++
	constant_value => constant_value_count++
	scope => scope_count++
}

Context {
	identity: String
	identifier: String
	name: String
	mangle: Mangle
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

	all_variables() {
		result = List<Variable>()

		loop iterator in variables {
			variable = iterator.value
			if variable.category != VARIABLE_CATEGORY_LOCAL and variable.category != VARIABLE_CATEGORY_PARAMETER continue
			result.add(variable)
		}

		loop subcontext in subcontexts {
			if subcontext.type !== NORMAL_CONTEXT continue
			result.add_all(subcontext.all_variables)
		}

		return result
	}

	locals() {
		result = List<Variable>()

		loop iterator in variables {
			variable = iterator.value
			if variable.category != VARIABLE_CATEGORY_LOCAL continue
			result.add(variable)
		}

		loop subcontext in subcontexts {
			if subcontext.type !== NORMAL_CONTEXT continue
			result.add_all(subcontext.locals)
		}

		return result
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

	init(identity: String, type: normal, profile: tiny) {
		this.identity = identity
		this.type = type
		this.identifier = String.empty
		this.name = String.empty
		this.variables = Map<String, Variable>(profile)
		this.functions = Map<String, FunctionList>(profile)
		this.types = Map<String, Type>(profile)
		this.labels = Map<String, Label>(profile)
		this.subcontexts = List<Context>()
		this.imports = List<Type>()
		this.indexer = Indexer()
	}

	# Summary: Returns the mangled name of this context
	get_fullname() {
		if mangle == none {
			mangle = Mangle(none as Mangle)
			on_mangle(mangle)
		}
		
		return mangle.value
	}

	virtual on_mangle(mangle: Mangle) {}

	# Summary: Tries to find the self pointer variable
	virtual get_self_pointer() {
		if parent != none return parent.get_self_pointer() as Variable
		return none as Variable
	}

	# Summary: Adds this context under the specified context
	connect(context: Context) {
		parent = context
		parent.subcontexts.add(this)
	}

	# Summary: Declares the specified type
	declare(type: Type) {
		if types.contains_key(type.name) return false

		type.parent = this
		types.add(type.name, type)
		return true
	}

	# Summary: Declares the specified function
	declare(function: Function) {
		if functions.contains_key(function.name) {
			entry = functions[function.name]
			return entry.add(function)
		}

		entry = FunctionList()
		functions.add(function.name, entry)
		return entry.add(function)
	}

	# Summary: Declares the specified variable
	declare(variable: Variable) {
		if variables.contains_key(variable.name) return false

		variable.parent = this
		variables.add(variable.name, variable)
		return true
	}

	# Summary: Declares a variable into the context
	declare(type: Type, category: large, name: String) {
		if variables.contains_key(name) return none as Variable
		variable = Variable(this, type, category, name, MODIFIER_DEFAULT)
		if not declare(variable) return none as Variable
		return variable
	}

	# Summary: Declares a hidden variable with the specified type
	declare_hidden(type: Type) {
		variable = Variable(this, type, VARIABLE_CATEGORY_LOCAL, identity + '.' + to_string(indexer.hidden), MODIFIER_DEFAULT)
		declare(variable)
		return variable
	}

	# Summary: Declares a hidden variable with the specified type
	declare_hidden(type: Type, category: large) {
		variable = Variable(this, type, category, identity + '.' + to_string(indexer.hidden), MODIFIER_DEFAULT)
		declare(variable)
		return variable
	}

	# Summary: Declares an unnamed pack type
	declare_unnamed_pack(position: Position) {
		return Type(this, identity + '.' + to_string(indexer.hidden), MODIFIER_PACK, position)
	}

	# Summary: Declares an already existing type with different name
	declare_type_alias(alias: String, type: Type) {
		if is_local_type_declared(alias) return false
		types.add(alias, type)
		return true
	}

	# Summary: Tries to find the first parent context which is a type
	find_type_parent() {
		if is_type return this as Type

		iterator = parent

		loop (iterator != none) {
			if iterator.is_type return iterator as Type
			iterator = iterator.parent
		}

		return none as Type
	}

	# Summary: Tries to find the first parent context which is a function implementation
	find_implementation_parent() {
		if is_implementation return this as FunctionImplementation

		iterator = parent

		loop (iterator != none) {
			if iterator.is_implementation return iterator as FunctionImplementation
			iterator = iterator.parent
		}

		return none as FunctionImplementation
	}

	# Summary: Returns all parent contexts, which represent types
	get_parent_types() {
		result = List<Type>()
		iterator = parent

		loop (iterator != none) {
			if iterator.is_type result.add(iterator as Type)
			iterator = iterator.parent
		}

		result.reverse()
		return result
	}

	# Summary: Returns whether the specified context is this context or one of the parent contexts
	is_inside(context: Context) {
		return context == this or (parent != none and parent.is_inside(context))
	}

	# Summary: Returns whether the specified type is declared inside this context
	is_local_type_declared(name: String) {
		return types.contains_key(name)
	}

	# Summary: Returns whether the specified function is declared inside this context
	is_local_function_declared_default(name: String) {
		return functions.contains_key(name)
	}

	# Summary: Returns whether the specified function is declared inside this context
	virtual is_local_function_declared(name: String) {
		return is_local_function_declared_default(name)
	}

	# Summary: Returns whether the specified variable is declared inside this context
	is_local_variable_declared_default(name: String) {
		return variables.contains_key(name)
	}

	# Summary: Returns whether the specified variable is declared inside this context
	virtual is_local_variable_declared(name: String) {
		return is_local_variable_declared_default(name)
	}

	# Summary: Returns whether the specified property is declared inside this context
	is_local_property_declared(name: String) {
		return is_local_function_declared(name) and get_function(name).get_overload(List<Type>()) != none
	}

	# Summary: Returns whether the specified type is declared inside this context or in the parent contexts
	is_type_declared(name: String) {
		if types.contains_key(name) return true

		loop (i = 0, i < imports.size, i++) {
			if imports[i].is_local_type_declared(name) return true
		}

		return parent != none and parent.is_type_declared(name)
	}

	# Summary: Returns whether the specified function is declared inside this context or in the parent contexts
	is_function_declared_default(name: String) {
		if functions.contains_key(name) return true

		loop (i = 0, i < imports.size, i++) {
			if imports[i].is_local_function_declared(name) return true
		}

		return parent != none and parent.is_function_declared(name)
	}

	# Summary: Returns whether the specified function is declared inside this context or in the parent contexts
	virtual is_function_declared(name: String) {
		return is_function_declared_default(name)
	}

	# Summary: Returns whether the specified variable is declared inside this context or in the parent contexts
	is_variable_declared_default(name: String) {
		if variables.contains_key(name) return true

		loop (i = 0, i < imports.size, i++) {
			if imports[i].is_local_variable_declared(name) return true
		}

		return parent != none and parent.is_variable_declared(name)
	}

	# Summary: Returns whether the specified variable is declared inside this context or in the parent contexts
	virtual is_variable_declared(name: String) {
		return is_variable_declared_default(name)
	}

	# Summary: Returns whether the specified property is declared inside this context or in the parent contexts
	is_property_declared(name: String) {
		return is_function_declared(name) and get_function(name).get_overload(List<Type>()) != none
	}

	# Summary: Returns whether the specified type is declared inside this context or in the parent contexts depending on the specified flag
	is_type_declared(name: String, local: bool) {
		if local return is_local_type_declared(name)
		return is_type_declared(name)
	}

	# Summary: Returns whether the specified function is declared inside this context or in the parent contexts depending on the specified flag
	is_function_declared(name: String, local: bool) {
		if local return is_local_function_declared(name)
		return is_function_declared(name)
	}

	# Summary: Returns whether the specified variable is declared inside this context or in the parent contexts depending on the specified flag
	is_variable_declared(name: String, local: bool) {
		if local return is_local_variable_declared(name)
		return is_variable_declared(name)
	}

	# Summary: Returns whether the specified property is declared inside this context or in the parent contexts depending on the specified flag
	is_property_declared(name: String, local: bool) {
		if local return is_local_property_declared(name)
		return is_property_declared(name)
	}

	# Summary: Returns the specified type by searching it from the local types, imports and parent types
	get_type(name: String) {
		if types.contains_key(name) return types[name]

		loop (i = 0, i < imports.size, i++) {
			if imports[i].types.contains_key(name) {
				return types[name]
			}
		}

		if parent != none return parent.get_type(name) as Type
		return none as Type
	}

	# Summary: Returns the specified function by searching it from the local types, imports and parent types
	get_function_default(name: String) {
		if functions.contains_key(name) return functions[name]

		loop (i = 0, i < imports.size, i++) {
			if imports[i].functions.contains_key(name) {
				return functions[name]
			}
		}

		if parent != none return parent.get_function(name) as FunctionList
		return none as FunctionList
	}

	# Summary: Returns the specified function by searching it from the local types, imports and parent types
	virtual get_function(name: String) {
		return get_function_default(name)
	}

	# Summary: Returns the specified variable by searching it from the local types, imports and parent types
	get_variable_default(name: String) {
		if variables.contains_key(name) return variables[name]

		loop (i = 0, i < imports.size, i++) {
			if imports[i].variables.contains_key(name) {
				return variables[name]
			}
		}

		if parent != none return parent.get_variable(name) as Variable
		return none as Variable
	}

	# Summary: Returns the specified variable by searching it from the local types, imports and parent types
	virtual get_variable(name: String) {
		return get_variable_default(name)
	}

	# Summary: Returns the specified property by searching it from the local types, imports and parent types
	get_property(name: String) {
		return get_function(name).get_overload(List<Type>())
	}

	create_label() {
		return Label(get_fullname() + '_I' + to_string(indexer.label))
	}

	create_stack_address() {
		return "stack." + identity + '.' + to_string(indexer.stack)
	}

	create_lambda() {
		return indexer.lambda
	}

	create_identity() {
		return identity + `.` + to_string(indexer.context)
	}

	# Summary: Moves all types, functions and variables from the specified context to this context
	merge(context: Context) {
		# Add all types
		loop type in context.types {
			types.try_add(type.key, type.value)
			type.value.parent = this
		}

		# Add all functions
		loop function in context.functions {
			# If the function can not be added, add all of its overloads
			if not functions.try_add(function.key, function.value) {
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
			variables.try_add(variable.key, variable.value)
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

	default_dispose() {
		variables.clear()
		functions.clear()
		types.clear()
		labels.clear()
		imports.clear()

		distinct_subcontexts = List<Context>(subcontexts).distinct()

		loop subcontext in distinct_subcontexts {
			subcontext.dispose()
		}

		subcontexts.clear()
	}

	virtual dispose() {
		default_dispose()
	}

	virtual string() {
		return String.empty
	}
}

Function Constructor {
	is_default: bool

	static empty(context: Context, start: Position, end: Position) {
		constructor = Constructor(context, MODIFIER_DEFAULT, start, end, true)
		return constructor
	}

	init(context: Context, modifiers: normal, start: Position, end: Position, is_default: bool) {
		Function.init(context, modifiers, Keywords.INIT.identifier, start, end)
		this.type |= CONSTRUCTOR_CONTEXT_MODIFIER
		this.is_default = is_default
	}

	# Summary: Adds the member variable initializations to the specified constructor implementation
	add_member_initializations(implementation: FunctionImplementation) {
		root = implementation.node
		parent: Type = this.parent as Type

		loop (i = parent.initialization.size - 1, i >= 0, i--) {
			initialization = parent.initialization[i].clone()

			# Skip initializations of static and constant variables
			if initialization.match(Operators.ASSIGN) {
				edited = common.get_edited(initialization)

				if edited.match(NODE_VARIABLE) {
					variable = edited.(VariableNode).variable
					if variable.is_static or variable.is_constant continue
				}
			}

			# Find all member accesses, which do not use the self pointer but require it
			self_pointer_node = common.get_self_pointer(implementation, none as Position)
			member_accessors = initialization.find_all(i -> common.is_self_pointer_required(i))

			# Add self pointer to all member accessors
			loop member_accessor in member_accessors {
				member_accessor.replace(LinkNode(self_pointer_node.clone(), member_accessor.clone()))
			}

			root.insert(root.first, initialization)
		}
	}

	# Summary: Adds the member variable initializations for all existing implementations.
	# NOTE: This should not be executed twice, as it will cause duplicate initializations.
	add_member_initializations() {
		loop implementation in implementations {
			add_member_initializations(implementation)
		}
	}

	override implement(types: List<Type>) {
		# Implement the constructor and then add the parent type initializations to the beginning of the function body
		implementation = Function.implement_default(types)
		implementation.return_type = primitives.create_unit()
		add_member_initializations(implementation)
		return implementation
	}
}

Function Destructor {
	is_default: bool

	static empty(context: Context, start: Position, end: Position) {
		constructor = Destructor(context, MODIFIER_DEFAULT, start, end, true)
		return constructor
	}

	init(context: Context, modifiers: normal, start: Position, end: Position, is_default: bool) {
		Function.init(context, modifiers, Keywords.DEINIT.identifier, start, end)
		this.type |= DESTRUCTOR_CONTEXT_MODIFIER
		this.is_default = is_default
	}

	override implement(types: List<Type>) {
		implementation = Function.implement_default(types)
		implementation.return_type = primitives.create_unit()
		return implementation
	}
}

RuntimeConfiguration {
	constant CONFIGURATION_VARIABLE = '.configuration'

	entry: Table
	descriptor: Table

	variable: Variable
	references: Variable

	is_completed: bool = false

	get_fullname(type: Type) {
		builder = StringBuilder()
		builder.append(type.name)

		supertypes = List<String>()
		loop supertype in type.get_all_supertypes() { supertypes.add(supertype.name) }

		builder.append('\\x00')
		builder.append(String.join("\\x00", supertypes))
		builder.append('\\x01')

		return builder.string()
	}

	init(type: Type) {
		variable = type.(Context).declare(Link.get_variant(primitives.create_number(primitives.U64, FORMAT_UINT64)), VARIABLE_CATEGORY_MEMBER, String(CONFIGURATION_VARIABLE))
		entry = Table(type.get_fullname() + 'CE')
		descriptor = Table(type.get_fullname() + 'DE')

		entry.add(descriptor)
		descriptor.add(StringTableItem(get_fullname(type)), false)
	}
}

Context Type {
	modifiers: normal
	position: Position
	format: large = SYSTEM_FORMAT
	template_arguments: List<Type> = List<Type>()

	initialization: List<Node> = List<Node>()

	constructors: FunctionList = FunctionList()
	destructors: FunctionList = FunctionList()
	supertypes: List<Type> = List<Type>()

	virtuals: Map<String, FunctionList>
	overrides: Map<String, FunctionList>

	configuration: RuntimeConfiguration

	is_resolved: bool = true

	is_primitive => has_flag(modifiers, MODIFIER_PRIMITIVE)
	is_imported => has_flag(modifiers, MODIFIER_IMPORTED)
	is_exported => has_flag(modifiers, MODIFIER_EXPORTED)
	is_user_defined => not is_primitive and destructors.overloads.size > 0

	is_unresolved => not is_resolved
	is_inlining => has_flag(modifiers, MODIFIER_INLINE)
	is_static => has_flag(modifiers, MODIFIER_STATIC)
	is_plain => has_flag(modifiers, MODIFIER_PLAIN)
	
	is_generic_type => not has_flag(modifiers, MODIFIER_TEMPLATE_TYPE)
	is_template_type => has_flag(modifiers, MODIFIER_TEMPLATE_TYPE)
	is_function_type => has_flag(modifiers, MODIFIER_FUNCTION_TYPE)
	is_array_type => has_flag(modifiers, MODIFIER_ARRAY_TYPE)
	is_number => has_flag(modifiers, MODIFIER_NUMBER)
	is_pack => has_flag(modifiers, MODIFIER_PACK)
	is_unnamed_pack => is_pack and name.index_of(`.`) != -1
	is_template_type_variant => name.index_of(`<`) != -1

	reference_size: large = SYSTEM_BYTES
	allocation_size => get_allocation_size()

	virtual get_allocation_size() {
		if is_pack {
			result = 0

			loop iterator in variables {
				member = iterator.value
				if member.is_static or member.is_constant continue

				result += member.type.allocation_size
			}

			return result
		}

		return reference_size
	}

	# Summary: Returns how many bytes this type contains
	content_size() {
		if is_array_type return get_allocation_size()

		bytes = 0

		loop variable in variables {
			if variable.value.is_static or variable.value.is_constant continue

			if variable.value.is_inlined {
				bytes += variable.value.type.content_size
			}
			else {
				bytes += variable.value.type.allocation_size
			}
		}

		loop supertype in supertypes { bytes += supertype.content_size }

		return bytes
	}

	init(identity: String) {
		Context.init(identity, TYPE_CONTEXT)

		this.virtuals = Map<String, FunctionList>()
		this.overrides = Map<String, FunctionList>()
	}

	init(context: Context, name: String, modifiers: normal, position: Position) {
		Context.init(context, TYPE_CONTEXT)

		this.name = name
		this.identifier = name
		this.modifiers = modifiers
		this.position = position
		this.virtuals = Map<String, FunctionList>()
		this.overrides = Map<String, FunctionList>()

		add_constructor(Constructor.empty(this, position, position))
		add_destructor(Destructor.empty(this, position, position))

		context.declare(this)
	}

	init(name: String, modifiers: normal) {
		Context.init(name, TYPE_CONTEXT)
		this.name = name
		this.identifier = name
		this.modifiers = modifiers
		this.virtuals = Map<String, FunctionList>()
		this.overrides = Map<String, FunctionList>()
	}

	init(name: String, modifiers: normal, profile: tiny) {
		Context.init(name, TYPE_CONTEXT, profile)
		this.name = name
		this.identifier = name
		this.modifiers = modifiers
		this.virtuals = Map<String, FunctionList>(profile)
		this.overrides = Map<String, FunctionList>(profile)
	}

	add_runtime_configuration() {
		if configuration != none return
		configuration = RuntimeConfiguration(this)
	}

	virtual clone() {
		abort('Type did not support cloning')
		return none as Type
	}

	virtual get_accessor_type() {
		return none as Type
	}

	add_constructor(constructor: Constructor) {
		if constructors.overloads.size <= 0 or not constructors.overloads[].(Constructor).is_default {
			constructors.add(constructor)
			Context.declare(constructor)
			return
		}

		# Remove all default constructors
		functions[Keywords.INIT.identifier].overloads.clear()
		constructors.overloads.clear()
		
		# Declare the specified constructor
		constructors.add(constructor)
		Context.declare(constructor)
	}

	add_destructor(destructor: Destructor) {
		if not is_user_defined or not destructors.overloads[].(Destructor).is_default {
			destructors.add(destructor)
			Context.declare(destructor)
			return
		}

		# Remove all default destructors
		functions[Keywords.DEINIT.identifier].overloads.clear()
		destructors.overloads.clear()
		
		# Declare the specified destructor
		destructors.add(destructor)
		Context.declare(destructor)
	}

	# Summary: Declares a virtual function into the context
	declare(function: VirtualFunction) {
		entry = none as FunctionList

		if virtuals.contains_key(function.name) {
			entry = get_virtual_function(function.name)
			if entry == none abort('Could not retrieve a virtual function list')
		}
		else {
			loop supertype in supertypes {
				if supertype.is_virtual_function_declared(function.name) abort('Virtual function was already declared in supertypes')
			}

			entry = FunctionList()
			virtuals.add(function.name, entry)
		}

		entry.add(function)
	}

	# Summary: Declares the specified virtual function overload
	declare_override(function: Function) {
		entry = none as FunctionList

		if overrides.contains_key(function.name) {
			entry = overrides[function.name]
		}
		else {
			entry = FunctionList()
			overrides.add(function.name, entry)
		}

		entry.add(function)
	}

	# Summary: Returns all supertypes this type inherits
	get_all_supertypes() {
		result = List<Type>(supertypes)
		loop supertype in supertypes { result.add_all(supertype.get_all_supertypes()) }
		return result
	}

	is_supertype_declared(type: Type) {
		if supertypes.contains(type) return true
		loop supertype in supertypes { if supertype.is_supertype_declared(type) return true }
		return false
	}

	is_super_function_declared(name: String) {
		loop supertype in supertypes { if supertype.is_local_function_declared(name) return true }
		return false
	}

	is_super_variable_declared(name: String) {
		loop supertype in supertypes { if supertype.is_local_variable_declared(name) return true }
		return false
	}

	get_super_function(name: String) {
		loop supertype in supertypes { if supertype.is_local_function_declared(name) return supertype.get_function(name) }
		return none as FunctionList
	}

	get_super_variable(name: String) {
		loop supertype in supertypes { if supertype.is_local_variable_declared(name) return supertype.get_variable(name) }
		return none as Variable
	}

	# Summary: Returns whether the type contains a function, which overloads the specified operator
	is_operator_overloaded(operator: Operator) {
		if not Operators.operator_overloads.contains_key(operator) return false
		overload = Operators.operator_overloads[operator]
		return is_local_function_declared(overload) or is_super_function_declared(overload)
	}

	is_type_inherited(type: Type) {
		loop supertype in supertypes {
			if supertype == type or supertype.is_type_inherited(type) return true
		}

		return false
	}

	# Summary: Returns whether the specified virtual function is declared in this type or in any of the supertypes
	is_virtual_function_declared(name: String) {
		if virtuals.contains_key(name) return true
		loop supertype in supertypes { if supertype.is_virtual_function_declared(name) return true }
		return false
	}

	override is_function_declared(name: String) {
		return is_function_declared_default(name) or is_super_function_declared(name)
	}

	override is_local_function_declared(name: String) {
		return functions.contains_key(name) or is_super_function_declared(name)
	}

	override is_variable_declared(name: String) {
		return is_variable_declared_default(name) or is_super_variable_declared(name)
	}

	override is_local_variable_declared(name: String) {
		return variables.contains_key(name) or is_super_variable_declared(name)
	}

	override get_function(name: String) {
		if is_local_function_declared_default(name) or not is_super_function_declared(name) return get_function_default(name)
		return get_super_function(name)
	}

	override get_variable(name: String) {
		if is_local_variable_declared_default(name) or not is_super_variable_declared(name) return get_variable_default(name)
		return get_super_variable(name)
	}

	# Summary: Retrieves the virtual function list which corresponds the specified name
	get_virtual_function(name: String) {
		if virtuals.contains_key(name) return virtuals[name]

		loop supertype in supertypes {
			result = supertype.get_virtual_function(name) as FunctionList
			if result != none return result
		}

		return none as FunctionList
	}

	# Summary: Tries to find virtual function overrides with the specified name
	get_override(name: String) {
		if overrides.contains_key(name) return overrides[name]

		loop supertype in supertypes {
			result = supertype.get_override(name) as FunctionList
			if result != none return result
		}

		return none as FunctionList
	}

	# Summary: Returns all virtual function declarations contained in this type and its supertypes
	get_all_virtual_functions() {
		result = List<VirtualFunction>()
		loop supertype in supertypes { result.add_all(supertype.get_all_virtual_functions()) }

		loop iterator in virtuals {
			loop overload in iterator.value.overloads { result.add(overload) }
		}

		return result
	}

	get_supertype_base_offset(type: Type) {
		position: large = 0
		if type == this return Optional<large>(position)

		loop supertype in supertypes {
			if supertype == type return Optional<large>(position)

			result = supertype.get_supertype_base_offset(type) as Optional<large>
			if result has offset return Optional<large>(position + offset)

			position += supertype.content_size
		}

		return Optional<large>()
	}

	is_inheriting_allowed(inheritant: Type) {
		# Type must not inherit itself
		if inheritant == this return false

		# The inheritant should not have this type as its supertype
		inheritant_supertypes = inheritant.get_all_supertypes()
		if inheritant_supertypes.contains(this) return false

		# Deny the inheritance if supertypes already contain the inheritant or if any supertype would be duplicated
		inheritor_supertypes = get_all_supertypes()
		
		# The inheritor can inherit the same type multiple times
		if inheritor_supertypes.contains(inheritant) return false

		# Look for conflicts between the supertypes of the inheritor and the inheritant
		loop supertype in inheritant_supertypes {
			if inheritor_supertypes.contains(supertype) return false
		}

		return true
	}

	# Summary: Finds the first configuration variable in the hierarchy of this type
	get_configuration_variable() {
		if supertypes.size > 0 {
			supertype = supertypes[]

			loop (supertype.supertypes.size > 0) {
				supertype = supertype.supertypes[]
			}

			if supertype.configuration == none abort('Could not find runtime configuration from an inherited supertype')
			return supertype.configuration.variable
		}

		if configuration == none abort('Could not find runtime configuration')
		return configuration.variable
	}

	get_register_format() {
		if format == FORMAT_DECIMAL return FORMAT_DECIMAL
		if (format & 1) != 0 return SYSTEM_FORMAT
		return SYSTEM_SIGNED
	}

	override on_mangle(mangle: Mangle) {
		mangle.add(this, 0, true)
	}

	virtual match(other: Type) {
		if is_pack {
			# The other type should also be a pack
			if not other.is_pack return false

			# Verify the members are compatible with each other
			expected_member_types = List<Type>()
			actual_member_types = List<Type>()

			loop iterator in variables {
				expected_member_types.add(iterator.value.type)
			}
			loop iterator in other.variables {
				actual_member_types.add(iterator.value.type)
			}

			return common.compatible(expected_member_types, actual_member_types)
		}

		return this.name == other.name and this.identity == other.identity
	}

	override dispose() {
		Context.default_dispose()
		template_arguments.clear()
		initialization.clear()
		supertypes.clear()
		virtuals.clear()
		overrides.clear()
	}

	override string() {
		# Handle unnamed packs separately
		if is_unnamed_pack {
			# Pattern: { $member-1: $type-1, $member-2: $type-2, ... }
			member_sections = List<String>(variables.size, false)

			loop iterator in variables {
				member = iterator.value
				member_section = member.name + ': '

				# Add the type of the member
				if member.type != none { member_section = member_section + member.type.string() }
				else { member_section = member_section + '?' }
			}

			return "{ " + String.join(", ", member_sections) + ' }'
		}

		names = List<String>()

		loop iterator in get_parent_types() {
			names.add(iterator.name)
		}

		names.add(name)

		return String.join(`.`, names)
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
	is_aligned: bool = false
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
	is_generated => position === none

	is_unresolved => type == none or type.is_unresolved
	is_resolved => type != none and type.is_resolved

	init(parent: Context, type: Type, category: normal, name: String, modifiers: normal) {
		this.name = name
		this.type = type
		this.category = category
		this.modifiers = modifiers
		this.parent = parent
	}

	# Summary: Returns the mangled static name for this variable
	get_static_name() {
		# Request the fullname in order to generate the mangled name object
		parent.get_fullname()

		mangle: Mangle = parent.mangle.clone()
		name: String = this.name.to_lower()

		mangle.add(Mangle.STATIC_VARIABLE_COMMAND)
		mangle.add(to_string(name.length))
		mangle.add(name)
		mangle.add(type)
		mangle.add(Mangle.END_COMMAND)

		return mangle.value
	}

	# Summary: Returns whether this variable is edited inside the specified node
	is_edited_inside(node: Node) {
		loop write in writes {
			# If one of the parent nodes of the current write is the specified node, then this variable is edited inside the specified node
			loop (iterator = write.parent, iterator != none, iterator = iterator.parent) {
				if iterator == node return true
			}
		}

		return false
	}

	# Summary: Returns the alignment compared to the specified parent type
	get_alignment(parent: Type) {
		if this.parent == parent {
			alignment: large = 0
			loop supertype in parent.supertypes { alignment += supertype.content_size }
			alignment += this.alignment
			return alignment
		}

		position: large = 0

		loop supertype in parent.supertypes {
			alignment: large = get_alignment(supertype)
			if alignment >= 0 return position + alignment

			position += supertype.content_size
		}

		return -1
	}

	# Summary: Returns whether this variable is inlined
	is_inlined() {
		if has_flag(modifiers, MODIFIER_OUTLINE) or type == none return false
		if has_flag(modifiers, MODIFIER_INLINE) return true

		# Inlining types should always be inlined
		return type.is_inlining
	}

	string() {
		start: String = String.empty
		if parent != none and parent.is_type { start = parent.string() + '.' }

		end: String = name + ': '
		if type == none or type.is_unresolved { end = end + '?' }
		else { end = end + type.string() }

		return start + end
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

			if not pass return overload
		}

		overloads.add(function)
		return none as Function
	}

	# Summary: Returns the number of casts needed to call the specified function candidate with the specified parameter types
	get_cast_count(candidate: Function, parameter_types: List<Type>) {
		casts = 0

		loop (i = 0, i < parameter_types.size, i++) {
			if candidate.parameters[i].type == none or candidate.parameters[i].type.match(parameter_types[i]) continue
			casts++
		}

		return casts
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

		if candidates.size == 0 return none as Function
		if candidates.size == 1 return candidates[]

		minimum_candidate =  candidates[]
		minimum_casts = get_cast_count(minimum_candidate, parameter_types)

		loop (i = 1, i < candidates.size, i++) {
			candidate = candidates[i]
			casts = get_cast_count(candidate, parameter_types)

			if casts >= minimum_casts continue

			minimum_candidate = candidate
			minimum_casts = casts
		}

		return minimum_candidate
	}

	get_overload(parameter_types: List<Type>) {
		return get_overload(parameter_types, List<Type>())
	}

	get_implementation(parameter_types: List<Type>, template_arguments: List<Type>) {
		overload = get_overload(parameter_types, template_arguments)
		if overload == none return none as FunctionImplementation
		if template_arguments.size > 0 return overload.(TemplateFunction).get(parameter_types, template_arguments)
		return overload.get(parameter_types)
	}

	get_implementation(parameter_types: List<Type>) {
		return get_implementation(parameter_types, List<Type>(0, false))
	}

	get_implementation(parameter: Type) {
		parameter_types = List<Type>()
		parameter_types.add(parameter)
		return get_implementation(parameter_types, List<Type>(0, false))
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
		if type == none return name
		return name + ': ' + type.string()
	}

	string() {
		if type == none return name + ': any'
		return name + ': ' + type.string()
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
	return_type: Type

	implementations: List<FunctionImplementation> = List<FunctionImplementation>()

	is_constructor => has_flag(type, CONSTRUCTOR_CONTEXT_MODIFIER)
	is_destructor => has_flag(type, DESTRUCTOR_CONTEXT_MODIFIER)
	is_public => has_flag(modifiers, MODIFIER_PUBLIC)
	is_protected => has_flag(modifiers, MODIFIER_PROTECTED)
	is_private => has_flag(modifiers, MODIFIER_PRIVATE)
	is_static => has_flag(modifiers, MODIFIER_STATIC)
	is_imported => has_flag(modifiers, MODIFIER_IMPORTED)
	is_exported => has_flag(modifiers, MODIFIER_EXPORTED)
	is_outlined => has_flag(modifiers, MODIFIER_OUTLINE)
	is_template_function => has_flag(modifiers, MODIFIER_TEMPLATE_FUNCTION)
	is_template_function_variant => name.index_of(`<`) != -1

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
		implementation.return_type = return_type # Force the return type, if user added it

		implementations.add(implementation)

		implementation.implement(blueprint)
	}

	# Summary: Implements the function with the specified parameter type
	implement(type: Type) {
		parameter_types = List<Type>()
		parameter_types.add(type)
		return implement(parameter_types)
	}

	# Summary: Implements the function with the specified parameter types
	implement_default(parameter_types: List<Type>) {
		implementation_parameters = List<Parameter>(types.size, false)

		# Pack parameters with names and types
		loop (i = 0, i < parameters.size, i++) {
			parameter = parameters[i]
			implementation_parameters.add(Parameter(parameter.name, parameter.position, parameter_types[i]))
		}

		# Create a function implementation
		implementation = FunctionImplementation(this, none as Type, parent)
		implementation.set_parameters(implementation_parameters)
		implementation.return_type = return_type # Force the return type, if user added it

		# Add the created implementation to the list
		implementations.add(implementation)

		implementation.implement(clone(blueprint))

		return implementation
	}

	# Summary: Implements the function with the specified parameter types
	virtual implement(parameter_types: List<Type>) {
		return implement_default(parameter_types)
	}

	# Summary: Returns whether the specified parameter types can be used to implement this function
	passes(types: List<Type>) {
		if types.size != parameters.size return false

		loop (i = 0, i < parameters.size, i++) {
			expected = parameters[i].type
			if expected == none continue

			actual = types[i]
			if expected.match(actual) continue

			if not expected.is_primitive or not actual.is_primitive {
				if not expected.is_type_inherited(actual) and not actual.is_type_inherited(expected) return false
			} 
			else resolver.get_shared_type(expected, actual) == none return false
		}

		return true
	}

	# Summary: Returns whether the specified parameter types can be used to implement this function
	passes(types: List<Type>, template_arguments: List<Type>) {
		if template_arguments.size > 0 return is_template_function and this.(TemplateFunction).passes(types, template_arguments)
		return not is_template_function and passes(types)
	}

	# Summary: Tries to find function implementation with the specified parameter type
	get(type: Type) {
		parameter_types = List<Type>()
		parameter_types.add(type)
		return get(parameter_types)
	}

	# Summary: Tries to find function implementation with the specified parameter types
	get(parameter_types: List<Type>) {
		if parameter_types.size != parameters.size return none as FunctionImplementation

		# Implementation should not be made if any of the parameters has a fixed type but it is unresolved
		loop parameter_type in parameter_types {
			if parameter_type == none or parameter_type.is_unresolved return none as FunctionImplementation
		}

		implementation_types = List<Type>(parameter_types.size, true)

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

				if not a.match(b) {
					matches = false
					stop
				}
			}

			if matches return implementation
		}

		# Imported functions should have exactly one implementation
		# This also prevents additional implementations when the parameters of an imported function are unresolved
		if is_imported and implementations.size > 0 return none as FunctionImplementation

		return implement(implementation_types)
	}

	override on_mangle(mangle: Mangle) {
		if language == LANGUAGE_OTHER {
			mangle.value = name
			return
		}

		if language == LANGUAGE_CPP { mangle.value = String(Mangle.CPP_LANGUAGE_TAG) }

		if is_member {
			mangle.add(Mangle.START_LOCATION_COMMAND)
			mangle.add_path(get_parent_types())
		}

		mangle.add(to_string(name.length) + name)

		if is_member { mangle.add(Mangle.END_COMMAND) }
	}

	override dispose() {
		Context.default_dispose()
		parameters.clear()
		blueprint.clear()
		implementations.clear()
	}
}

TemplateTypeVariant {
	type: Type
	arguments: List<Type>

	init(type: Type, arguments: List<Type>) {
		this.type = type
		this.arguments = arguments
	}
}

Type TemplateType {
	template_parameters: List<String>

	inherited: List<Token> = List<Token>()
	blueprint: List<Token>

	variants: Map<String, TemplateTypeVariant> = Map<String, TemplateTypeVariant>()

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

	insert_arguments(tokens: List<Token>, arguments: List<Type>) {
		loop (i = 0, i < tokens.size, i++) {
			token = tokens[i]

			if token.type == TOKEN_TYPE_IDENTIFIER {
				j = template_parameters.index_of(token.(IdentifierToken).value)
				if j == -1 continue

				position = token.position

				tokens.remove_at(i)
				tokens.insert_all(i, common.get_tokens(arguments[j], position))
			}
			else token.type == TOKEN_TYPE_FUNCTION {
				insert_arguments(token.(FunctionToken).parameters.tokens, arguments)
			}
			else token.type == TOKEN_TYPE_PARENTHESIS {
				insert_arguments(token.(ParenthesisToken).tokens, arguments)
			}
		}
	}

	# Summary: Returns an identifier, which are used to identify template type variants
	get_variant_identifier(arguments: List<Type>) {
		names = List<String>(arguments.size, false)
		loop argument in arguments { names.add(argument.string()) }
		return String.join(", ", names)
	}

	try_get_variant(arguments: List<Type>) {
		variant_identifier = get_variant_identifier(arguments)
		if variants.contains_key(variant_identifier) return variants[variant_identifier].type
		return none as Type
	}

	create_variant(arguments: List<Type>) {
		identifier: String = get_variant_identifier(arguments)
		
		# Copy the blueprint and insert the specified arguments to their places
		tokens = clone(inherited)

		blueprint: List<Token> = clone(this.blueprint)
		blueprint[].(IdentifierToken).value = name + `<` + identifier + `>`

		tokens.add_all(blueprint)

		# Now, insert the specified arguments to their places
		insert_arguments(tokens, arguments)

		# Parse the new variant
		result = parser.parse(parent, tokens, 0, parser.MAX_PRIORITY).first
		if result == none or result.instance != NODE_TYPE_DEFINITION abort('Invalid template type blueprint')

		# Register the new variant
		variant = result.(TypeDefinitionNode).type
		variant.identifier = name
		variant.modifiers = modifiers & (!MODIFIER_IMPORTED) # Remove the imported modifier, because new variants are not imported
		variant.template_arguments = arguments

		variants.add(identifier, TemplateTypeVariant(variant, arguments))

		# Parse the body of the new variant
		result.(TypeDefinitionNode).parse()

		# Finally, add the inherited supertypes to the new variant
		variant.supertypes.add_all(supertypes)

		return variant
	}

	# Summary: Returns a variant with the specified template arguments, creating it if necessary
	get_variant(arguments: List<Type>) {
		if arguments.size < template_parameters.size return none as Type
		variant = try_get_variant(arguments)
		if variant != none return variant
		return create_variant(arguments) 
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

	# Summary: Creates the parameters of this function in a way that they do not have types
	initialize() {
		result = header.get_parameters(Context(String.empty, FUNCTION_CONTEXT))

		if result has parameters {
			parameters.add_all(parameters)
			return true
		}

		return false
	}

	try_get_variant(template_arguments: List<Type>) {
		names = List<String>()
		loop template_argument in template_arguments { names.add(template_argument.string()) }
		variant_identifier = String.join(", ", names)

		if variants.contains_key(variant_identifier) return variants[variant_identifier]
		return none as FunctionImplementation
	}

	insert_arguments(tokens: List<Token>, arguments: List<Type>) {
		loop (i = 0, i < tokens.size, i++) {
			token = tokens[i]

			if token.type == TOKEN_TYPE_IDENTIFIER {
				j = template_parameters.index_of(token.(IdentifierToken).value)
				if j == -1 continue

				position = token.position

				tokens.remove_at(i)
				tokens.insert_all(i, common.get_tokens(arguments[j], position))
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
		variant_identifier = String.join(", ", names)

		# Copy the blueprint and insert the specified arguments to their places
		blueprint: List<Token> = clone(this.blueprint)
		blueprint[].(FunctionToken).identifier.value = name + `<` + variant_identifier + `>`

		insert_arguments(blueprint, template_arguments)

		# Parse the new variant
		result = parser.parse(parent, blueprint, 0, parser.MAX_PRIORITY).first
		if result == none or result.instance != NODE_FUNCTION_DEFINITION abort('Invalid template function blueprint')

		# Register the new variant
		variant = result.(FunctionDefinitionNode).function
		variant.modifiers = modifiers & (!MODIFIER_IMPORTED) # Remove the imported modifier, because new variants are not imported

		variants.add(variant_identifier, variant)
		return variant
	}

	passes(types: List<Type>) {
		return abort('Tried to execute pass function without template parameters') as bool
	}

	passes(actual_types: List<Type>, template_arguments: List<Type>) {
		if template_arguments.size != template_parameters.size return false

		# None of the types can be unresolved
		loop type in actual_types { if type.is_unresolved return false }
		loop type in template_arguments { if type.is_unresolved return false }

		# Clone the header, insert the template arguments and determine the expected parameters
		header: FunctionToken = this.header.clone() as FunctionToken
		insert_arguments(header.parameters.tokens, template_arguments)

		if header.get_parameters(Context(this, FUNCTION_CONTEXT)) has not expected_parameters return false
		if expected_parameters.size != actual_types.size return false

		loop (i = 0, i < actual_types.size, i++) {
			expected = expected_parameters[i].type
			if expected == none continue

			actual = actual_types[i]
			if expected.match(actual) continue

			# If both types are not primitives, either a upcast or downcast must be possible
			if not expected.is_primitive and not actual.is_primitive {
				if not expected.is_type_inherited(actual) and not actual.is_type_inherited(expected) return false
			}
			else resolver.get_shared_type(expected, actual) == none {
				return false
			}
		}

		return true
	}

	get(parameter_types: List<Type>) {
		return abort('Tried to get overload of template function without template arguments') as FunctionImplementation
	}

	get(parameter_types: List<Type>, template_arguments: List<Type>) {
		if template_arguments.size != template_parameters.size abort('Missing template arguments')

		variant = try_get_variant(template_arguments)

		if variant == none {
			variant = create_variant(template_arguments)
			if variant == none return none as FunctionImplementation
		}

		implementation = variant.get(parameter_types)
		implementation.identifier = name
		implementation.metadata.modifiers = modifiers
		implementation.template_arguments = template_arguments
		return implementation
	}
}

Function Lambda {
	init(context: Context, modifiers: large, name: String, blueprint: List<Token>, start: Position, end: Position) {
		Function.init(context, modifiers, name, blueprint, start, end)
		this.type = this.type | LAMBDA_CONTEXT_MODIFIER

		# Lambdas usually capture variables from the parent context
		connect(context)

		# Add import modifier if this lambda is inside an imported function
		implementation = context.find_implementation_parent()
		if implementation.metadata.is_imported { modifiers |= MODIFIER_IMPORTED }
	}

	# Summary: Implements the lambda using the specified parameter types
	override implement(types: List<Type>) {
		if implementations.size > 0 abort('Tried to implement a lambda twice')

		# Pack parameters with names and types
		parameters: List<Parameter> = List<Parameter>(this.parameters.size, false)

		loop (i = 0, i < types.size, i++) {
			parameter = this.parameters[i]
			parameters.add(Parameter(parameter.name, parameter.position, types[i]))
		}

		# Create a function implementation
		implementation = LambdaImplementation(this, none as Type, parent)
		implementation.set_parameters(parameters)
		implementation.return_type = return_type # Force the return type, if user added it
		implementation.is_imported = is_imported

		# Add the created implementation to the implementations list
		implementations.add(implementation)

		implementation.implement(blueprint)
		return implementation
	}
}

Context FunctionImplementation {
	metadata: Function
	node: Node
	usages: List<FunctionNode> = List<FunctionNode>()
	
	self: Variable
	template_arguments: List<Type>
	return_type: Type

	size_of_locals: large = 0
	size_of_local_memory: large = 0

	virtual_function: VirtualFunction = none
	is_imported: bool = false

	is_constructor => metadata.is_constructor
	is_destructor => metadata.is_destructor
	is_static => metadata.is_static
	is_empty => (node == none or node.first == none) and not metadata.is_imported

	parameters() {
		result = List<Variable>()

		loop iterator in variables {
			variable = iterator.value
			if not variable.is_parameter or variable.is_self_pointer or variable.is_hidden continue
			result.add(variable)
		}

		return result
	}

	parameter_types() {
		result = List<Type>()
		loop iterator in parameters() { result.add(iterator.type) }
		return result
	}

	init(metadata: Function, return_type: Type, parent: Context) {
		Context.init(parent, IMPLEMENTATION_CONTEXT)

		this.metadata = metadata
		this.return_type = return_type
		this.template_arguments = List<Type>(0, false)

		this.name = metadata.name
		this.identifier = name
		
		connect(parent)
	}

	override get_self_pointer() {
		return self
	}

	# Summary: Sets the function parameters
	set_parameters(parameters: List<Parameter>) {
		loop parameter in parameters {
			variable = Variable(this, parameter.type, VARIABLE_CATEGORY_PARAMETER, parameter.name, MODIFIER_DEFAULT)
			variable.position = parameter.position

			if variables.contains_key(variable.name) return Status('Parameter with the same name already exists')

			variables.add(variable.name, variable)
		}

		return Status()
	}

	# Summary: Implements the function using the given blueprint
	virtual implement(blueprint: List<Token>) {
		if metadata.is_member and not metadata.is_static {
			self = Variable(this, metadata.find_type_parent(), VARIABLE_CATEGORY_PARAMETER, String(SELF_POINTER_IDENTIFIER), MODIFIER_DEFAULT)
			self.is_self_pointer = true
			self.position = metadata.start
			declare(self)
		}

		node = ScopeNode(this, metadata.start, metadata.end, false)
		parser.parse(node, this, blueprint, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
	}

	override on_mangle(mangle: Mangle) {
		if metadata.language == LANGUAGE_OTHER {
			mangle.value = name
			return
		}

		if metadata.language == LANGUAGE_CPP { mangle.value = String(Mangle.CPP_LANGUAGE_TAG) }

		if is_member {
			mangle.add(Mangle.START_LOCATION_COMMAND)
			mangle.add_path(get_parent_types())
		}

		mangle.add(to_string(identifier.length) + identifier)

		if template_arguments.size > 0 {
			mangle.add(Mangle.START_TEMPLATE_ARGUMENTS_COMMAND)
			mangle.add(template_arguments)
			mangle.add(Mangle.END_COMMAND)
		}

		if is_member { mangle.add(Mangle.END_COMMAND) }

		# Add the parameters
		loop parameter in parameters { mangle.add(parameter.type) }

		# If there are no parameters, it must be notified
		if parameters.size == 0 { mangle.add(Mangle.NO_PARAMETERS_COMMAND) }

		if metadata.language == LANGUAGE_VIVID and not primitives.is_primitive(return_type, primitives.UNIT) {
			mangle.add(Mangle.PARAMETERS_END)
			mangle.add(Mangle.START_RETURN_TYPE_COMMAND)
			mangle.add(return_type)
		}
	}

	virtual get_header() {
		start: String = String.empty
		if parent != none and parent.is_type { start = parent.string() + `.` }

		middle: String = metadata.name + `(` + String.join(", ", parameters().map<String>((i: Variable) -> i.string())) + '): '

		result = start + middle

		if return_type == none {
			result = result + `?`
		}
		else {
			result = result + return_type.string()
		}

		return result
	}

	delete_node_tree(tree: Node) {
		if tree === none return

		loop (iterator = tree.last, iterator != none, iterator = iterator.previous) {
			delete_node_tree(iterator)
		}

		deallocate(tree as link)
	}

	override dispose() {
		Context.default_dispose()
		usages.clear()
		template_arguments.clear()
		delete_node_tree(node)
	}

	override string() {
		return get_header()
	}
}

Variable CapturedVariable {
	captured: Variable

	init(context: Context, captured: Variable) {
		Variable.init(context, captured.type, captured.category, captured.name, captured.modifiers)
		context.declare(this)
		this.captured = captured
	}
}

FunctionImplementation LambdaImplementation {
	captures: List<CapturedVariable> = List<CapturedVariable>()
	function: Variable
	internal_type: Type

	init(metadata: Lambda, return_type: Type, context: Context) {
		FunctionImplementation.init(metadata, return_type, context)
		this.type = this.type | LAMBDA_CONTEXT_MODIFIER
	}

	seal() {
		# 1. If the type is not created, it means that this lambda is not used, therefore this lambda can be skipped
		# 2. If the function is already created, this lambda is sealed
		if internal_type == none or function != none return

		self = Variable(this, internal_type, VARIABLE_CATEGORY_PARAMETER, String(LAMBDA_SELF_POINTER_IDENTIFIER), MODIFIER_DEFAULT)
		self.is_self_pointer = true

		# Declare the function pointer as the first member
		function = internal_type.declare_hidden(Link(), VARIABLE_CATEGORY_MEMBER)

		# Change all captured variables into member variables so that they are retrieved using the self pointer of this lambda
		loop capture in captures { capture.category = VARIABLE_CATEGORY_MEMBER }

		# Remove all captured variables from the current context since they must be moved into the internal type of the lambda
		loop capture in captures { variables.remove(capture.name) }

		# Move all the captured variables into the internal type of the lambda
		loop capture in captures { internal_type.(Context).declare(capture) }

		# Add the self pointer to all of the usages of the captured variables
		usages: List<Node> = node.find_all(i -> i.instance == NODE_VARIABLE and captures.contains(i.(VariableNode).variable))

		loop usage in usages { usage.replace(LinkNode(VariableNode(self), usage.clone())) }

		# Align the member variables
		common.align_members(internal_type)
	}

	override is_variable_declared(name: String) {
		return is_local_variable_declared(name) or get_variable(name) != none
	}

	override get_variable(name: String) {
		if is_local_variable_declared(name) return get_variable_default(name)

		# If the variable is declared outside of this implementation, it may need to be captured
		variable = get_variable_default(name)

		if variable == none return none as Variable

		# The variable can be captured only if it is a local variable or a parameter and it is resolved
		if variable.is_predictable and variable.is_resolved and not variable.is_constant {
			captured = CapturedVariable(this, variable)
			captures.add(captured)
			return captured
		}

		if variable.is_member or variable.is_constant return variable
		return none as Variable
	}

	# Summary: Implements the function using the given blueprint
	override implement(blueprint: List<Token>) {
		root = parent
		loop (root.parent != none) { root = root.parent }

		internal_type = Type(root, identity.replace(`.`, `_`), MODIFIER_DEFAULT, metadata.start)
		internal_type.add_runtime_configuration()

		# Add the default constructor and destructor
		internal_type.add_constructor(Constructor.empty(internal_type, metadata.start, metadata.end))
		internal_type.add_destructor(Destructor.empty(internal_type, metadata.start, metadata.end))

		node = ScopeNode(this, metadata.start, metadata.end, false)
		parser.parse(node, this, blueprint, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
	}

	override get_self_pointer() {
		if self != none return self
		return get_variable(String(SELF_POINTER_IDENTIFIER))
	}

	override on_mangle(mangle: Mangle) {
		function_parent = parent.find_implementation_parent()
		function_parent.on_mangle(mangle)

		mangle.add(`_`)
		mangle.add(name)
		mangle.add(`_`)

		# Add the parameters
		loop parameter in parameters { mangle.add(parameter.type) }

		# Add the return type, if it is not unit
		if primitives.is_primitive(return_type, primitives.UNIT) return

		mangle.add(Mangle.PARAMETERS_END)
		mangle.add(Mangle.START_RETURN_TYPE_COMMAND)
		mangle.add(return_type)
	}

	override get_header() {
		parent_implementation = parent.find_implementation_parent()
		return parent_implementation.string() + ' Lambda #' + name
	}
}

Label {
	name: String

	init(name: String) {
		this.name = name
	}

	equals(other: Label) {
		return name == other.name
	}

	hash() {
		return name.hash()
	}

	string() {
		return name
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

			replacement = resolver.resolve(context, argument)
			if replacement == none continue

			arguments[i] = replacement
		}
	}
}

Type UnresolvedType {
	components: List<UnresolvedTypeComponent>
	size: ParenthesisToken
	pointers: large = 0

	init(identifier: String) {
		Type.init(String.empty, MODIFIER_DEFAULT)
		this.components = [ UnresolvedTypeComponent(identifier) ]
		this.is_resolved = false
	}

	init(components: List<UnresolvedTypeComponent>) {
		Type.init(String.empty, MODIFIER_DEFAULT)
		this.components = components
		this.is_resolved = false
	}

	virtual resolve(context: Context) {
		environment = context

		loop component in components {
			component.resolve(environment)

			local = component != components[]
			if not context.is_type_declared(component.identifier, local) return none as TypeNode

			component_type = context.get_type(component.identifier)

			if component.arguments.size == 0 {
				context = component_type
				continue
			}

			# Require all of the arguments to be resolved
			loop arguments in component.arguments {
				if arguments.is_unresolved return none as TypeNode
			}

			# Since the component has template arguments, the type must be a template type
			if component_type.is_generic_type return none as TypeNode

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

		result = context as Type

		# Array types:
		if size != none {
			return TypeNode(ArrayType(environment, result, size, position))
		}

		# Wrap the result type around pointers
		loop (i = 0, i < pointers, i++) {
			pointer = Link(result)
			result = pointer
		}

		return TypeNode(result)
	}

	override match(other: Type) {
		return false
	}

	resolve_or_none(context: Context) {
		result = resolve(context)
		if result === none return none as Type
		return result.try_get_type()
	}

	resolve_or_this(context: Context) {
		node = resolve(context)
		if node === none return this

		result = node.try_get_type()
		if result === none return this

		return result
	}
}

UnresolvedType FunctionType {
	self: Type
	parameters: List<Type>
	return_type: Type

	init(parameters: List<Type>, return_type: Type, position: Position) {
		UnresolvedType.init(String.empty)
		this.self = none as Type
		this.modifiers = MODIFIER_FUNCTION_TYPE
		this.parameters = parameters
		this.return_type = return_type
		this.position = position
		update_state()
	}

	init(self: Type, parameters: List<Type>, return_type: Type, position: Position) {
		UnresolvedType.init(String.empty)
		this.self = self
		this.modifiers = MODIFIER_FUNCTION_TYPE
		this.parameters = parameters
		this.return_type = return_type
		this.position = position
		update_state()
	}

	update_state() {
		loop parameter in parameters {
			if parameter == none or parameter.is_unresolved return
		}

		is_resolved = true
	}

	override resolve(context: Context) {
		resolved = List<Type>(parameters.size, false)

		loop parameter in parameters {
			if parameter == none or parameter.is_resolved {
				resolved.add(none as Type)
				continue
			}

			resolved.add(resolver.resolve(context, parameter))
		}

		loop (i = 0, i < resolved.size, i++) {
			iterator = resolved[i]
			if iterator == none continue
			parameters[i] = iterator
		}

		update_state()
		return none as Node
	}

	override get_accessor_type() {
		return Link.get_variant(primitives.create_number(primitives.U64, FORMAT_UINT64))
	}

	override match(other: Type) {
		if not other.is_function_type return false
		if parameters.size != other.(FunctionType).parameters.size return false
		if not common.compatible(parameters, other.(FunctionType).parameters) return false
		return common.compatible(return_type, other.(FunctionType).return_type)
	}

	override string() {
		names = List<String>(parameters.size, false)

		loop parameter in parameters {
			if parameter == none {
				names.add("?")
				continue
			}

			names.add(parameter.string())
		}

		return_type_name = none as String

		if return_type != none { return_type_name = return_type.string() }
		else { return_type_name = "?" }

		return "(" + String.join(", ", names) + ') -> ' + return_type_name
	}
}

Function VirtualFunction {
	init(type: Type, name: String, return_type: Type, start: Position, end: Position) {
		Function.init(type, MODIFIER_DEFAULT, name, List<Token>(), start, end)
		this.return_type = return_type
	}
}

Number ArrayType {
	element: Type
	usage_type: Type
	tokens: List<Token>
	expression: Node
	size => expression.(NumberNode).value

	init(context: Context, element: Type, count: ParenthesisToken, position: Position) {
		Number.init(SYSTEM_FORMAT, 64, element.string() + '[]')
		this.modifiers = MODIFIER_DEFAULT | MODIFIER_PRIMITIVE | MODIFIER_INLINE | MODIFIER_ARRAY_TYPE
		this.element = element
		this.usage_type = Link(element)
		this.tokens = count.tokens
		this.position = position
		this.template_arguments = [ element ]

		try_parse(context)

		is_resolved = expression != none and expression.instance == NODE_NUMBER
	}

	override get_allocation_size() {
		if is_unresolved abort('Array size was not resolved')

		count: large = expression.(NumberNode).value
		return element.allocation_size * count
	}

	# Summary: Try to parse the expression using the internal tokens
	try_parse(context: Context) {
		expression = parser.parse(context, tokens, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
	}
	
	override get_accessor_type() {
		return element
	}

	resolve(context: Context) {
		# Ensure the expression is created
		if expression == none {
			try_parse(context)
			if expression == none return
		}

		if expression.first == none return

		# Insert values of constants manually
		analysis.apply_constants_into(expression)

		# Try to convert the expression into a constant number
		if expression.first.instance !== NODE_NUMBER {
			evaluated = expression_optimizer.get_simplified_value(expression.first)
			if evaluated.instance !== NODE_NUMBER or evaluated.(NumberNode).format === FORMAT_DECIMAL return

			expression.first.replace(evaluated)
		}

		expression = NumberNode(SYSTEM_FORMAT, expression.first.(NumberNode).value, position)
		is_resolved = true
	}

	get_status() {
		if is_resolved return none as Status
		return Status(start, 'Can not convert the size of the array to a constant number')
	}

	override string() {
		size: String = none as String

		if expression == none or expression.instance != NODE_NUMBER {
			size = "?"
		}
		else {
			size = to_string(this.size)
		}

		return element.string() + `[` + size + `]`
	}
}