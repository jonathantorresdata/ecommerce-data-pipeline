{#- Use the schema set in dbt_project.yml as is (silver, gold) instead of
    dbt's default "<target schema>_<custom schema>". -#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ custom_schema_name if custom_schema_name is not none else target.schema }}
{%- endmacro %}
