//------------------------------------------------------------------------------------------------//
// This file is part of the Nebula Logger project, released under the MIT License.                //
// See LICENSE file or go to https://github.com/jongpie/NebulaLogger for full license details.    //
//------------------------------------------------------------------------------------------------//

@SuppressWarnings('PMD.ApexDoc, PMD.CyclomaticComplexity, PMD.ExcessiveParameterList, PMD.MethodNamingConventions')
@IsTest(IsParallel=true)
private class LoggerEngineDataSelector_Tests {
  static {
    // Don't use the org's actual custom metadata records when running tests
    LoggerConfigurationSelector.useMocks();
  }

  @IsTest
  static void it_loads_mock_instance() {
    MockLoggerEngineDataSelector mockSelector = new MockLoggerEngineDataSelector();
    System.Assert.areNotEqual(mockSelector, LoggerEngineDataSelector.getInstance());

    LoggerEngineDataSelector.setMock(mockSelector);

    System.Assert.areEqual(mockSelector, LoggerEngineDataSelector.getInstance());
  }

  @IsTest
  static void it_returns_cached_auth_session_proxy_when_populated_in_cache() {
    System.Assert.isTrue(LoggerParameter.QUERY_AUTH_SESSION_DATA);
    System.Assert.areEqual(0, System.Limits.getQueries());
    LoggerEngineDataSelector.useMocks();
    LoggerSObjectProxy.AuthSession mockAuthSessionProxy = new LoggerSObjectProxy.AuthSession();
    LoggerCache.getOrganizationCache().put('AuthSession' + System.UserInfo.getUserId(), mockAuthSessionProxy);

    LoggerSObjectProxy.AuthSession returnedAuthSessionProxy = LoggerEngineDataSelector.getInstance().getCachedAuthSessionProxy();

    System.Assert.areEqual(0, System.Limits.getQueries());
    System.Assert.areEqual(mockAuthSessionProxy, returnedAuthSessionProxy);
  }

  @IsTest
  static void it_returns_queried_auth_session_proxy_when_cache_is_not_populated() {
    List<Schema.AuthSession> sessions = [
      SELECT
        Id,
        LoginHistory.Application,
        LoginHistory.Browser,
        LoginHistory.Platform,
        LoginHistoryId,
        LoginType,
        LogoutUrl,
        ParentId,
        SessionSecurityLevel,
        SessionType,
        SourceIp
      FROM AuthSession
      WHERE UsersId = :System.UserInfo.getUserId() AND IsCurrent = TRUE
    ];
    LoggerSObjectProxy.AuthSession expectedAuthSessionProxy = sessions.isEmpty()
      ? null
      : (LoggerSObjectProxy.AuthSession) System.JSON.deserialize(System.JSON.serialize(sessions.get(0)), LoggerSObjectProxy.AuthSession.class);
    System.Assert.areEqual(1, System.Limits.getQueries());

    LoggerSObjectProxy.AuthSession returnedAuthSessionProxy = LoggerEngineDataSelector.getInstance().getCachedAuthSessionProxy();

    System.Assert.areEqual(2, System.Limits.getQueries());
    LoggerEngineDataSelector.getInstance().getCachedAuthSessionProxy();
    System.Assert.areEqual(2, System.Limits.getQueries(), 'Query results should have been cached');
    System.Assert.areEqual(expectedAuthSessionProxy, returnedAuthSessionProxy);
  }

  @IsTest
  static void it_returns_mock_auth_session_proxy_when_mock_is_provided() {
    System.Assert.isTrue(LoggerParameter.QUERY_AUTH_SESSION_DATA);
    System.Assert.areEqual(0, System.Limits.getQueries());
    LoggerEngineDataSelector.useMocks();
    LoggerSObjectProxy.AuthSession mockAuthSessionProxy = new LoggerSObjectProxy.AuthSession();
    mockAuthSessionProxy.UsersId = System.UserInfo.getUserId();
    LoggerEngineDataSelector.mockAuthSessionProxies.add(mockAuthSessionProxy);

    LoggerSObjectProxy.AuthSession returnedAuthSessionProxy = LoggerEngineDataSelector.getInstance().getCachedAuthSessionProxy();

    System.Assert.areEqual(1, System.Limits.getQueries());
    System.Assert.areEqual(mockAuthSessionProxy, returnedAuthSessionProxy);
  }

