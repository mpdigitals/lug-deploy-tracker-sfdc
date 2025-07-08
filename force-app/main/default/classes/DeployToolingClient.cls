/**
 * @description Client for calling Salesforce Tooling API using either Named Credential or UserInfo.getSessionId().
 * Supports SOQL queries and fetching detailed DeployRequest results.
 * Author: develop@mpdigitals.com
 */
public with sharing class DeployToolingClient implements DeployToolingClientInterface {

    private final String namedCredential;
    private final Boolean useSessionId;

    /**
     * @description Constructor that sets the Named Credential and auth mode.
     * @param namedCredential DeveloperName of the Named Credential.
     * @param useSessionId Whether to use UserInfo.getSessionId() instead of Named Credential.
     */
    public DeployToolingClient(String namedCredential, Boolean useSessionId) {
        if (!useSessionId && String.isBlank(namedCredential)) {
            throw new IllegalArgumentException(DeployConstants.ERR_NC_BLANK);
        }
        this.namedCredential = namedCredential;
        this.useSessionId = useSessionId;
    }

    /**
     * @description Executes a SOQL query via Tooling API using HTTP GET.
     * @param soql A valid SOQL query string.
     * @return The HttpResponse returned from the API.
     */
    public HttpResponse query(String soql) {
        String endpointPath = DeployConstants.SERVICES_BASE_PATH
            + DeployConstants.API_VERSION
            + DeployConstants.TOOLING_QUERY_PATH
            + EncodingUtil.urlEncode(soql, 'UTF-8');

        return sendRequest('GET', endpointPath);
    }

    /**
     * @description Fetches full deploy result details by DeployRequest Id from Tooling API.
     * @param deployRequestId The Id of the DeployRequest to fetch.
     * @return The HttpResponse containing deploy result details.
     */
    public HttpResponse fetchDeployResult(Id deployRequestId) {
        String path = DeployConstants.SERVICES_BASE_PATH
            + DeployConstants.API_VERSION
            + DeployConstants.METADATA_DEPLOY_REQUEST_PATH
            + String.valueOf(deployRequestId)
            + DeployConstants.METADATA_DEPLOY_REQUEST_SUFFIX;

        return sendRequest('GET', path);
    }

    /**
     * @description Helper that constructs and sends the HTTP request based on auth mode.
     * @param httpMethod The HTTP method ('GET', 'POST', etc.).
     * @param path The endpoint path after the base URL.
     * @return The HttpResponse returned from the API.
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    private HttpResponse sendRequest(String httpMethod, String path) {
        HttpRequest req = new HttpRequest();
        req.setMethod(httpMethod);
        req.setHeader('Content-Type', 'application/json');

        if (useSessionId) {
            req.setEndpoint(System.Url.getOrgDomainUrl().toExternalForm() + path);
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        } else {
            req.setEndpoint(formatNamedCredential() + path);
        }

        return new Http().send(req);
    }

    /**
     * @description Ensures the Named Credential is prefixed with 'callout:'.
     * @return The fully qualified Named Credential endpoint prefix.
     */
    private String formatNamedCredential() {
        return namedCredential.startsWith(DeployConstants.CALLOUT_PREFIX)
            ? namedCredential
            : DeployConstants.CALLOUT_PREFIX + namedCredential;
    }
}