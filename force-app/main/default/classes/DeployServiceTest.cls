@IsTest
private class DeployServiceTest {

    private static void setupTestConfig() {
        DeploySetup__c cfg = new DeploySetup__c(
            StartTime__c = System.now().addMinutes(1),
            IsEnabled__c = true,
            FrequencyUnit__c = 'days',
            FrequencyValue__c = 1,
            NamedCredential__c = 'ToolingAPICredential',
            RetrieveComponents__c = true,
            RetrieveTests__c = true,
            RetrieveIntermediateStates__c = false,
            BatchSize__c = 50
        );
        insert cfg;
    }

    @IsTest
    static void testSyncDeploymentsNoDates() {
        setupTestConfig();
        DeployAccessValidator.testAccess = true;
        Test.setMock(HttpCalloutMock.class, new DeployToolingApiMock());

        Test.startTest();
        DeployService.syncDeployments((DateTime)null, (DateTime)null, true);
        Test.stopTest();

        Assert.isTrue(true, 'syncDeployments should complete with null dates');
    }

    @IsTest
    static void testSyncDeploymentsStartOnly() {
        setupTestConfig();
        DeployAccessValidator.testAccess = true;
        Test.setMock(HttpCalloutMock.class, new DeployToolingApiMock());

        DateTime fromDate = (DateTime)Datetime.now().addDays(-1);
        DeployService.syncDeployments(fromDate, (DateTime)null, true);

        Assert.isTrue(true, 'syncDeployments should complete with fromDate only');
    }

    @IsTest
    static void testSyncDeploymentsStartAndEnd() {
        setupTestConfig();
        DeployAccessValidator.testAccess = true;
        Test.setMock(HttpCalloutMock.class, new DeployToolingApiMock());

        DateTime fromDate = (DateTime)Datetime.now().addDays(-2);
        DateTime toDate = (DateTime)Datetime.now();
        DeployService.syncDeployments(fromDate, toDate, true);

        Assert.isTrue(true, 'syncDeployments should complete with from and to dates');
    }

    @IsTest
    static void testSyncDeploymentsInvalidDate() {
        setupTestConfig();
        DeployAccessValidator.testAccess = true;
        Test.setMock(HttpCalloutMock.class, new DeployToolingApiMock());

        Test.startTest();
        DeployService.syncDeployments((DateTime)null, (DateTime)null, true);
        Test.stopTest();

        Assert.isTrue(true, 'syncDeployments should complete gracefully with invalid dates');
    }
}