  @IsTest
  static void it_returns_null_when_querying_auth_session_is_disabled() {
    LoggerParameter.setMock(new LoggerParameter__mdt(DeveloperName = 'QueryAuthSessionData', Value__c = String.valueOf(false)));
    System.Assert.isFalse(LoggerParameter.QUERY_AUTH_SESSION_DATA);

    LoggerSObjectProxy.AuthSession returnedAuthSessionProxy = LoggerEngineDataSelector.getInstance().getCachedAuthSessionProxy();

    System.Assert.areEqual(0, System.Limits.getQueries());
    System.Assert.isNull(returnedAuthSessionProxy);
  }

  @IsTest
  static void it_does_not_query_auth_session_when_disabled_via_logger_parameter() {
    MockLoggerEngineDataSelector mockSelector = new MockLoggerEngineDataSelector();
    LoggerEngineDataSelector.setMock(mockSelector);
    System.Assert.areEqual(mockSelector, LoggerEngineDataSelector.getInstance());
    System.Assert.areEqual(0, mockSelector.getCachedAuthSessionQueryCount());
    LoggerParameter.setMock(new LoggerParameter__mdt(DeveloperName = 'QueryAuthSessionData', Value__c = String.valueOf(false)));

    LoggerSObjectProxy.AuthSession returnedAuthSessionProxy = LoggerEngineDataSelector.getInstance().getCachedAuthSessionProxy();

    System.Assert.areEqual(0, mockSelector.getCachedAuthSessionQueryCount());
    System.Assert.isNull(returnedAuthSessionProxy);
  }

  @IsTest
  static void it_returns_null_when_querying_network_is_disabled() {
    LoggerParameter.setMock(new LoggerParameter__mdt(DeveloperName = 'QueryNetworkData', Value__c = String.valueOf(false)));
    System.Assert.isFalse(LoggerParameter.QUERY_NETWORK_DATA);
    Id someNetworkId = System.UserInfo.getUserId();
    System.Assert.areEqual(0, System.Limits.getQueries());

    LoggerSObjectProxy.Network returnedNetworkProxy = LoggerEngineDataSelector.getInstance().getCachedNetworkProxy(someNetworkId);

    System.Assert.areEqual(0, System.Limits.getQueries());
    System.Assert.isNull(returnedNetworkProxy);
  }

  @IsTest
  static void it_returns_null_when_network_id_is_null() {
    System.Assert.isTrue(LoggerParameter.QUERY_NETWORK_DATA);
    Id someNetworkId;
    System.Assert.areEqual(0, System.Limits.getQueries());

    LoggerSObjectProxy.Network returnedNetworkProxy = LoggerEngineDataSelector.getInstance().getCachedNetworkProxy(someNetworkId);

    System.Assert.areEqual(0, System.Limits.getQueries());
    System.Assert.isNull(returnedNetworkProxy);
  }

  @IsTest
  static void it_returns_cached_network_proxy_when_populated_in_cache() {
    System.Assert.isTrue(LoggerParameter.QUERY_NETWORK_DATA);
    System.Assert.areEqual(0, System.Limits.getQueries());
    LoggerEngineDataSelector.useMocks();
    LoggerSObjectProxy.Network mockNetworkProxy = new LoggerSObjectProxy.Network();
    mockNetworkProxy.Id = System.UserInfo.getUserId();
    LoggerCache.getOrganizationCache().put('Network' + mockNetworkProxy.Id, mockNetworkProxy);

    LoggerSObjectProxy.Network returnedNetworkProxy = LoggerEngineDataSelector.getInstance().getCachedNetworkProxy(mockNetworkProxy.Id);

    System.Assert.areEqual(0, System.Limits.getQueries());
    System.Assert.areEqual(mockNetworkProxy, returnedNetworkProxy);
  }

  @IsTest
  static void it_returns_mock_network_proxy_when_mock_is_provided() {
    System.Assert.isTrue(LoggerParameter.QUERY_NETWORK_DATA);
    System.Assert.areEqual(0, System.Limits.getQueries());
    LoggerEngineDataSelector.useMocks();
    LoggerSObjectProxy.Network mockNetworkProxy = new LoggerSObjectProxy.Network();
    mockNetworkProxy.Id = System.UserInfo.getUserId();
    LoggerEngineDataSelector.mockNetworkProxies.add(mockNetworkProxy);

    LoggerSObjectProxy.Network returnedNetworkProxy = LoggerEngineDataSelector.getInstance().getCachedNetworkProxy(mockNetworkProxy.Id);

    Integer expectedQueryCount = LoggerEngineDataSelector.IS_EXPERIENCE_CLOUD_ENABLED ? 1 : 0;
    System.Assert.areEqual(expectedQueryCount, System.Limits.getQueries());
    System.Assert.areEqual(mockNetworkProxy, returnedNetworkProxy);
  }

