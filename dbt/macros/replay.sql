{#- Live-store replay helpers. See the vars in dbt_project.yml. -#}

{#- Days between the original date and the store opening day. -#}
{% macro replay_shift_days() -%}
    {%- set opening = modules.datetime.date.fromisoformat(var('replay_store_opening')) -%}
    {%- set original = modules.datetime.date.fromisoformat(var('replay_original_start')) -%}
    {{ (opening - original).days }}
{%- endmacro %}

{#- Move an original timestamp to its replayed date. -#}
{% macro replay(column) -%}
    timestampadd(DAY, {{ replay_shift_days() }}, {{ column }})
{%- endmacro %}

{#- The moment the store is rebuilt for: now, or the as_of var. -#}
{% macro as_of() -%}
    {%- if var('as_of') -%} TIMESTAMP '{{ var("as_of") }}' {%- else -%} current_timestamp() {%- endif -%}
{%- endmacro %}

{#- An event that has not happened yet is not visible: return NULL. -#}
{% macro visible(column) -%}
    CASE WHEN {{ column }} <= {{ as_of() }} THEN {{ column }} END
{%- endmacro %}
