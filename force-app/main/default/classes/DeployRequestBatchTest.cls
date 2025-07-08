@IsTest
public class DeployRequestBatchTest {

    static void createBasicSetup() {
        insert new DeploySetup__c(
            StartTime__c = System.now().addMinutes(5),
            IsEnabled__c = true,
            FrequencyUnit__c = 'days',
            FrequencyValue__c = 1,
            NamedCredential__c = 'ToolingAPICredential',
            RetrieveComponents__c = true,
            RetrieveTests__c = true,
            RetrieveIntermediateStates__c = false,
            BatchSize__c = 50,
            sessionId__c = true
        );

        DeployAccessValidator.testAccess = true;
        Test.setMock(HttpCalloutMock.class, new DeployToolingApiMock());
    }

    @IsTest
    static void testDeployRequestBatchEndToEnd() {
        createBasicSetup();

        Datetime startTime = Datetime.newInstance(Date.today(), Time.newInstance(10, 0, 0, 0));
        Datetime endTime = startTime.addMinutes(30);

        Test.startTest();
        Database.executeBatch(new DeployRequestBatch(startTime, endTime, true), 1);
        Test.stopTest();

        List<DeployResult__c> results = [SELECT Id, Status__c FROM DeployResult__c];
        Assert.areEqual(1, results.size(), 'Expected exactly 1 DeployResult__c');
        Assert.areEqual('Failed', results[0].Status__c, 'Expected status to be Failed');

        List<DeployResultComponent__c> components = [
            SELECT Id, FullName__c, ComponentType__c FROM DeployResultComponent__c ORDER BY FullName__c
        ];
        Assert.areEqual(2, components.size(), 'Expected 2 DeployResultComponent__c records');
        Assert.areEqual('MyServiceClass', components[0].FullName__c, 'First component name mismatch');
        Assert.areEqual('ApexClass', components[0].ComponentType__c, 'First component type mismatch');
        Assert.areEqual('MyServiceClassTest', components[1].FullName__c, 'Second component name mismatch');
        Assert.areEqual('ApexClass', components[1].ComponentType__c, 'Second component type mismatch');

        List<DeployResultTest__c> tests = [
            SELECT Id, MethodName__c, Success__c FROM DeployResultTest__c ORDER BY MethodName__c
        ];
        Assert.areEqual(3, tests.size(), 'Expected 3 DeployResultTest__c records');
        Assert.areEqual('testBasicExecution', tests[0].MethodName__c, 'First test name mismatch');
        Assert.isTrue(tests[0].Success__c, 'Expected first test to succeed');
        Assert.areEqual('testExecution_withDates', tests[1].MethodName__c, 'Second test name mismatch');
        Assert.isFalse(tests[1].Success__c, 'Expected second test to fail');
        Assert.areEqual('testExecution_withStartOnly', tests[2].MethodName__c, 'Third test name mismatch');
        Assert.isFalse(tests[2].Success__c, 'Expected third test to fail');

        DeployResult__c resultWithWarnings = [SELECT Id, ErrorMessage__c, ErrorStatusCode__c FROM DeployResult__c LIMIT 1];
        Assert.isFalse(String.isBlank(resultWithWarnings.ErrorMessage__c), 'Expected ErrorMessage__c to contain coverage warnings');
        Assert.isTrue(resultWithWarnings.ErrorMessage__c.contains('Test coverage of selected Apex Class'), 'Expected coverage warning message');
        Assert.areEqual(DeployConstants.ERR_TEST_COVERAGE, resultWithWarnings.ErrorStatusCode__c, 'Expected ErrorStatusCode__c to be ERR_TEST_COVERAGE');
    }

    @IsTest
    static void testGetBatchStatusNullId() {
        Map<String, String> result = DeployRequestBatch.getBatchStatus(null);
        Assert.areEqual('Unknown', result.get('status'), 'Status should be Unknown when batchId is null');
        Assert.areEqual('0', result.get('numberOfErrors'), 'NumberOfErrors should be 0 when batchId is null');
        Assert.areEqual(DeployConstants.ERR_BATCH_ID_REQUIRED, result.get('extendedStatus'), 'Should return ERR_BATCH_ID_REQUIRED when batchId is null');
    }

    @IsTest
    @SuppressWarnings('PMD.AvoidHardcodingId')
    static void testGetBatchStatusNotFound() {
        Id fakeId = Id.valueOf('707000000000000AAA');
        Map<String, String> result = DeployRequestBatch.getBatchStatus(fakeId);
        Assert.areEqual('Unknown', result.get('status'), 'Status should be Unknown for non-existent batchId');
        Assert.areEqual('0', result.get('numberOfErrors'), 'NumberOfErrors should be 0 for non-existent batchId');
        Assert.areEqual(DeployConstants.ERR_BATCH_NOT_FOUND, result.get('extendedStatus'), 'Should return ERR_BATCH_NOT_FOUND for non-existent batchId');
    }

    @IsTest
    static void testGetBatchStatusValidJob() {
        createBasicSetup();

        Test.startTest();
        Id batchId = Database.executeBatch(new DeployRequestBatch(DateTime.now(), DateTime.now(), true), 1);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, ExtendedStatus 
            FROM AsyncApexJob 
            WHERE Id = :batchId 
            LIMIT 1
        ];

        Map<String, String> result = DeployRequestBatch.getBatchStatus(batchId);
        Assert.areEqual(String.valueOf(job.Status), result.get('status'), 'Status should match the AsyncApexJob status');
        Assert.areEqual(String.valueOf(job.NumberOfErrors), result.get('numberOfErrors'), 'NumberOfErrors should match AsyncApexJob');
        Assert.areEqual(job.ExtendedStatus != null ? job.ExtendedStatus : '', result.get('extendedStatus'), 'ExtendedStatus should match or be empty');
    }
}