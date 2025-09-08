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
3. Check for last System Message ProcessedDate, add that date as fromDate in the job and update it.
        ```Sql query
        SELECT MAX(processed_date) AS last_processed_date
        FROM system_message
        WHERE system_message_type_id = 'GenerateReturnedOrderIdsFeed';
        ```
4. Run the job once with this fromDate.
5. After the first run, remove fromDate and update the job.
6. Un-pause the job to resume normal scheduling.