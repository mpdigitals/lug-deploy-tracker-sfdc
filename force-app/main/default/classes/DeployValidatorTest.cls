@IsTest
private class DeployValidatorTest {

    private static String toIso(Datetime dt) {
        return dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    private static DeploySetupWrapper createBaseWrapper() {
        DeploySetupWrapper wrapper = new DeploySetupWrapper();
        wrapper.startTime = System.now().addMinutes(5);
        wrapper.frequencyUnit = 'days';
        wrapper.frequencyValue = '1';
        wrapper.isEnabled = true;
        wrapper.namedCredential = 'ToolingAPICredential';
        wrapper.batchSize = 10;
        return wrapper;
    }

    @TestSetup
    static void setup() {
        DeploySetup__c config = new DeploySetup__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            StartTime__c = System.now(),
            IsEnabled__c = false,
            FrequencyUnit__c = 'days',
            FrequencyValue__c = 1,
            NamedCredential__c = 'TestNC'
        );
        insert config;

        System.schedule(
            'TestJob',
            '0 0 0 1 1 ? 2050',
            new DummySched()
        );
    }

    @SuppressWarnings('PMD.EmptyStatementBlock')
    private class DummySched implements Schedulable {
        public void execute(SchedulableContext sc) {}
    }

    @IsTest
    static void testScheduleValid() {
        DeployAccessValidator.testAccess = true;
        DeploySetupWrapper wrapper = createBaseWrapper();
        DeployValidator.validateScheduleInput(wrapper);
        Assert.isTrue(true, 'Schedule input should be valid');
    }

