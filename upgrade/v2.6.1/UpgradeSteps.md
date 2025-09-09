## Upgrade Steps
### All jobs cloned from queue_ReturnedOrderIdsFeed
1. Pause the Service Jobs scheduled
2. Add below data
        ```xml
        <moqui.service.job.ServiceJob jobName="queue_ReturnedOrderIdsFeed" serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.queue#FeedSystemMessage">
            <parameters parameterName="additionalParameters" parameterValue=""/>
            <parameters parameterName="runAsBatch" parameterValue="true"/>
        </moqui.service.job.ServiceJob>
        ```
3. Provide value for additionalParameters. Example- {"thruDateBuffer":5}
4. Update the SystemMessage with the Init date:
        ```SQL query
                SELECT SYSTEM_MESSAGE_ID, INIT_DATE, MESSAGE_DATE
                FROM system_message
                WHERE system_message_type_id = 'GenerateReturnedOrderIdsFeed'
                ORDER BY PROCESSED_DATE DESC
                LIMIT 1;
        ```
5. Retrieve the InitDate from the result.
6. Update the same SystemMessage’s message_date with the retrieved init_date value.