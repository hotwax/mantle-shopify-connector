## Upgrade Steps
### Poll OMS Order Ids Feed
1. SystemMessageType for GenerateOrderMetafieldsFeed
    1. Make sure to include the systemMessageId in the sendPath for the specific shop or product store's SystemMessageType GenerateOrderMetafieldsFeed_{shopId_storeId}.
       - Sample data
        ```xml
        <moqui.service.message.SystemMessageType systemMessageTypeId="GenerateOrderMetafieldsFeed_{shopId_storeId}"
                    sendPath="${contentRoot}/shopify/OrderMetafieldsFeed/OrderMetafieldsFeed-${dateTime}-${systemMessageId}.json">
        </moqui.service.message.SystemMessageType>
        ```