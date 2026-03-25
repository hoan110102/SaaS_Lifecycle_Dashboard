{% macro capitalize_words(column) %}
    array_to_string(
        list_transform(
            regexp_split_to_array(lower({{ column }}), '\s+'),
            x -> upper(left(x, 1)) || x[2:]
        ),
        ' '
    )
{% endmacro %}