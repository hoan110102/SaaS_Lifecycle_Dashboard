-- macros/handle_issue.sql

{% macro handle_issue(column, fill_value='') %}
    {% set text_raw %}
    case
        -- missing value
        when lower({{column}}) in ('null', 'n/a', 'na', 'nan', 'none') or {{column}} is null then '{{fill_value}}'
        else trim({{column}})
    end
    {% endset %}

    {% if text_raw!='' %}
        {{ capitalize_words(text_raw) }}
    {% endif %}
{% endmacro %}