  @IsTest
  static void it_returns_cached_organization() {
    Schema.Organization expectedOrganization = [
      SELECT
        Id,
        CreatedById,
        CreatedBy.Name,
        CreatedBy.Username,
        CreatedDate,
        InstanceName,
        IsSandbox,
        Name,
        NamespacePrefix,
        OrganizationType,
        TrialExpirationDate
      FROM Organization
    ];
    MockLoggerEngineDataSelector mockSelector = new MockLoggerEngineDataSelector();
    LoggerEngineDataSelector.setMock(mockSelector);
    System.Assert.areEqual(mockSelector, LoggerEngineDataSelector.getInstance());
    System.Assert.areEqual(0, mockSelector.getCachedOrganizationQueryCount());

    Schema.Organization returnedOrganization = LoggerEngineDataSelector.getInstance().getCachedOrganization();

    System.Assert.areEqual(1, mockSelector.getCachedOrganizationQueryCount());
    LoggerEngineDataSelector.getInstance().getCachedOrganization();
    System.Assert.areEqual(1, mockSelector.getCachedOrganizationQueryCount(), 'Query results should have been cached');
    System.Assert.areEqual(expectedOrganization, returnedOrganization);
  }

  @IsTest
  static void it_does_not_query_organization_when_disabled_via_logger_parameter() {
    MockLoggerEngineDataSelector mockSelector = new MockLoggerEngineDataSelector();
    System.Assert.areNotEqual(mockSelector, LoggerEngineDataSelector.getInstance());
    System.Assert.areEqual(0, mockSelector.getCachedOrganizationQueryCount());
    LoggerParameter.setMock(new LoggerParameter__mdt(DeveloperName = 'QueryOrganizationData', Value__c = String.valueOf(false)));

    Schema.Organization returnedOrganization = LoggerEngineDataSelector.getInstance().getCachedOrganization();

    System.Assert.areEqual(0, mockSelector.getCachedOrganizationQueryCount());
    System.Assert.isNull(returnedOrganization);
  }

  @IsTest
  static void it_returns_cached_user() {
    Schema.User expectedUser = [
      SELECT
        FederationIdentifier,
        Id,
        Profile.Name,
        Profile.UserLicenseId,
        Profile.UserLicense.LicenseDefinitionKey,
        Profile.UserLicense.Name,
        Username,
        UserRole.Name
      FROM User
      WHERE Id = :System.UserInfo.getUserId()
    ];
    System.Assert.areEqual(1, System.Limits.getQueries());

    Schema.User returnedUser = LoggerEngineDataSelector.getInstance().getCachedUser();

    System.Assert.areEqual(2, System.Limits.getQueries());
    LoggerEngineDataSelector.getInstance().getCachedUser();
    System.Assert.areEqual(2, System.Limits.getQueries(), 'Query results should have been cached');
    System.Assert.areEqual(expectedUser, returnedUser);
  }

  @IsTest
  static void it_returns_null_when_querying_user_is_disabled() {
    LoggerParameter.setMock(new LoggerParameter__mdt(DeveloperName = 'QueryUserData', Value__c = String.valueOf(false)));
    System.Assert.isFalse(LoggerParameter.QUERY_USER_DATA);

    Schema.User returnedUser = LoggerEngineDataSelector.getInstance().getCachedUser();

    System.Assert.areEqual(0, System.Limits.getQueries());
    System.Assert.isNull(returnedUser);
  }

  private class MockLoggerEngineDataSelector extends LoggerEngineDataSelector {
    private Integer authSessionQueryCount = 0;
    private Integer organizationQueryCount = 0;

    public override LoggerSObjectProxy.AuthSession getCachedAuthSessionProxy() {
      Integer originalQueryCount = System.Limits.getQueries();
      LoggerSObjectProxy.AuthSession result = super.getCachedAuthSessionProxy();
      if (System.Limits.getQueries() != originalQueryCount) {
        authSessionQueryCount = System.Limits.getQueries() - originalQueryCount;
      }
      return result;
    }

    public Integer getCachedAuthSessionQueryCount() {
      return authSessionQueryCount;
    }

    public override Schema.Organization getCachedOrganization() {
      Integer originalQueryCount = System.Limits.getQueries();
      Schema.Organization result = super.getCachedOrganization();
      if (System.Limits.getQueries() != originalQueryCount) {
        organizationQueryCount = System.Limits.getQueries() - originalQueryCount;
      }
      return result;
    }

    public Integer getCachedOrganizationQueryCount() {
      return organizationQueryCount;
    }
  }
}
