-- SQL query to update cloned service jobs with their parent job's Job Type Enumeration ID
UPDATE
    service_job SJ_CLONE
JOIN
    service_job SJ_PARENT
    ON SJ_CLONE.PARENT_JOB_NAME = SJ_PARENT.JOB_NAME
SET
    SJ_CLONE.JOB_TYPE_ENUM_ID = SJ_Parent.JOB_TYPE_ENUM_ID