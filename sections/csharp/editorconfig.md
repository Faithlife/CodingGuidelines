# .editorconfig for C#

The standard settings for `charset`, `end_of_line`, `insert_final_newline`, and `trim_trailing_whitespace` should be inherited from [the `[*]` section](../editorconfig.md).

```
[*.cs]
indent_size = 4
indent_style = tab
```

We have always used tabs of width 4 for C#.

## Language Conventions

The properties listed below are in the same order as in the [documentation](https://docs.microsoft.com/en-us/visualstudio/ide/editorconfig-language-conventions).

```
dotnet_style_qualification_for_field = false : warning
dotnet_style_qualification_for_property = false : warning
dotnet_style_qualification_for_method = false : warning
dotnet_style_qualification_for_event = false : warning
```

Never use `this.` qualifier.

```
dotnet_style_predefined_type_for_locals_parameters_members = true : warning
dotnet_style_predefined_type_for_member_access = true : warning
```

Always use language keywords (e.g. `int`) instead of framework type names (e.g. `Int32`).

```
dotnet_style_require_accessibility_modifiers = for_non_interface_members : warning
csharp_preferred_modifier_order = public, private, protected, internal, new, abstract, virtual, sealed, override, static, readonly, extern, unsafe, volatile, async : warning
dotnet_style_readonly_field = true : suggestion
```

Always use modifiers, in the preferred order, and use `readonly` when possible.

```
dotnet_style_parentheses_in_arithmetic_binary_operators = never_if_unnecessary : none
dotnet_style_parentheses_in_relational_binary_operators = never_if_unnecessary : none
dotnet_style_parentheses_in_other_binary_operators = never_if_unnecessary : none
dotnet_style_parentheses_in_other_operators = never_if_unnecessary : none
```

Allow the developer to decide when parentheses around operators improve clarity.

```
dotnet_style_object_initializer = true : suggestion
dotnet_style_collection_initializer = true : suggestion
dotnet_style_explicit_tuple_names = true : warning
dotnet_style_prefer_inferred_tuple_names = true : suggestion
dotnet_style_prefer_inferred_anonymous_type_member_names = true : suggestion
dotnet_style_prefer_auto_properties = true : suggestion
dotnet_style_prefer_is_null_check_over_reference_equality_method = true : suggestion
dotnet_style_prefer_conditional_expression_over_assignment = true : suggestion
dotnet_style_prefer_conditional_expression_over_return = true : suggestion
dotnet_style_prefer_compound_assignment = true : suggestion
dotnet_style_coalesce_expression = true : warning
dotnet_style_null_propagation = true : suggestion
dotnet_style_prefer_is_null_check_over_reference_equality_method = true : suggestion
```

Use shorter, modern syntax.

```
dotnet_code_quality_unused_parameters = all : suggestion
```

Flag unused parameters.

```
csharp_style_var_elsewhere = true : suggestion
csharp_style_var_for_built_in_types = true : suggestion
csharp_style_var_when_type_is_apparent = true : suggestion
```

Use `var` everywhere.

```
csharp_style_expression_bodied_methods = true : suggestion
csharp_style_expression_bodied_constructors = false : suggestion
csharp_style_expression_bodied_operators = true : suggestion
csharp_style_expression_bodied_properties = true : suggestion
csharp_style_expression_bodied_indexers = true : suggestion
csharp_style_expression_bodied_accessors = true : suggestion
csharp_style_expression_bodied_lambdas = true : suggestion
csharp_style_expression_bodied_local_functions = true : suggestion
```

Use expression-bodied members everywhere but constructors.

```
csharp_style_pattern_matching_over_is_with_cast_check = true : suggestion
csharp_style_pattern_matching_over_as_with_null_check = true : suggestion
csharp_style_inlined_variable_declaration = true : suggestion
csharp_prefer_simple_default_expression = true : suggestion
csharp_style_throw_expression = true : suggestion
csharp_style_conditional_delegate_call = true : suggestion
```

Use shorter, modern syntax.

```
csharp_prefer_braces = when_multiline : suggestion
```

Don't use braces around single-line blocks.

```
csharp_style_unused_value_assignment_preference = discard_variable : suggestion
csharp_style_unused_value_expression_statement_preference = discard_variable : suggestion
```

Use discard variables.

```
csharp_style_prefer_index_operator = true : suggestion
csharp_style_prefer_range_operator = true : suggestion
```

Use the new index/range syntax.

```
csharp_style_deconstructed_variable_declaration = true : suggestion
csharp_style_pattern_local_over_anonymous_function = true : suggestion
csharp_prefer_static_local_function = true : suggestion
csharp_prefer_simple_using_statement = true : suggestion
csharp_style_prefer_switch_expression = true : suggestion
```

Use shorter, modern syntax.

## Formatting Conventions

The properties listed below are in the same order as in the [documentation](https://docs.microsoft.com/en-us/visualstudio/ide/editorconfig-formatting-conventions).

```
dotnet_sort_system_directives_first = true
dotnet_separate_import_directive_groups = false
csharp_using_directive_placement = outside_namespace : suggestion
```

Organize using directives.

```
csharp_new_line_before_open_brace = all
csharp_new_line_before_else = true
csharp_new_line_before_catch = true
csharp_new_line_before_finally = true
csharp_new_line_before_members_in_object_initializers = true
csharp_new_line_before_members_in_anonymous_types = true
csharp_new_line_within_query_expression_clauses = true
```

Braces on their own lines.

```
csharp_indent_case_contents = true
csharp_indent_switch_labels = false
```

We used to use `csharp_indent_switch_labels = false` but recently decided to stick with the default.

```
csharp_indent_labels = one_less_than_current
csharp_indent_block_contents = true
csharp_indent_braces = false
csharp_indent_case_contents_when_block = false
```

Our standard indentation rules.

```
csharp_space_after_cast = true
```

Non-standard but still popular.

```
csharp_space_after_keywords_in_control_flow_statements = true
csharp_space_between_parentheses = false
csharp_space_before_colon_in_inheritance_clause = true
csharp_space_after_colon_in_inheritance_clause = true
csharp_space_around_binary_operators = before_and_after
csharp_space_between_method_declaration_parameter_list_parentheses = false
csharp_space_between_method_declaration_empty_parameter_list_parentheses = false
csharp_space_between_method_declaration_name_and_open_parenthesis = false
csharp_space_between_method_call_parameter_list_parentheses = false
csharp_space_between_method_call_empty_parameter_list_parentheses = false
csharp_space_between_method_call_name_and_opening_parenthesis = false
csharp_space_after_comma = true
csharp_space_before_comma = false
csharp_space_after_dot = false
csharp_space_before_dot = false
csharp_space_after_semicolon_in_for_statement = true
csharp_space_before_semicolon_in_for_statement = false
csharp_space_around_declaration_statements = false
csharp_space_before_open_square_brackets = false
csharp_space_between_empty_square_brackets = false
csharp_space_between_square_brackets = false
```

Spaces around keywords, around inheritance colons, around binary operators, and after commas and semicolons.

```
csharp_preserve_single_line_statements = true
csharp_preserve_single_line_blocks = true
```

Let the developer decide when and where to wrap lines.

## Naming Conventions

See [documentation](https://docs.microsoft.com/en-us/visualstudio/ide/editorconfig-naming-conventions).

```
dotnet_naming_rule.local_functions_rule.severity = warning
dotnet_naming_rule.local_functions_rule.style = upper_camel_case_style
dotnet_naming_rule.local_functions_rule.symbols = local_functions_symbols
dotnet_naming_rule.private_constants_rule.severity = warning
dotnet_naming_rule.private_constants_rule.style = c_lower_camel_case_style
dotnet_naming_rule.private_constants_rule.symbols = private_constants_symbols
dotnet_naming_rule.private_instance_fields_rule.severity = warning
dotnet_naming_rule.private_instance_fields_rule.style = m_lower_camel_case_style
dotnet_naming_rule.private_instance_fields_rule.symbols = private_instance_fields_symbols
dotnet_naming_rule.private_static_fields_rule.severity = warning
dotnet_naming_rule.private_static_fields_rule.style = s_lower_camel_case_style
dotnet_naming_rule.private_static_fields_rule.symbols = private_static_fields_symbols
dotnet_naming_rule.private_static_readonly_rule.severity = warning
dotnet_naming_rule.private_static_readonly_rule.style = s_lower_camel_case_style
dotnet_naming_rule.private_static_readonly_rule.symbols = private_static_readonly_symbols
dotnet_naming_style.c_lower_camel_case_style.capitalization = camel_case
dotnet_naming_style.c_lower_camel_case_style.required_prefix = c_
dotnet_naming_style.m_lower_camel_case_style.capitalization = camel_case
dotnet_naming_style.m_lower_camel_case_style.required_prefix = m_
dotnet_naming_style.s_lower_camel_case_style.capitalization = camel_case
dotnet_naming_style.s_lower_camel_case_style.required_prefix = s_
dotnet_naming_style.upper_camel_case_style.capitalization = pascal_case
dotnet_naming_symbols.local_functions_symbols.applicable_accessibilities = *
dotnet_naming_symbols.local_functions_symbols.applicable_kinds = local_function
dotnet_naming_symbols.private_constants_symbols.applicable_accessibilities = private
dotnet_naming_symbols.private_constants_symbols.applicable_kinds = field
dotnet_naming_symbols.private_constants_symbols.required_modifiers = const
dotnet_naming_symbols.private_instance_fields_symbols.applicable_accessibilities = private
dotnet_naming_symbols.private_instance_fields_symbols.applicable_kinds = field
dotnet_naming_symbols.private_static_fields_symbols.applicable_accessibilities = private
dotnet_naming_symbols.private_static_fields_symbols.applicable_kinds = field
dotnet_naming_symbols.private_static_fields_symbols.required_modifiers = static
dotnet_naming_symbols.private_static_readonly_symbols.applicable_accessibilities = private
dotnet_naming_symbols.private_static_readonly_symbols.applicable_kinds = field
dotnet_naming_symbols.private_static_readonly_symbols.required_modifiers = static,readonly
```

Typical .NET naming and casing rules. Use `m_`, `s_`, and `c_` prefixes for private fields.
