## Perform following migration steps before upgrading
1. Delete previous data where SYSTEM_MESSAGE_REMOTE_ID is null.
```sql
delete from SYSTEM_MESSAGE_TYPE_PARAMETER where SYSTEM_MESSAGE_REMOTE_ID is NULL;
```
2. To change the primary key constraint
    1. Drop the previous one.
   2. Add new primary key constraint:
```sql
alter table SYSTEM_MESSAGE_TYPE_PARAMETER drop PRIMARY KEY;
```
```sql
alter table SYSTEM_MESSAGE_TYPE_PARAMETER add PRIMARY KEY(SYSTEM_MESSAGE_TYPE_ID, PARAMETER_NAME, SYSTEM_MESSAGE_REMOTE_ID);
```
3. Verify new constraint:
```sql
desc SYSTEM_MESSAGE_TYPE_PARAMETER;
```