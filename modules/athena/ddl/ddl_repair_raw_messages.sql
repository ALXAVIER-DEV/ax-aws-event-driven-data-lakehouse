-- Template variables:
--   ${database_name}
--   ${raw_table_name}

MSCK REPAIR TABLE ${database_name}.${raw_table_name};