    @IsTest
    static void testPastStartFails() {
        DeployAccessValidator.testAccess = true;
        Boolean threw = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.startTime = System.now().addMinutes(-5);
            DeployValidator.validateScheduleInput(wrapper);
        } catch (Exception e) {
            threw = true;
        }
        Assert.isTrue(threw, 'Expected exception for past start date');
    }

    @IsTest
    static void testBlankValuesScheduleInput() {
        DeployAccessValidator.testAccess = true;
        Boolean ex;

        ex = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.startTime = null;
            DeployValidator.validateScheduleInput(wrapper);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for blank start time');

        ex = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.frequencyUnit = '';
            DeployValidator.validateScheduleInput(wrapper);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for blank frequency unit');

        ex = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.frequencyValue = '';
            DeployValidator.validateScheduleInput(wrapper);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for blank frequency value');
    }

    @IsTest
    static void testNumericAndRangeValidation() {
        DeployAccessValidator.testAccess = true;
        Boolean ex;

        ex = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.frequencyValue = 'abc';
            DeployValidator.validateScheduleInput(wrapper);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for non-numeric frequency value');

        ex = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.frequencyValue = '0';
            DeployValidator.validateScheduleInput(wrapper);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for zero frequency');

        ex = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.frequencyUnit = 'foo';
            DeployValidator.validateScheduleInput(wrapper);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for invalid frequency unit');

        ex = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.frequencyValue = '9999';
            DeployValidator.validateScheduleInput(wrapper);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for frequency value too large');

        ex = false;
        Integer maxDays = DeployConstants.LIMITS.get('days');
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.frequencyValue = String.valueOf(maxDays);
            DeployValidator.validateScheduleInput(wrapper);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isFalse(ex, 'Should accept value at max limit');
    }

    @IsTest
    static void testSyncDatesValid() {
        DeployAccessValidator.testAccess = true;
        DeployValidator.validateSyncDates(
            toIso(System.now().addDays(-5)),
            toIso(System.now().addDays(-2))
        );
        Assert.isTrue(true, 'Sync dates should be valid');
    }

    @IsTest
    static void testSyncDatesThrows() {
        DeployAccessValidator.testAccess = true;
        Boolean ex;

        ex = false;
        try {
            DeployValidator.validateSyncDates(toIso(System.now().addMinutes(5)), null);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for future from date');

        ex = false;
        try {
            DeployValidator.validateSyncDates(null, toIso(System.now().addMinutes(5)));
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for future to date');

        ex = false;
        try {
            DeployValidator.validateSyncDates(
                toIso(System.now().addDays(-DeployConstants.DAYS_MAX - 1)),
                null
            );
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for from date too old');

        ex = false;
        try {
            DeployValidator.validateSyncDates(
                toIso(System.now().addDays(-1)),
                toIso(System.now().addDays(-2))
            );
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for end before start');

        ex = false;
        try {
            DeployValidator.validateSyncDates(
                null,
                toIso(System.now().addDays(DeployConstants.DAYS_MAX + 1))
            );
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for end date too far when startIso is null');
    }

    @IsTest
    static void testAdvancedSettingsValid() {
        DeployAccessValidator.testAccess = true;
        DeploySetupWrapper wrapper = createBaseWrapper();
        DeployValidator.validateAdvancedSettings(wrapper.batchSize, wrapper.namedCredential, true);
        Assert.isTrue(true, 'Advanced settings should be valid');
    }

    @IsTest
    static void testAdvancedSettingsInvalidBatch() {
        DeployAccessValidator.testAccess = true;
        Boolean ex;

        ex = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.batchSize = 0;
            DeployValidator.validateAdvancedSettings(wrapper.batchSize, wrapper.namedCredential, true);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for batch size = 0');

        ex = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.batchSize = DeployConstants.MAX_BATCH_SIZE + 1;
            DeployValidator.validateAdvancedSettings(wrapper.batchSize, wrapper.namedCredential, true);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for batch size > max');
    }

    @IsTest
    static void testAdvancedSettingsMissingNC() {
        DeployAccessValidator.testAccess = true;
        DeployValidator.validateNCInTest = true;
        Boolean ex = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.namedCredential = '';
            DeployValidator.validateAdvancedSettings(wrapper.batchSize, wrapper.namedCredential, false);
        } catch (Exception e) {
            ex = true;
        }
        Assert.isTrue(ex, 'Expected exception for missing Named Credential');
    }

    @IsTest
    static void testGetBatchSizeDefault() {
        DeployAccessValidator.testAccess = true;
        Integer sizeVal = DeployValidator.getBatchSize();
        Assert.areEqual(DeployConstants.MAX_BATCH_SIZE, sizeVal, 'Expected default batch size');
    }

    @IsTest
    static void testNoJobThrows() {
        DeployAccessValidator.testAccess = true;
        DeployValidator.validateNCInTest = true;

        for (CronTrigger ct : [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name = 'TestJob'
        ]) {
            System.abortJob(ct.Id);
        }

        Boolean threw = false;
        try {
            DeploySetupWrapper wrapper = createBaseWrapper();
            wrapper.isEnabled = false;
            DeployValidator.validateScheduleInput(wrapper);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Assert.isTrue(threw, 'Expected exception when enabled = false and no job exists');
    }

    @IsTest
    static void testNamedCredentialOk() {
        DeployAccessValidator.testAccess = true;
        DeployValidator.validateNamedCredential('TestNC', true);
        Assert.isTrue(true, 'assertNamedCredential should pass for non-blank NC');
    }

    @IsTest
    static void testScheduleWrapperOk() {
        DeployAccessValidator.testAccess = true;
        DeploySetupWrapper wrapper = createBaseWrapper();
        DeployValidator.validateScheduleInput(wrapper);
        Assert.isTrue(true, 'Schedule wrapper should be valid');
    }

    @IsTest
    static void testAssertNoSyncSkipsWhenDisabled() {
        DeployAccessValidator.testAccess = true;
        DeployValidator.assertNoSyncInProgress();
        Assert.isTrue(true, 'assertNoSyncInProgress should not throw when no job running');
    }

    @IsTest
    static void testAssertNoSyncThrows() {
        DeployAccessValidator.testAccess = true;

        Test.setMock(HttpCalloutMock.class, new DeployToolingApiMock());

        Test.startTest();
        Database.executeBatch(
            new DeployRequestBatch(
                System.now().addDays(-1), 
                System.now(), true
            ), 
            1
        );
        Boolean threw = false;
        try {
            DeployValidator.assertNoSyncInProgress();
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        Assert.isTrue(threw, 'Expected assertNoSyncInProgress to throw when a batch job is running');
    }
}