//------------------------------------------------------------------------------------------------//
// This file is part of the Nebula Logger project, released under the MIT License.                //
// See LICENSE file or go to https://github.com/jongpie/NebulaLogger for full license details.    //
//------------------------------------------------------------------------------------------------//

/**
 * @group Log Management
 * @description Selector class used for all queries that are specific to the log management layer
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.ExcessivePublicCount')
public without sharing virtual class LogManagementDataSelector {
  private static final Boolean IS_OMNISTUDIO_ENABLED = System.Type.forName('Schema.OmniProcess') != null;

  private static LogManagementDataSelector instance = new LogManagementDataSelector();

  @SuppressWarnings('PMD.EmptyStatementBlock')
  @TestVisible
  private LogManagementDataSelector() {
  }

  /**
   * @description The instance `LogManagementDataSelector` used for any querying specific to the log management layer
   * @return   The singleton instance of `LogManagementDataSelector`
   */
  public static LogManagementDataSelector getInstance() {
    return instance;
  }

  /**
   * @description Dynamically queries & returns all records in the specified `SObjectType`
   * @param  sobjectType The `SObjectType` to query
   * @param  fieldNames  `Set<String>` API names of any fields to include in the query
   * @return             `List<SObject>` containing any records in the specified `SObjectType`
   */
  public virtual List<SObject> getAll(Schema.SObjectType sobjectType, Set<String> fieldNames) {
    String query = String.format('SELECT {0} FROM {1}', new List<Object>{ String.join(fieldNames, ', '), sobjectType });
    return System.Database.query(String.escapeSingleQuotes(query));
  }

  /**
   * @description Dynamically queries & returns records in the specified `SObjectType` based on
   *              the specified record IDs
   * @param  sobjectType The `SObjectType` to query
   * @param  fieldNames  `Set<String>` API names of any fields to include in the query
   * @param  recordIds   `List<Id>` of record IDs to include in the query results
   * @return             `List<SObject>` containing any matching records in the specified `SObjectType`
   */
  public virtual List<SObject> getById(Schema.SObjectType sobjectType, Set<String> fieldNames, List<Id> recordIds) {
    String query = String.format('SELECT {0} FROM {1} WHERE Id IN :recordIds', new List<Object>{ String.join(fieldNames, ', '), sobjectType });
    return System.Database.query(String.escapeSingleQuotes(query));
  }

  /**
   * @description Returns a list of `Schema.ApexClass` records
   * @param  apexClassNames The names of the Apex classes to query
   * @return                `List<Schema.ApexClass>` containing any matching records
   */
  public virtual List<Schema.ApexClass> getApexClasses(Set<String> apexClassNames) {
    if (LoggerParameter.QUERY_APEX_CLASS_DATA == false) {
      return new List<Schema.ApexClass>();
    }

    return [
      SELECT ApiVersion, Body, CreatedById, CreatedBy.Username, CreatedDate, Id, LastModifiedById, LastModifiedBy.Username, LastModifiedDate, Name
      FROM ApexClass
      WHERE Name IN :apexClassNames
      ORDER BY NamespacePrefix NULLS LAST
    ];
  }

  /**
   * @description Returns a list of `Schema.ApexTrigger` records
   * @param  apexTriggerNames The names of the Apex triggers to query
   * @return                `List<Schema.ApexTrigger>` containing any matching records
   */
  public virtual List<Schema.ApexTrigger> getApexTriggers(Set<String> apexTriggerNames) {
    if (LoggerParameter.QUERY_APEX_TRIGGER_DATA == false) {
      return new List<Schema.ApexTrigger>();
    }

    return [
      SELECT ApiVersion, Body, CreatedById, CreatedBy.Username, CreatedDate, Id, LastModifiedById, LastModifiedBy.Username, LastModifiedDate, Name
      FROM ApexTrigger
      WHERE Name IN :apexTriggerNames
      ORDER BY NamespacePrefix NULLS LAST
    ];
  }

  /**
   * @description Returns a cached copy of the `Schema.ApexEmailNotification` records in the org
   * @return   The cached `List<Schema.ApexEmailNotification>` records
   */
  public virtual List<Schema.ApexEmailNotification> getCachedApexEmailNotifications() {
    String cacheKey = 'ApexEmailNotifications';
    if (LoggerCache.getOrganizationCache().contains(cacheKey)) {
      return (List<Schema.ApexEmailNotification>) LoggerCache.getOrganizationCache().get(cacheKey);
    }

    List<Schema.ApexEmailNotification> apexEmailNotifications = [
      SELECT Email, UserId
      FROM ApexEmailNotification
      WHERE Email != NULL OR User.IsActive = TRUE
    ];
    LoggerCache.getOrganizationCache().put(cacheKey, apexEmailNotifications);
    return apexEmailNotifications;
  }

  /**
   * @description Returns a cached `Log__c` record that has been created within the last 4 hours
   *              that has API details populated from calling https://api.status.salesforce.com
   * @return   The cached `Log__c` record, or `null` if no match is found
   */
  public virtual Log__c getCachedRecentLogWithApiReleaseDetails() {
    if (LoggerParameter.CALL_STATUS_API == false) {
      return null;
    }

    String cacheKey = 'RecentLogWithApiReleaseDetails';
    if (LoggerCache.getOrganizationCache().contains(cacheKey)) {
      return (Log__c) LoggerCache.getOrganizationCache().get(cacheKey);
    }

    // Query for recent logs created only today - the status API should be called
    // at least once per day to make sure that status details are still accurate.
    // This query should make a callout approximately every 4 hours.
    Datetime fourHoursAgo = System.now().addMinutes(-4 * 60);

    List<Log__c> logs = [
      SELECT Id, ApiReleaseNumber__c, ApiReleaseVersion__c, OrganizationReleaseNumber__c, OrganizationReleaseVersion__c
      FROM Log__c
      WHERE CreatedDate >= :fourHoursAgo AND CreatedDate = TODAY AND ApiReleaseNumber__c != NULL
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    Log__c log = logs.isEmpty() ? null : logs.get(0);
    LoggerCache.getOrganizationCache().put(cacheKey, log);
    return log;
  }

  /**
   * @description Returns the count of `Schema.AsyncApexJob` records with the specified Apex class name, method name & job status
   * @param  apexClassName  The fully-qualified name of the Apex class associated with `Schema.AsyncApexJob`
   * @param  apexMethodName The specific method (if any) within the Apex class associated with `Schema.AsyncApexJob`
   * @param  jobStatuses    The list of job statuses that should be used to filter `AsynxApexJob` records
   * @return                The `Integer` count of matching `AsynxApexJob` records
   */
  public virtual Integer getCountOfAsyncApexJobs(String apexClassName, String apexMethodName, List<String> jobStatuses) {
    String apexClassNamespacePrefix = apexClassName.contains('.') ? apexClassName.substringBefore('.') : null;
    String apexClassLocalName = apexClassName.contains('.') ? apexClassName.substringAfter('.') : apexClassName;

    return [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE
        ApexClass.NamespacePrefix = :apexClassNamespacePrefix
        AND ApexClass.Name = :apexClassLocalName
        AND MethodName = :apexMethodName
        AND Status IN :jobStatuses
    ];
  }

  /**
   * @description Returns the count of `LogEntry__c` records related to the specified record ID
   * @param  recordId The `ID` to use for filtering `LogEntry__c` records
   * @return          The `Integer` count of matching `LogEntry__c` records
   */
  public virtual Integer getCountOfRelatedRecordLogEntries(Id recordId) {
    return [SELECT COUNT() FROM LogEntry__c WHERE RecordId__c = :recordId];
  }

  /**
   * @description Returns the list of `Schema.UserRecordAccess` records for any of the specified record IDs that the current user can delete
   * @param  recordIds The list of `ID` for records to be deleted
   * @return           The matching `List<Schema.UserRecordAccess>` records
   */
  public virtual List<Schema.UserRecordAccess> getDeleteableUserRecordAccess(List<Id> recordIds) {
    return [SELECT RecordId FROM UserRecordAccess WHERE UserId = :System.UserInfo.getUserId() AND RecordId IN :recordIds AND HasDeleteAccess = TRUE];
  }

  /**
   * @description Returns a list of `Schema.FlowDefinitionView` records
   * @param  flowApiNames The names of the Apex classes to query
   * @return              `List<Schema.FlowDefinitionView>` containing any matching records
   */
  public virtual List<Schema.FlowDefinitionView> getFlowDefinitionViewsByFlowApiName(List<String> flowApiNames) {
    if (LoggerParameter.QUERY_FLOW_DEFINITION_VIEW_DATA == false) {
      return new List<Schema.FlowDefinitionView>();
    }

    return [
      SELECT
        ActiveVersionId,
        ApiName,
        Description,
        DurableId,
        Label,
        LastModifiedBy, // This is a text field of the person's name - it's NOT a lookup to Schema.User :'(
        LastModifiedDate,
        ManageableState,
        ProcessType,
        RecordTriggerType,
        TriggerObjectOrEvent.QualifiedApiName,
        TriggerOrder,
        TriggerType,
        VersionNumber
      FROM FlowDefinitionView
      WHERE ApiName IN :flowApiNames AND IsActive = TRUE
    ];
  }

  /**
   * @description Returns a list of `Schema.FlowVersionView` records description
   * @param  durableIds The durable IDs of the Flows to query
   * @return            `List<Schema.FlowDefinitionView>` containing any matching records
   */
  public virtual List<Schema.FlowVersionView> getFlowVersionViewsByDurableId(List<String> durableIds) {
    return [SELECT ApiVersionRuntime, FlowDefinitionViewId, RunInMode, Status, VersionNumber FROM FlowVersionView WHERE DurableId IN :durableIds];
  }

  /**
   * @description Returns a `Log__c` record
   * @param  logId The `ID` of the `Log__c` record to query
   * @return       The matching `Log__c` record
   */
  public virtual Log__c getLogById(Id logId) {
    String queryTemplate = 'SELECT {0} FROM {1} WHERE Id = :logId';

    List<String> logFieldNames = new List<String>(Schema.Log__c.SObjectType.getDescribe().fields.getMap().keySet());
    logFieldNames.addAll(new List<String>{ 'Owner.Name', 'Owner.Type' });
    List<String> textReplacements = new List<String>{ String.join(logFieldNames, ','), Schema.Log__c.SObjectType.toString() };

    String query = String.format(queryTemplate, textReplacements);
    return (Log__c) System.Database.query(String.escapeSingleQuotes(query));
  }

  /**
   * @description Returns a `LogEntry__c` record
   * @param  logEntryId The `ID` of the `LogEntry__c` record to query
   * @return            The matching `LogEntry__c` record
   */
  public virtual LogEntry__c getLogEntryById(Id logEntryId) {
    String queryTemplate = 'SELECT {0} FROM {1} WHERE Id = :logEntryId';

    List<String> logEntryFieldNames = new List<String>(Schema.LogEntry__c.SObjectType.getDescribe().fields.getMap().keySet());
    List<String> textReplacements = new List<String>{ String.join(logEntryFieldNames, ','), Schema.LogEntry__c.SObjectType.toString() };

    String query = String.format(queryTemplate, textReplacements);
    return (LogEntry__c) System.Database.query(String.escapeSingleQuotes(query));
  }

  /**
   * @description Returns a `List<LogEntry__c>` records for the specified `Log__c` ID
   * @param  logId The `ID` of the `Log__c` record of the `LogEntry__c` records to query
   * @return       The matching `List<LogEntry__c>` records
   */
  public virtual List<LogEntry__c> getLogEntriesByLogId(Id logId) {
    String queryTemplate = 'SELECT {0} FROM {1} WHERE {2} = :logId ORDER BY {3}';

    List<String> logEntryFieldNames = new List<String>(Schema.LogEntry__c.SObjectType.getDescribe().fields.getMap().keySet());
    List<String> textReplacements = new List<String>{
      String.join(logEntryFieldNames, ', '),
      Schema.LogEntry__c.SObjectType.toString(),
      Schema.LogEntry__c.Log__c.toString(),
      Schema.LogEntry__c.TransactionEntryNumber__c.toString()
    };

    String query = String.format(queryTemplate, textReplacements);
    return (List<LogEntry__c>) System.Database.query(String.escapeSingleQuotes(query));
  }

  /**
   * @description Returns a `Log__c` record and its related `LogEntry__c` records
   * @param  logIds The list of `ID` of the `Log__c` records to query
   * @return        The list of matching `Log__c` records
   */
  public virtual List<Log__c> getLogsById(List<Id> logIds) {
    return [SELECT Id, Name, LoggedBy__c, LoggedBy__r.Name, StartTime__c, TotalLogEntries__c, TransactionId__c FROM Log__c WHERE Id IN :logIds];
  }

  /**
   * @description Returns a `List<Log__c>` of records with the specified parent transaction IDs and a `null` value in `ParentLog__c`
   * @param  parentTransactionIds The list of `String` parent transaction IDs of the `Log__c` records to query
   * @return                      The list of matching `Log__c` records
   */
  public virtual List<Log__c> getLogsWithoutParentLogByParentTransactionId(List<String> parentTransactionIds) {
    return [
      SELECT Id, ParentLogTransactionId__c, ParentLog__c, ParentLog__r.TransactionId__c, TransactionId__c
      FROM Log__c
      WHERE ParentLogTransactionId__c IN :parentTransactionIds AND ParentLog__c = NULL
    ];
  }

  /**
   * @description Returns a `List<Log__c>` of records with the specified transaction IDs
   * @param  transactionIds The list of `String` transaction IDs of the `Log__c` records to query
   * @return                The list of matching `Log__c` records
   */
  public virtual List<Log__c> getLogsByTransactionId(List<String> transactionIds) {
    return [SELECT Id, TransactionId__c FROM Log__c WHERE TransactionId__c IN :transactionIds];
  }

  /**
   * @description Returns a `List<LoggerScenario__c>` of records with the specified log scenario IDs
   * @param  logScenarioIds The list of `ID` of the `Log__c` records to query
   * @return                The list of matching `LoggerScenario__c` records
   */
  public virtual List<LoggerScenario__c> getLoggerScenariosById(List<Id> logScenarioIds) {
    return [SELECT Id, OwnerId, UniqueId__c FROM LoggerScenario__c WHERE Id IN :logScenarioIds];
  }

  /**
   * @description Returns a list of matching `Schema.OmniProcess` records based on the provided list of OmniProcess IDs
   * @param  omniProcessIds The list of `Schema.OmniProcess` IDs to query
   * @return            The instance of `Map<Id, SObject>` containing any matching `Schema.OmniProcess` records
   */
  public virtual Map<Id, LoggerSObjectProxy.OmniProcess> getOmniProcessProxies(List<Id> omniProcessIds) {
    if (LoggerParameter.QUERY_OMNI_PROCESS_DATA == false) {
      return new Map<Id, LoggerSObjectProxy.OmniProcess>();
    }

    // OmniStudio may not be enabled in the org, and the Schema.OmniProcess object may not exist,
    // so run everything dynamically
    Map<Id, LoggerSObjectProxy.OmniProcess> omniProcessIdToOmniProcessProxy = new Map<Id, LoggerSObjectProxy.OmniProcess>();
    String query =
      'SELECT CreatedBy.Username, CreatedById, CreatedDate, Id, IsIntegrationProcedure, LastModifiedBy.Username, LastModifiedById, LastModifiedDate, OmniProcessType, UniqueName' +
      ' FROM OmniProcess WHERE Id IN :omniProcessIds';
    List<SObject> omniProcessRecords = IS_OMNISTUDIO_ENABLED ? System.Database.query(String.escapeSingleQuotes(query)) : new List<SObject>();

    List<LoggerSObjectProxy.OmniProcess> omniProcessProxies = (List<LoggerSObjectProxy.OmniProcess>) System.JSON.deserialize(
      System.JSON.serialize(omniProcessRecords),
      List<LoggerSObjectProxy.OmniProcess>.class
    );

    for (LoggerSObjectProxy.OmniProcess omniProcessProxy : omniProcessProxies) {
      omniProcessIdToOmniProcessProxy.put(omniProcessProxy.Id, omniProcessProxy);
    }
    return omniProcessIdToOmniProcessProxy;
  }

  /**
   * @description Returns a `List<Schema.Profile>` of records with the specified profile IDs
   * @param  profileIds The list of `ID` of the `Schema.Profile` records to query
   * @return            The list of matching `Schema.Profile` records
   */
  public virtual List<Schema.Profile> getProfilesById(List<Id> profileIds) {
    return [SELECT Id, Name FROM Profile WHERE Id IN :profileIds];
  }

  /**
   * @description Returns a `List<Schema.Profile>` of records where the profile's names partially matches the specified search term
   * @param  searchTerm The `String` search term to use for searching `Schema.Profile` records
   * @return            The list of matching `Schema.Profile` records
   */
  public virtual List<Schema.Profile> getProfilesByNameSearch(String searchTerm) {
    return [SELECT Id, Name, UserLicense.Name FROM Profile WHERE Name LIKE :searchTerm];
  }

  /**
   * @description Returns a `List<Schema.Group>` of records with the specified developer names and type == 'Queue'
   * @param  queueDeveloperNames The list of `String` queue developer names to query
   * @return                     The list of matching `Schema.Group` records
   */
  public virtual List<Schema.Group> getQueuesByDeveloperName(List<String> queueDeveloperNames) {
    return [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName IN :queueDeveloperNames];
  }

  /**
   * @description Returns the list of `LogEntry__c` records related to the specified record ID
   * @param  recordId      The `ID` to use for filtering `LogEntry__c` records
   * @param  fieldsClause  A comma-separated `String` of field API names to include in the query
   * @param  orderByClause A comma-separated `String` of field API names to use for sorting the query results
   * @param  rowLimit      The maximum number of records to return
   * @return               The list of matching `LogEntry__c` records
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public virtual List<LogEntry__c> getRecordLogEntries(Id recordId, String fieldsClause, String orderByClause, Integer rowLimit) {
    List<Object> queryTextReplacements = new List<Object>{
      fieldsClause,
      Schema.LogEntry__c.SObjectType.toString(),
      Schema.LogEntry__c.RecordId__c.toString(),
      orderByClause,
      rowLimit
    };
    String logEntryQuery = 'SELECT {0} FROM {1} WHERE {2} = :recordId ORDER BY {3} LIMIT {4}';
    logEntryQuery = String.format(logEntryQuery, queryTextReplacements);

    return (List<LogEntry__c>) System.Database.query(String.escapeSingleQuotes(logEntryQuery));
  }

  /**
   * @description Returns a list of `LoggerTag__c` records with one of the specified tag names
   * @param  tagNames The set of `String` tag names to query
   * @return          The list of matching `LoggerTag__c` records
   */
  public virtual List<LoggerTag__c> getTagsByName(Set<String> tagNames) {
    return [SELECT Id, Name FROM LoggerTag__c WHERE Name IN :tagNames];
  }

  /**
   * @description Returns a list of `Schema.Topic` records with one of the specified topic names
   * @param  topicNames The set of `String` topic names to query
   * @return            The list of matching `Schema.Topic` records
   */
  public virtual List<Schema.Topic> getTopicsByName(Set<String> topicNames) {
    return [SELECT Id, Name FROM Topic WHERE Name IN :topicNames];
  }

  /**
   * @description Returns a `List<Schema.User>` of records with the specified user IDs
   * @param  userIds The list of `ID` of the `Schema.User` records to query
   * @return         The list of matching `Schema.User` records
   */
  public virtual List<Schema.User> getUsersById(List<Id> userIds) {
    return [SELECT Id, Username FROM User WHERE Id IN :userIds];
  }

  /**
   * @description Returns a `List<Schema.User>` of records where the User's names or username partially matches the specified search term
   * @param  searchTerm The `String` search term to use for searching `Schema.User` records
   * @return            The list of matching `Schema.User` records
   */
  public virtual List<Schema.User> getUsersByNameSearch(String searchTerm) {
    if (String.isBlank(searchTerm)) {
      return new List<Schema.User>();
    }

    return [SELECT Id, Name, Username, SmallPhotoUrl FROM User WHERE Name LIKE :searchTerm OR Username LIKE :searchTerm ORDER BY Username LIMIT 20];
  }

  /**
   * @description Returns a `List<Schema.User>` of records with the specified usernames (`Schema.User.Username`)
   * @param  usernames The list of `String` user usernames to query
   * @return           Tje list of matching `Schema.User` records
   */
  public virtual List<Schema.User> getUsersByUsername(List<String> usernames) {
    return [SELECT Id, Username FROM User WHERE Username IN :userNames];
  }

  @TestVisible
  private static void setMock(LogManagementDataSelector mockSelectorInstance) {
    instance = mockSelectorInstance;
  }
}
