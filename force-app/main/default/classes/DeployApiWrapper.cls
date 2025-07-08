/**
 * @description Wrapper class to interact with the Tooling API for retrieving deployment results, including detailed components and test execution outcomes.
 * @author develop@mpdigitals.com
 */
public with sharing class DeployApiWrapper {

    private final DeployToolingClient client;

    /**
     * @description Constructor that initializes the API client using the given Named Credential.
     * @param namedCredential Name of the Named Credential to use for API access.
     */
    public DeployApiWrapper(String namedCredential, Boolean sessionId) {
        DeployValidator.validateNamedCredential(namedCredential, sessionId);
        client = new DeployToolingClient(namedCredential, sessionId);
    }

    /**s
     * @description Fetches deployment results for the provided list of IDs using the Tooling API.
     * @param ids List of DeployRequest IDs to retrieve.
     * @return List of DeployRequest objects with detailed deployment data.
     */
    public List<DeployRequest> getDeployResults(List<Id> ids) {
        List<DeployRequest> out = new List<DeployRequest>();
        if (ids == null || ids.isEmpty()) {
            return out;
        }
        for (Id idVal : ids) {
            HttpResponse res;
            try {
                res = client.fetchDeployResult(idVal);
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Callout error ' + idVal + ': ' + ex.getMessage());
                continue;
            }
            Integer code = res.getStatusCode();
            if (code >= 200 && code < 300) {
                out.add((DeployRequest) JSON.deserialize(res.getBody(), DeployRequest.class));
            } else {
                System.debug(LoggingLevel.ERROR, 'DeployRequest ' + idVal + ' returned ' + code + ': ' + res.getBody());
            }
        }
        return out;
    }

    public class DeployRequest {
        public String id;
        public Datetime completedDate;
        public DeployResult deployResult;
    }

    public class DeployResult {
        public String id;
        public Boolean success;
        public Boolean checkOnly;
        public Boolean ignoreWarnings;
        public Boolean rollbackOnError;
        public Boolean done;
        public Boolean runTestsEnabled;
        public Integer numberComponentsDeployed;
        public Integer numberComponentsTotal;
        public Integer numberComponentErrors;
        public Integer numberTestsCompleted;
        public Integer numberTestErrors;
        public Integer numberTestsTotal;
        public Decimal totalTime;
        public Details details;
    }

    public class Details {
        public List<Component> allComponentMessages;
        public RunTestResult runTestResult;
    }

    public class Component {
        public String componentType;
        public String fileName;
        public String fullName;
        public String id;
        public String problem;
        public Boolean success;
        public Boolean warning;
        public Boolean created;
        public Boolean changed;
        public Boolean deleted;
        public Boolean knownPackagingProblem;
        public Boolean forPackageManifestFile;
        public Boolean requiresProductionTestRun;
        public Integer lineNumber;
        public Integer columnNumber;
        public Datetime createdDate;
        public String problemType;
    }

    public class RunTestResult {
        public List<TestSuccess> successes;
        public List<TestFailure> failures;
        public Decimal totalTime;
        public String apexLogId;
        public Integer numFailures;
        public Integer numTestsRun;
        public List<CodeCoverageWarning> codeCoverageWarnings;
    }

    public class TestSuccess {
        public String namespace;
        public String name;
        public String methodName;
        public String id;
        public Decimal timeValue;
        public Boolean seeAllData;
    }

    public class TestFailure {
        public String type;
        public String namespace;
        public String name;
        public String methodName;
        public String message;
        public String stackTrace;
        public String id;
        public Boolean seeAllData;
        public Decimal timeValue;
        public String packageName;
    }

    public class CodeCoverageWarning {
        public String id;
        public String name;
        public String namespace;
        public String message;
    }
}