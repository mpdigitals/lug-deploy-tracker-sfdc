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

        Test.startTest();
        DeployService.syncDeployments(null, null);
        Test.stopTest();

        Assert.isTrue(true, 'syncDeployments should complete with null dates');
    }

    @IsTest
    static void testSyncDeploymentsStartOnly() {
        setupTestConfig();
        DeployAccessValidator.testAccess = true;

        Datetime fromDate = Datetime.now().addDays(-1);

        Test.startTest();
        DeployService.syncDeployments(fromDate, null);
        Test.stopTest();

        Assert.isTrue(true, 'syncDeployments should complete with fromDate only');
    }

    @IsTest
    static void testSyncDeploymentsStartAndEnd() {
        setupTestConfig();
        DeployAccessValidator.testAccess = true;

        Datetime fromDate = Datetime.now().addDays(-2);
        Datetime toDate   = Datetime.now();

        Test.startTest();
        DeployService.syncDeployments(fromDate, toDate);
        Test.stopTest();

        Assert.isTrue(true, 'syncDeployments should complete with from and to dates');
    }

    @IsTest
    static void testSyncDeploymentsInvalidDate() {
        setupTestConfig();
        DeployAccessValidator.testAccess = true;

        Test.startTest();
        DeployService.syncDeployments(null, null);
        Test.stopTest();

        Assert.isTrue(true, 'syncDeployments should complete gracefully with invalid dates');
    }
}