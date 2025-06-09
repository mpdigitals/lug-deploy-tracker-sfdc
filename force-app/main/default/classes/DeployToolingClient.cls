/**
 * @description Client for calling Salesforce Tooling API using a Named Credential.
 * Supports SOQL queries and fetching detailed DeployRequest results.
 * @author develop@mpdigitals.com
 */
public with sharing class DeployToolingClient implements DeployToolingClientInterface {

    private final String namedCredential;

    /**
     * @description Constructor that sets the Named Credential for API callouts.
     * @param namedCredential DeveloperName of the Named Credential.
     */
    public DeployToolingClient(String namedCredential) {
        if (String.isBlank(namedCredential)) {
            throw new IllegalArgumentException('Named Credential cannot be blank');
        }
        this.namedCredential = namedCredential;
    }

    /**
     * @description Executes a SOQL query via Tooling API using HTTP GET.
     * @param soql A valid SOQL query string.
     * @return The HttpResponse returned from the API.
     */
    public HttpResponse query(String soql) {
        String base = formatNamedCredential();
        String endpoint = base
            + DeployConstants.SERVICES_BASE_PATH
            + DeployConstants.API_VERSION
            + DeployConstants.TOOLING_QUERY_PATH
            + EncodingUtil.urlEncode(soql, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        return new Http().send(req);
    }

    /**
     * @description Fetches full deploy result details by DeployRequest Id from Tooling API.
     * @param deployRequestId The Id of the DeployRequest to fetch.
     * @return The HttpResponse containing deploy result details.
     */
    public HttpResponse fetchDeployResult(Id deployRequestId) {
        String base = formatNamedCredential();
        String path = DeployConstants.SERVICES_BASE_PATH
            + DeployConstants.API_VERSION
            + DeployConstants.METADATA_DEPLOY_REQUEST_PATH
            + String.valueOf(deployRequestId)
            + DeployConstants.METADATA_DEPLOY_REQUEST_SUFFIX;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(base + path);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

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