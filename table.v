TABLE_ITEM_STRING = 0
TABLE_ITEM_INTEGER = 1
TABLE_ITEM_LABEL = 2
TABLE_ITEM_TABLE_REFERENCE = 3
TABLE_ITEM_LABEL_OFFSET = 4
TABLE_ITEM_TABLE_LABEL = 5

TableItem {
	type: large

	init(type: large) {
		this.type = type
	}
}

TableItem StringTableItem {
	value: String

	init(value: String) {
		TableItem.init(TABLE_ITEM_STRING)
		this.value = value
	}
}

TableItem IntegerTableItem {
	value: large
	size: large

	init(value: large, size: large) {
		TableItem.init(TABLE_ITEM_INTEGER)
		this.value = value
		this.size = size
	}
}

TableItem LabelTableItem {
	value: Label

	init(value: Label) {
		TableItem.init(TABLE_ITEM_LABEL)
		this.value = value
	}
}

TableItem TableReferenceTableItem {
	value: Table

	init(value: Table) {
		TableItem.init(TABLE_ITEM_TABLE_REFERENCE)
		this.value = value
	}
}

LabelOffset {
	from: Label
	to: Label

	init(from: Label, to: Label) {
		this.from = from
		this.to = to
	}
}

TableItem LabelOffsetTableItem {
	value: LabelOffset

	init(value: LabelOffset) {
		TableItem.init(TABLE_ITEM_LABEL_OFFSET)
		this.value = value
	}
}

TableLabel {
	name: String
	size: large
	is_section_relative: bool = false
	declare: bool

	init(name: String, size: large, declare: bool) {
		this.name = name
		this.size = size
		this.declare = declare
	}

	init(name: String, declare: bool) {
		this.name = name
		this.size = SYSTEM_BYTES
		this.declare = declare
	}
}

TableItem TableLabelTableItem {
	value: TableLabel

	init(value: TableLabel) {
		TableItem.init(TABLE_ITEM_TABLE_LABEL)
		this.value = value
	}
}

Table {
	name: String
	label: Label
	is_built: bool = false
	is_section: bool = false
	items: List<TableItem> = List<TableItem>()
	subtables: large = 0

	init(name: String) {
		this.name = name
		this.label = Label(name)
	}

	add(item: TableItem, inlined: bool) {
		if inlined {
			items.add(item)
			return
		}

		subtable = Table(name + `_` + to_string(subtables++))
		subtable.add(item)

		items.add(TableReferenceTableItem(subtable))
	}

	add(item: TableItem) {
		add(item, true)
	}

	add(value: String) { add(StringTableItem(value)) }
	add(value: large) { add(IntegerTableItem(value, sizeof(large))) }
	add(value: normal) { add(IntegerTableItem(value, sizeof(normal))) }
	add(value: small) { add(IntegerTableItem(value, sizeof(small))) }
	add(value: tiny) { add(IntegerTableItem(value, sizeof(tiny))) }
	add(value: Table) { add(TableReferenceTableItem(value)) }
	add(value: Label) { add(LabelTableItem(value)) }
	add(value: LabelOffset) { add(LabelOffsetTableItem(value)) }
	add(value: TableLabel) { add(TableLabelTableItem(value)) }
}