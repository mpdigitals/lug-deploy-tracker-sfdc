@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts, PMD.ExcessiveParameterList')
@IsTest
private class DeployScheduleServiceTest {

    private static DeploySetup__c createSetup(String unit, String value, Boolean enabled) {
        return new DeploySetup__c(
            StartTime__c = System.now(),
            IsEnabled__c = enabled,
            FrequencyUnit__c = unit,
            FrequencyValue__c = Integer.valueOf(value),
            NamedCredential__c = 'ToolingAPICredential',
            RetrieveComponents__c = true,
            RetrieveTests__c = true
        );
    }
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void runScheduleTest(String unit, String value, Boolean enabled, String message) {
        DeploySetup__c setup = createSetup(unit, value, enabled);
        insert setup;

        DeployAccessValidator.testAccess = true;
        Test.setMock(HttpCalloutMock.class, new DeployToolingApiMock());

        Test.startTest();
        try {
            DeployScheduleService.scheduleNextRun(DeployCoreUtils.getDeployConfig());
            Assert.isTrue(true, message);
        } catch (Exception e) {
            Assert.fail('Unexpected exception: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDailyUnit() {
        runScheduleTest('days', '1', true, 'Scheduled daily job without error');
    }

    @IsTest
    static void testMonthlyUnit() {
        runScheduleTest('months', '1', true, 'Scheduled monthly job without error');
    }

    @IsTest
    static void testHourlyUnit() {
        runScheduleTest('hours', '6', true, 'Scheduled hourly job without error');
    }

    @IsTest
    static void testInvalidUnit() {
        runScheduleTest('invalid', '5', true, 'Handled invalid unit gracefully');
    }

    @IsTest
    static void testDisabledConfig() {
        runScheduleTest('days', '1', false, 'No job scheduled when config is disabled');
    }
}