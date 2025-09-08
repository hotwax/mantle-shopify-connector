## Upgrade Steps
### All jobs cloned from queue_ReturnedOrderIdsFeed
1. Pause the Service Jobs scheduled
2. Add below data
        ```xml
        <moqui.service.job.ServiceJob jobName="queue_ReturnedOrderIdsFeed" serviceName="co.hotwax.shopify.system.ShopifySystemMessageServices.queue#FeedSystemMessage">
            <parameters parameterName="bufferTime" parameterValue=""/>
            <parameter name="runAsBatch" parameterValue="true"/>
        </moqui.service.job.ServiceJob>
        ```
3. Update the SystemMessage with the latest processed date:
        ```SQL query
                SELECT SYSTEM_MESSAGE_ID, INIT_DATE, MESSAGE_DATE
                FROM system_message
                WHERE system_message_type_id = 'GenerateReturnedOrderIdsFeed'
                ORDER BY PROCESSED_DATE DESC
                LIMIT 1;
        ```
4. Retrieve the InitDate from the result.
5. Update the same SystemMessage by adding MessageDate to the retrieved InitDate.