@isTest
private class DeployToolingClientTest {
    @SuppressWarnings('PMD.AvoidHardcodingId')
    @isTest
    static void testFetchDeployResultWithMockedResponse() {
        Test.setMock(HttpCalloutMock.class, new DeployToolingApiMock());

        Id deployId = Id.valueOf('0AfQy00000Kf1XhKAJ');
        Id parentId = Id.valueOf('a01100000000000AAA');
        DeployToolingClient client = new DeployToolingClient('Mocked_NC');

        Test.startTest();
        HttpResponse response = client.fetchDeployResult(deployId);
        Test.stopTest();

        DeployApiWrapper.DeployRequest wrapper = (DeployApiWrapper.DeployRequest)
            JSON.deserialize(response.getBody(), DeployApiWrapper.DeployRequest.class);

        Assert.isNotNull(wrapper.deployResult, 'Deploy result should not be null');
        Assert.isNotNull(wrapper.deployResult.details, 'Details should not be null');
        Assert.isNotNull(wrapper.deployResult.details.allComponentMessages, 'Component messages should not be null');

        List<DeployResultTest__c> testResults = DeployResultTestMapper.mapResultTests(wrapper, parentId);
        List<DeployResultComponent__c> components = DeployResultComponentMapper.mapComponents(wrapper, parentId);

        Assert.isNotNull(testResults, 'Test results should not be null');
        Assert.areEqual(3, testResults.size(), 'There should be 3 test results');

        Boolean hasFailure = false;
        for (DeployResultTest__c result : testResults) {
            if (!result.Success__c) {
                hasFailure = true;
                Assert.isTrue(result.StackTrace__c != null && result.StackTrace__c.contains('MyServiceClass'), 'Failure stack trace should be present');
            }
        }
        Assert.isTrue(hasFailure, 'At least one test result should be a failure');

        Assert.areEqual(2, components.size(), 'Should map 2 components');
        Assert.areEqual('ApexClass', components[0].ComponentType__c, 'Component type should match');
        Assert.isTrue(components[0].FullName__c.startsWith('MyServiceClass'), 'Component name should match expected prefix');
    }
}