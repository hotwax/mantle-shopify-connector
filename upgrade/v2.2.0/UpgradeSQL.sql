-- SQL query to delete the systemMessageType and enumeration record for SendCreatedProductsFeed

delete from system_message_type where system_message_type_id = 'SendCreatedProductsFeed'

delete from enumeration where enum_id = 'SendCreatedProductsFeed'

-- SQL query to delete the enumeration record for GenerateCreatedProductsFeed and GenerateCreatedProductIdsFeed

delete from enumeration where enum_id = 'GenerateCreatedProductIdsFeed'

delete from enumeration where enum_id = 'GenerateCreatedProductsFeed'

-- SQL query to delete systemMessageTypeParameter record for GenerateProductUpdatesFeed systemMessageType

delete from system_message_type_parameter where system_message_type_id = 'GenerateProductUpdatesFeed'
and parameter_name = 'sendSmrId'

-- SQL query to delete the systemMessageType and enumeration record for SendCreatedProductsFeed

delete from system_message_type where system_message_type_id = 'SendProductUpdatesFeed'

delete from enumeration where enum_id = 'SendProductUpdatesFeed'

-- SQL query to delete the enumeration record for GenerateProductUpdatesFeed and GenerateUpdatedProductIdsFeed

delete from enumeration where enum_id = 'GenerateProductUpdatesFeed'

delete from enumeration where enum_id = 'GenerateUpdatedProductIdsFeed'

-- SQL query to delete systemMessageTypeParameter record for GenerateProductUpdatesFeed systemMessageType

delete from system_message_type_parameter where system_message_type_id = 'GenerateCreatedProductsFeed'
and parameter_name = 'sendSmrId'



