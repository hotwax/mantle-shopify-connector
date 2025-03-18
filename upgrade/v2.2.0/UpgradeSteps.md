## Upgrade Steps

### Purge SendCreatedProductsFeed systemMessages

1. Open the service purge#OldSystemMessages from Services in the Tools.
2. Pass purgeDays as 0 and systemMessageTypeId as SendCreatedProductsFeed.
3. Run the service with the above parameters.
4. Run the SQL queries in the Upgrade SQL.

### Purge SendProductUpdatesFeed systemMessages

1. Open the service purge#OldSystemMessages from Services in the Tools.
2. Pass purgeDays as 0 and systemMessageTypeId as SendProductUpdatesFeed.
3. Run the service with the above parameters.
4. Run the SQL queries in the Upgrade SQL.